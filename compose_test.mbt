///|
fn composition_maps() -> (DecodedSourceMap, DecodedSourceMap) {
  let outer = DecodedSourceMap::new(
    file="app.min.js",
    sources=[SourceEntry::new(url="app.js")],
    mappings=[
      Mapping::mapped(
        generated=Position::new(line=0, column=0),
        original=OriginalPosition::new(source_index=0, line=0, column=2),
        name="minifiedName",
      ),
      Mapping::mapped(
        generated=Position::new(line=0, column=7),
        original=OriginalPosition::new(source_index=0, line=1, column=0),
      ),
      Mapping::mapped(
        generated=Position::new(line=0, column=12),
        original=OriginalPosition::new(source_index=0, line=9, column=0),
      ),
    ],
  )
  let inner = DecodedSourceMap::new(
    file="app.js",
    sources=[
      SourceEntry::new(url="src/app.ts"),
      SourceEntry::new(url="src/util.ts"),
    ],
    mappings=[
      Mapping::mapped(
        generated=Position::new(line=0, column=0),
        original=OriginalPosition::new(source_index=0, line=3, column=1),
        name="sourceName",
      ),
      Mapping::mapped(
        generated=Position::new(line=1, column=0),
        original=OriginalPosition::new(source_index=1, line=8, column=4),
        name="utility",
      ),
    ],
  )
  (outer, inner)
}

///|
test "compose resolves two mapping stages and preserves outer names" {
  let (outer, inner) = composition_maps()
  let result = compose_with_options(outer, inner)
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
  let options : ComposeOptions = {
    bias: GreatestLowerBound,
    missing: Drop,
    preserve_outer_names: true,
  }
  let result = compose_with_options(outer, inner, options~)
  assert_eq(result.map.mappings.length(), 2)
  assert_eq(result.stats.dropped, 1)
  assert_eq(result.stats.generated_only, 0)
}

///|
test "compose can prefer inner names" {
  let (outer, inner) = composition_maps()
  let options : ComposeOptions = {
    bias: GreatestLowerBound,
    missing: KeepGenerated,
    preserve_outer_names: false,
  }
  let result = compose_with_options(outer, inner, options~)
  assert_true(result.map.mappings[0].name == Some("sourceName"))
}

///|
test "compose JSON produces a valid regular document" {
  let outer =
    #|{"version":3,"file":"min.js","sources":["mid.js"],"names":[],"mappings":"AAAA"}
  let inner =
    #|{"version":3,"file":"mid.js","sources":["src.ts"],"names":[],"mappings":"AACA"}
  let output = compose_json(outer, inner)
  let document = parse_document(output)
  let decoded = decode_document(document)
  guard decoded.mappings[0].original is Some(original) else {
    fail("expected composed JSON mapping")
  }
  assert_eq(original.line, 1)
  assert_true(decoded.sources[0].url == Some("src.ts"))
}
