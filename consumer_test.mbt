///|
test "consumer indexes batch and reverse queries" {
  let map = lookup_fixture()
  let consumer = @moon_sourcemap.SourceMapConsumer::new(map)
  let results = consumer.original_positions_for([
    @moon_sourcemap.Position::new(line=0, column=0),
    @moon_sourcemap.Position::new(line=0, column=8),
    @moon_sourcemap.Position::new(line=1, column=0),
  ])
  assert_true(results[0] is Some(_))
  assert_true(results[1] is Some(_))
  assert_true(results[2] is None)
  let reverse = consumer.generated_positions_for(source_index=0, line=2)
  assert_eq(reverse.length(), 2)
}

///|
test "consumer duplicate bias matches public lookup" {
  let consumer = @moon_sourcemap.SourceMapConsumer::new(lookup_fixture())
  let glb = consumer.original_position_for(
    generated=@moon_sourcemap.Position::new(line=0, column=5),
  )
  guard glb is Some(glb) else { fail("expected GLB") }
  assert_true(glb.original is None)
  let lub = consumer.original_position_for(
    generated=@moon_sourcemap.Position::new(line=0, column=5),
    bias=LeastUpperBound,
  )
  guard lub is Some(lub) else { fail("expected LUB") }
  assert_true(lub.original is Some(_))
}

///|
test "consumer GetOriginalPositions normalizes unsorted input" {
  let consumer = @moon_sourcemap.SourceMapConsumer::new(
    @moon_sourcemap.DecodedSourceMap::new(mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=2, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=20,
          column=0,
        ),
      ),
      @moon_sourcemap.Mapping::generated_only(
        generated=@moon_sourcemap.Position::new(line=0, column=5),
      ),
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=5),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=5,
          column=1,
        ),
      ),
    ]),
  )
  let result = consumer.get_original_positions(
    generated=@moon_sourcemap.Position::new(line=1, column=0),
  )
  assert_eq(result.length(), 2)
  assert_true(result[0] is None)
  guard result[1] is Some(original) else { fail("expected original position") }
  assert_eq(original.line, 5)
}

///|
test "consumer URL lookup preserves duplicate sources" {
  let map = @moon_sourcemap.DecodedSourceMap::new(sources=[
    @moon_sourcemap.SourceEntry::new(url="same.ts"),
    @moon_sourcemap.SourceEntry::new(url="same.ts", content="different"),
  ])
  let consumer = @moon_sourcemap.SourceMapConsumer::new(map)
  assert_true(consumer.source_index_for_url("same.ts") == Some(0))
  assert_true(consumer.source_indices_for_url("same.ts") == [0, 1])
}

///|
test "consumer statistics describe coverage" {
  let consumer = @moon_sourcemap.SourceMapConsumer::new(lookup_fixture())
  let stats = consumer.stats()
  assert_eq(stats.sources, 2)
  assert_eq(stats.mappings, 4)
  assert_eq(stats.mapped, 3)
  assert_eq(stats.generated_only, 1)
  assert_eq(stats.named, 1)
  assert_eq(stats.ignored_sources, 1)
  assert_eq(stats.generated_lines, 3)
  assert_true(stats.to_json() is Object(_))
}
