///|
test "positions compare in generated order" {
  let a = @moon_sourcemap.Position::new(line=2, column=3)
  let b = @moon_sourcemap.Position::new(line=2, column=5)
  assert_eq(a.compare(b), -1)
  assert_eq(b.compare(a), 1)
  assert_eq(a.compare(a), 0)
  assert_true(a.is_valid())
}

///|
test "mapping constructors preserve optional fields" {
  let generated = @moon_sourcemap.Position::new(line=1, column=4)
  let original = @moon_sourcemap.OriginalPosition::new(
    source_index=0,
    line=10,
    column=2,
  )
  let mapping = @moon_sourcemap.Mapping::mapped(
    generated~,
    original~,
    name="answer",
  )
  assert_true(mapping.generated == generated)
  assert_true(mapping.original == Some(original))
  assert_true(mapping.name == Some("answer"))
}

///|
test "regular documents expose common metadata" {
  let regular = @moon_sourcemap.RegularSourceMap::new(
    file="app.js",
    sources=[Some("app.mbt")],
    names=["main"],
    mappings="AAAA",
  )
  let doc = @moon_sourcemap.SourceMapDocument::Regular(regular)
  assert_eq(doc.version(), 3)
  assert_true(doc.file() == Some("app.js"))
}
