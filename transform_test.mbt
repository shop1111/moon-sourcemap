///|
test "canonicalize resolves duplicates and prunes sources" {
  let map = @moon_sourcemap.DecodedSourceMap::new(
    sources=[
      @moon_sourcemap.SourceEntry::new(url="unused.ts"),
      @moon_sourcemap.SourceEntry::new(url="used.ts"),
    ],
    mappings=[
      @moon_sourcemap.Mapping::generated_only(
        generated=@moon_sourcemap.Position::new(line=0, column=1),
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=1,
          line=2,
          column=3,
        ),
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=1),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=1,
          line=4,
          column=5,
        ),
      ),
    ],
  )
  let result = @moon_sourcemap.canonicalize(map)
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
  let sliced = @moon_sourcemap.slice_generated(
    map,
    start=@moon_sourcemap.Position::new(line=0, column=5),
    end=@moon_sourcemap.Position::new(line=2, column=3),
  )
  assert_eq(sliced.mappings.length(), 1)
  let shifted = @moon_sourcemap.shift_generated(
    sliced,
    line_delta=4,
    first_line_column_delta=7,
  )
  assert_eq(shifted.mappings[0].generated.line, 4)
  assert_eq(shifted.mappings[0].generated.column, 12)
}

///|
test "concatenate offsets and remaps sources" {
  let first = @moon_sourcemap.DecodedSourceMap::new(
    sources=[@moon_sourcemap.SourceEntry::new(url="a.ts")],
    mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=1),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=0,
          column=0,
        ),
      ),
    ],
  )
  let second = @moon_sourcemap.DecodedSourceMap::new(
    sources=[@moon_sourcemap.SourceEntry::new(url="b.ts")],
    mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=2),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=1,
          column=0,
        ),
      ),
    ],
  )
  let result = @moon_sourcemap.concatenate(
    [
      (@moon_sourcemap.Position::new(line=0, column=0), first),
      (@moon_sourcemap.Position::new(line=1, column=4), second),
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
