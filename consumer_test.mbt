///|
test "consumer indexes batch and reverse queries" {
  let map = lookup_fixture()
  let consumer = SourceMapConsumer::new(map)
  let results = consumer.original_positions_for([
    Position::new(line=0, column=0),
    Position::new(line=0, column=8),
    Position::new(line=1, column=0),
  ])
  assert_true(results[0] is Some(_))
  assert_true(results[1] is Some(_))
  assert_true(results[2] is None)
  let reverse = consumer.generated_positions_for(source_index=0, line=2)
  assert_eq(reverse.length(), 2)
}

///|
test "consumer duplicate bias matches public lookup" {
  let consumer = SourceMapConsumer::new(lookup_fixture())
  let glb = consumer.original_position_for(
    generated=Position::new(line=0, column=5),
  )
  guard glb is Some(glb) else { fail("expected GLB") }
  assert_true(glb.original is None)
  let lub = consumer.original_position_for(
    generated=Position::new(line=0, column=5),
    bias=LeastUpperBound,
  )
  guard lub is Some(lub) else { fail("expected LUB") }
  assert_true(lub.original is Some(_))
}

///|
test "consumer URL lookup preserves duplicate sources" {
  let map = DecodedSourceMap::new(sources=[
    SourceEntry::new(url="same.ts"),
    SourceEntry::new(url="same.ts", content="different"),
  ])
  let consumer = SourceMapConsumer::new(map)
  assert_true(consumer.source_index_for_url("same.ts") == Some(0))
  assert_true(consumer.source_indices_for_url("same.ts") == [0, 1])
}

///|
test "consumer statistics describe coverage" {
  let consumer = SourceMapConsumer::new(lookup_fixture())
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
