///|
test "encode canonical mappings" {
  let mappings = [
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=0, column=0),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=0,
        column=0,
      ),
      name="main",
    ),
    @moon_sourcemap.Mapping::generated_only(
      generated=@moon_sourcemap.Position::new(line=0, column=1),
    ),
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=1, column=0),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=1,
        column=0,
      ),
    ),
  ]
  assert_eq(
    @moon_sourcemap.encode_mappings(mappings, names=["main"]),
    "AAAAA,C;AACA",
  )
}

///|
test "mapping codec round trips representative mapping sets" {
  for encoded in ["", "AAAA", "AAAAA,C;AACA", ";;AAAA", "A,CAAC,GAAG"] {
    let names = if encoded.contains("AAAAA") { ["main"] } else { [] }
    let decoded = @moon_sourcemap.decode_mappings(
      encoded,
      sources_count=1,
      names~,
    )
    assert_eq(@moon_sourcemap.encode_mappings(decoded, names~), encoded)
  }
}

///|
test "encoder rejects unsorted mappings" {
  let mappings = [
    @moon_sourcemap.Mapping::generated_only(
      generated=@moon_sourcemap.Position::new(line=1, column=0),
    ),
    @moon_sourcemap.Mapping::generated_only(
      generated=@moon_sourcemap.Position::new(line=0, column=0),
    ),
  ]
  assert_false(@moon_sourcemap.mappings_are_sorted(mappings))
  try @moon_sourcemap.encode_mappings(mappings, names=[]) catch {
    InvalidDocument(message~) => assert_true(message.contains("sorted"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected unsorted mappings rejection")
  }
}

///|
test "sort mappings uses line and column order" {
  let mappings = [
    @moon_sourcemap.Mapping::generated_only(
      generated=@moon_sourcemap.Position::new(line=2, column=0),
    ),
    @moon_sourcemap.Mapping::generated_only(
      generated=@moon_sourcemap.Position::new(line=0, column=4),
    ),
    @moon_sourcemap.Mapping::generated_only(
      generated=@moon_sourcemap.Position::new(line=0, column=1),
    ),
  ]
  let sorted = @moon_sourcemap.sort_mappings(mappings)
  assert_eq(sorted[0].generated.line, 0)
  assert_eq(sorted[0].generated.column, 1)
  assert_eq(sorted[1].generated.column, 4)
  assert_eq(sorted[2].generated.line, 2)
}

///|
test "encoder rejects unknown names" {
  let mapping = @moon_sourcemap.Mapping::mapped(
    generated=@moon_sourcemap.Position::new(line=0, column=0),
    original=@moon_sourcemap.OriginalPosition::new(
      source_index=0,
      line=0,
      column=0,
    ),
    name="missing",
  )
  try @moon_sourcemap.encode_mappings([mapping], names=[]) catch {
    InvalidDocument(message~) => assert_true(message.contains("names table"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected unknown name rejection")
  }
}
