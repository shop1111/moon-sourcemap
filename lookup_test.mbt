///|
fn lookup_fixture() -> @moon_sourcemap.DecodedSourceMap {
  @moon_sourcemap.DecodedSourceMap::new(
    sources=[
      @moon_sourcemap.SourceEntry::new(url="src/main.ts"),
      @moon_sourcemap.SourceEntry::new(url="src/lib.ts", ignored=true),
    ],
    mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=2,
          column=1,
        ),
        name="start",
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=5),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=2,
          column=8,
        ),
      ),
      @moon_sourcemap.Mapping::generated_only(
        generated=@moon_sourcemap.Position::new(line=0, column=5),
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=2, column=3),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=1,
          line=4,
          column=0,
        ),
      ),
    ],
  )
}

///|
test "decode regular map resolves source metadata" {
  let map = @moon_sourcemap.RegularSourceMap::new(
    file="dist/app.js",
    source_root="../src",
    sources=[Some("./main.ts"), None, Some("util.ts")],
    sources_content=[Some("let x = 1"), None, Some("export {}")],
    names=["x"],
    mappings="AAAAA",
    ignore_list=[2],
  )
  let decoded = @moon_sourcemap.decode_regular_source_map(map)
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
  let exact = @moon_sourcemap.original_position_for(
    map,
    generated=@moon_sourcemap.Position::new(line=0, column=0),
  )
  assert_true(exact is Some(_))
  guard exact is Some(exact) else { fail("expected exact mapping") }
  assert_eq(exact.generated.line, 0)
  assert_eq(exact.generated.column, 0)
  assert_true(exact.name == Some("start"))
  let glb = @moon_sourcemap.original_position_for(
    map,
    generated=@moon_sourcemap.Position::new(line=0, column=9),
  )
  guard glb is Some(glb) else { fail("expected GLB mapping") }
  assert_eq(glb.generated.column, 5)
  assert_true(glb.original is None)
}

///|
test "generated lookup supports LUB and line boundaries" {
  let map = lookup_fixture()
  let lub = @moon_sourcemap.original_position_for(
    map,
    generated=@moon_sourcemap.Position::new(line=0, column=1),
    bias=LeastUpperBound,
  )
  guard lub is Some(lub) else { fail("expected LUB mapping") }
  assert_eq(lub.generated.column, 5)
  assert_true(lub.original is Some(_))
  assert_true(
    @moon_sourcemap.original_position_for(
      map,
      generated=@moon_sourcemap.Position::new(line=1, column=99),
    )
    is None,
  )
  assert_true(
    @moon_sourcemap.original_position_for(
      map,
      generated=@moon_sourcemap.Position::new(line=2, column=0),
      bias=GreatestLowerBound,
    )
    is None,
  )
}

///|
test "GetOriginalPositions returns every duplicate at the global GLB" {
  let map = lookup_fixture()
  let exact = @moon_sourcemap.get_original_positions(
    map,
    generated=@moon_sourcemap.Position::new(line=0, column=5),
  )
  assert_eq(exact.length(), 2)
  guard exact[0] is Some(first) else { fail("expected mapped duplicate") }
  assert_eq(first.source_index, 0)
  assert_eq(first.line, 2)
  assert_eq(first.column, 8)
  assert_true(exact[1] is None)
  let between_lines = @moon_sourcemap.get_original_positions(
    map,
    generated=@moon_sourcemap.Position::new(line=1, column=99),
  )
  assert_eq(between_lines.length(), 2)
  assert_true(between_lines[0] is Some(_))
  assert_true(between_lines[1] is None)
}

///|
test "GetOriginalPositions distinguishes no match from generated-only" {
  let map = @moon_sourcemap.DecodedSourceMap::new(mappings=[
    @moon_sourcemap.Mapping::generated_only(
      generated=@moon_sourcemap.Position::new(line=0, column=5),
    ),
  ])
  assert_true(
    @moon_sourcemap.get_original_positions(
      map,
      generated=@moon_sourcemap.Position::new(line=0, column=4),
    ).is_empty(),
  )
  let generated_only = @moon_sourcemap.get_original_positions(
    map,
    generated=@moon_sourcemap.Position::new(line=0, column=5),
  )
  assert_eq(generated_only.length(), 1)
  assert_true(generated_only[0] is None)
}

///|
test "reverse lookup filters line and optional column" {
  let map = lookup_fixture()
  let on_line = @moon_sourcemap.generated_positions_for(
    map,
    source_index=0,
    line=2,
  )
  assert_eq(on_line.length(), 2)
  let at_column = @moon_sourcemap.generated_positions_for(
    map,
    source_index=0,
    line=2,
    column=8,
  )
  assert_eq(at_column.length(), 1)
  assert_eq(at_column[0].generated.line, 0)
  assert_eq(at_column[0].generated.column, 5)
}

///|
test "mapping source resolution is bounds checked" {
  let map = lookup_fixture()
  let mapping = map.mappings[0]
  let source = @moon_sourcemap.source_for_mapping(map, mapping)
  guard source is Some(source) else { fail("expected source") }
  assert_true(source.url == Some("src/main.ts"))
  let bad = @moon_sourcemap.Mapping::mapped(
    generated=@moon_sourcemap.Position::new(line=0, column=0),
    original=@moon_sourcemap.OriginalPosition::new(
      source_index=9,
      line=0,
      column=0,
    ),
  )
  assert_true(@moon_sourcemap.source_for_mapping(map, bad) is None)
}
