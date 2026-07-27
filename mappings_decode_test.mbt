///|
test "decode a canonical single mapping" {
  let mappings = @moon_sourcemap.decode_mappings("AAAA", sources_count=1, names=[])
  assert_eq(mappings.length(), 1)
  assert_true(
    mappings[0] ==
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=0, column=0),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=0,
        column=0,
      ),
    ),
  )
}

///|
test "decode lines, generated-only segments, and names" {
  let mappings = @moon_sourcemap.decode_mappings(
    "AAAAA,C;AACA",
    sources_count=1,
    names=["main"],
  )
  assert_eq(mappings.length(), 3)
  assert_true(
    mappings[0].generated == @moon_sourcemap.Position::new(line=0, column=0),
  )
  assert_true(mappings[0].name == Some("main"))
  assert_true(mappings[1].original is None)
  assert_true(
    mappings[2].original ==
    Some(
      @moon_sourcemap.OriginalPosition::new(source_index=0, line=1, column=0),
    ),
  )
}

///|
test "empty lines advance generated line" {
  let mappings = @moon_sourcemap.decode_mappings(";;AAAA", sources_count=1, names=[])
  assert_eq(mappings.length(), 1)
  assert_eq(mappings[0].generated.line, 2)
  assert_eq(@moon_sourcemap.mappings_line_count(";;AAAA"), 3)
}

///|
test "decode rejects invalid segment field count" {
  try @moon_sourcemap.decode_mappings("AA", sources_count=1, names=[]) catch {
    InvalidMappings(line~, segment~, ..) => {
      assert_eq(line, 0)
      assert_eq(segment, 0)
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid mappings")
  }
}

///|
test "decode rejects out of range source index" {
  try @moon_sourcemap.decode_mappings("ACAA", sources_count=1, names=[]) catch {
    InvalidMappings(message~, ..) =>
      assert_true(message.contains("source index"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid source index")
  }
}

///|
test "decode rejects empty comma segments" {
  for input in [",AAAA", "AAAA,,CAAC", "AAAA,"] {
    try
      @moon_sourcemap.decode_mappings(input, sources_count=1, names=[])
    catch {
      InvalidMappings(..) => ()
      _ => fail("unexpected error")
    } noraise {
      _ => fail("expected empty segment rejection")
    }
  }
}
