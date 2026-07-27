///|
test "canonicalize resolves duplicates and prunes sources" {
  let map = DecodedSourceMap::new(
    sources=[SourceEntry::new(url="unused.ts"), SourceEntry::new(url="used.ts")],
    mappings=[
      Mapping::generated_only(generated=Position::new(line=0, column=1)),
      Mapping::mapped(
        generated=Position::new(line=0, column=0),
        original=OriginalPosition::new(source_index=1, line=2, column=3),
      ),
      Mapping::mapped(
        generated=Position::new(line=0, column=1),
        original=OriginalPosition::new(source_index=1, line=4, column=5),
      ),
    ],
  )
  let result = canonicalize(map)
  assert_eq(result.map.sources.length(), 1)
  assert_eq(result.map.mappings.length(), 2)
  assert_eq(result.report.duplicates_removed, 1)
  assert_eq(result.report.sources_removed, 1)
  guard result.map.mappings[1].original is Some(original) else {
    fail("expected mapped duplicate winner")
  }
  assert_eq(original.source_index, 0)
}

///|
test "generated slice is half open and shifts safely" {
  let map = lookup_fixture()
  let sliced = slice_generated(
    map,
    start=Position::new(line=0, column=5),
    end=Position::new(line=2, column=3),
  )
  assert_eq(sliced.mappings.length(), 1)
  let shifted = shift_generated(sliced, line_delta=4, first_line_column_delta=7)
  assert_eq(shifted.mappings[0].generated.line, 4)
  assert_eq(shifted.mappings[0].generated.column, 12)
}

///|
test "concatenate offsets and remaps sources" {
  let first = DecodedSourceMap::new(sources=[SourceEntry::new(url="a.ts")], mappings=[
    Mapping::mapped(
      generated=Position::new(line=0, column=1),
      original=OriginalPosition::new(source_index=0, line=0, column=0),
    ),
  ])
  let second = DecodedSourceMap::new(sources=[SourceEntry::new(url="b.ts")], mappings=[
    Mapping::mapped(
      generated=Position::new(line=0, column=2),
      original=OriginalPosition::new(source_index=0, line=1, column=0),
    ),
  ])
  let result = concatenate(
    [
      (Position::new(line=0, column=0), first),
      (Position::new(line=1, column=4), second),
    ],
    file="bundle.js",
  )
  assert_eq(result.sources.length(), 2)
  assert_eq(result.mappings[1].generated.line, 1)
  assert_eq(result.mappings[1].generated.column, 6)
  guard result.mappings[1].original is Some(original) else {
    fail("expected mapped concatenation")
  }
  assert_eq(original.source_index, 1)
}
