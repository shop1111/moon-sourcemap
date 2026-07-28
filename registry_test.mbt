///|
fn registry_fixture_map(file : String, source : String) -> DecodedSourceMap {
  DecodedSourceMap::new(
    file~,
    sources=[SourceEntry::new(url=source, content="zero\none\ntwo")],
    mappings=[
      Mapping::mapped(
        generated=Position::new(line=0, column=0),
        original=OriginalPosition::new(source_index=0, line=1, column=1),
        name="entry",
      ),
    ],
  )
}

///|
test "registry uses exact and normalized aliases" {
  let registry = SourceMapRegistry::new()
  registry.register(
    name="app",
    generated_file="dist/app.js",
    map=registry_fixture_map("dist/app.js", "src/app.ts"),
    aliases=["C:\\build\\dist\\app.js"],
  )
  assert_eq(registry.length(), 1)
  assert_true(registry.find("dist/./app.js") is Some(_))
  assert_true(registry.find("C:/build/dist/app.js") is Some(_))
  assert_true(registry.find("missing.js") is None)
}

///|
test "registry rejects alias conflicts" {
  let registry = SourceMapRegistry::new()
  registry.register(
    name="first",
    generated_file="dist/app.js",
    map=registry_fixture_map("dist/app.js", "a.ts"),
  )
  try
    registry.register(
      name="second",
      generated_file="dist/./app.js",
      map=registry_fixture_map("dist/app.js", "b.ts"),
    )
  catch {
    InvalidDocument(message~) => assert_true(message.contains("conflicts"))
    _ => fail("expected registry conflict")
  } noraise {
    _ => fail("expected registry conflict")
  }
}

///|
test "registry distinguishes missing map mapping and generated-only" {
  let registry = SourceMapRegistry::new()
  registry.register(
    name="mapped",
    generated_file="mapped.js",
    map=registry_fixture_map("mapped.js", "mapped.ts"),
  )
  registry.register(
    name="generated",
    generated_file="generated.js",
    map=DecodedSourceMap::new(mappings=[
      Mapping::generated_only(generated=Position::new(line=0, column=0)),
    ]),
  )
  let report = registry.symbolize(
    "mapped.js:0:0\nmapped.js:1:0\ngenerated.js:0:0\nmissing.js:0:0",
    context_radius=1,
  )
  assert_eq(report.matched, 1)
  assert_eq(report.mapping_missing, 1)
  assert_eq(report.generated_only, 1)
  assert_eq(report.map_missing, 1)
  assert_false(report.is_complete())
  assert_true(report.frames[0].context is Some(_))
  assert_true(report.to_json() is Object(_))
}
