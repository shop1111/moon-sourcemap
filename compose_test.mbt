///|
fn composition_maps() -> (
  @moon_sourcemap.DecodedSourceMap,
  @moon_sourcemap.DecodedSourceMap,
) {
  let outer = @moon_sourcemap.DecodedSourceMap::new(
    file="app.min.js",
    sources=[@moon_sourcemap.SourceEntry::new(url="app.js")],
    mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=0,
          column=2,
        ),
        name="minifiedName",
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=7),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=1,
          column=0,
        ),
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=12),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=9,
          column=0,
        ),
      ),
    ],
  )
  let inner = @moon_sourcemap.DecodedSourceMap::new(
    file="app.js",
    sources=[
      @moon_sourcemap.SourceEntry::new(url="src/app.ts"),
      @moon_sourcemap.SourceEntry::new(url="src/util.ts"),
    ],
    mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=3,
          column=1,
        ),
        name="sourceName",
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=1, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=1,
          line=8,
          column=4,
        ),
        name="utility",
      ),
    ],
  )
  (outer, inner)
}

///|
test "compose resolves two mapping stages and preserves outer names" {
  let (outer, inner) = composition_maps()
  let result = @moon_sourcemap.compose_with_options(outer, inner)
  assert_eq(result.stats.outer_mappings, 3)
  assert_eq(result.stats.composed_mappings, 2)
  assert_eq(result.stats.generated_only, 1)
  let first = result.map.mappings[0]
  guard first.original is Some(original) else {
    fail("expected composed mapping")
  }
  assert_eq(original.source_index, 0)
  assert_eq(original.line, 3)
  assert_true(first.name == Some("minifiedName"))
  let second = result.map.mappings[1]
  guard second.original is Some(second_original) else {
    fail("expected second composed mapping")
  }
  assert_eq(second_original.source_index, 1)
  assert_true(second.name == Some("utility"))
}

///|
test "compose can drop unresolved mappings" {
  let (outer, inner) = composition_maps()
  let options : @moon_sourcemap.ComposeOptions = {
    bias: GreatestLowerBound,
    missing: Drop,
    preserve_outer_names: true,
  }
  let result = @moon_sourcemap.compose_with_options(outer, inner, options~)
  assert_eq(result.map.mappings.length(), 2)
  assert_eq(result.stats.dropped, 1)
  assert_eq(result.stats.generated_only, 0)
}

///|
test "compose can prefer inner names" {
  let (outer, inner) = composition_maps()
  let options : @moon_sourcemap.ComposeOptions = {
    bias: GreatestLowerBound,
    missing: KeepGenerated,
    preserve_outer_names: false,
  }
  let result = @moon_sourcemap.compose_with_options(outer, inner, options~)
  assert_true(result.map.mappings[0].name == Some("sourceName"))
}

///|
test "compose JSON produces a valid regular document" {
  let outer =
    #|{"version":3,"file":"min.js","sources":["mid.js"],"names":[],"mappings":"AAAA"}
  let inner =
    #|{"version":3,"file":"mid.js","sources":["src.ts"],"names":[],"mappings":"AACA"}
  let output = @moon_sourcemap.compose_json(outer, inner)
  let document = @moon_sourcemap.parse_document(output)
  let decoded = @moon_sourcemap.decode_document(document)
  guard decoded.mappings[0].original is Some(original) else {
    fail("expected composed JSON mapping")
  }
  assert_eq(original.line, 1)
  assert_true(decoded.sources[0].url == Some("src.ts"))
}
