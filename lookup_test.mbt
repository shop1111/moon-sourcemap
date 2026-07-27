///|
fn lookup_fixture() -> DecodedSourceMap {
  DecodedSourceMap::new(
    sources=[
      SourceEntry::new(url="src/main.ts"),
      SourceEntry::new(url="src/lib.ts", ignored=true),
    ],
    mappings=[
      Mapping::mapped(
        generated=Position::new(line=0, column=0),
        original=OriginalPosition::new(source_index=0, line=2, column=1),
        name="start",
      ),
      Mapping::mapped(
        generated=Position::new(line=0, column=5),
        original=OriginalPosition::new(source_index=0, line=2, column=8),
      ),
      Mapping::generated_only(generated=Position::new(line=0, column=5)),
      Mapping::mapped(
        generated=Position::new(line=2, column=3),
        original=OriginalPosition::new(source_index=1, line=4, column=0),
      ),
    ],
  )
}

///|
test "decode regular map resolves source metadata" {
  let map = RegularSourceMap::new(
    file="dist/app.js",
    source_root="../src",
    sources=[Some("./main.ts"), None, Some("util.ts")],
    sources_content=[Some("let x = 1"), None, Some("export {}")],
    names=["x"],
    mappings="AAAAA",
    ignore_list=[2],
  )
  let decoded = decode_regular_source_map(map)
  assert_true(decoded.sources[0].url == Some("../src/main.ts"))
  assert_true(decoded.sources[0].content == Some("let x = 1"))
  assert_false(decoded.sources[0].ignored)
  assert_true(decoded.sources[1].url is None)
  assert_true(decoded.sources[1].content is None)
  assert_true(decoded.sources[2].url == Some("../src/util.ts"))
  assert_true(decoded.sources[2].content == Some("export {}"))
  assert_true(decoded.sources[2].ignored)
}

///|
test "generated lookup supports exact and GLB queries" {
  let map = lookup_fixture()
  let exact = original_position_for(
    map,
    generated=Position::new(line=0, column=0),
  )
  assert_true(exact is Some(_))
  guard exact is Some(exact) else { fail("expected exact mapping") }
  assert_eq(exact.generated.line, 0)
  assert_eq(exact.generated.column, 0)
  assert_true(exact.name == Some("start"))
  let glb = original_position_for(
    map,
    generated=Position::new(line=0, column=9),
  )
  guard glb is Some(glb) else { fail("expected GLB mapping") }
  assert_eq(glb.generated.column, 5)
  assert_true(glb.original is None)
}

///|
test "generated lookup supports LUB and line boundaries" {
  let map = lookup_fixture()
  let lub = original_position_for(
    map,
    generated=Position::new(line=0, column=1),
    bias=LeastUpperBound,
  )
  guard lub is Some(lub) else { fail("expected LUB mapping") }
  assert_eq(lub.generated.column, 5)
  assert_true(lub.original is Some(_))
  assert_true(
    original_position_for(map, generated=Position::new(line=1, column=99))
    is None,
  )
  assert_true(
    original_position_for(
      map,
      generated=Position::new(line=2, column=0),
      bias=GreatestLowerBound,
    )
    is None,
  )
}

///|
test "reverse lookup filters line and optional column" {
  let map = lookup_fixture()
  let on_line = generated_positions_for(map, source_index=0, line=2)
  assert_eq(on_line.length(), 2)
  let at_column = generated_positions_for(map, source_index=0, line=2, column=8)
  assert_eq(at_column.length(), 1)
  assert_eq(at_column[0].generated.line, 0)
  assert_eq(at_column[0].generated.column, 5)
}

///|
test "mapping source resolution is bounds checked" {
  let map = lookup_fixture()
  let mapping = map.mappings[0]
  let source = source_for_mapping(map, mapping)
  guard source is Some(source) else { fail("expected source") }
  assert_true(source.url == Some("src/main.ts"))
  let bad = Mapping::mapped(
    generated=Position::new(line=0, column=0),
    original=OriginalPosition::new(source_index=9, line=0, column=0),
  )
  assert_true(source_for_mapping(map, bad) is None)
}
