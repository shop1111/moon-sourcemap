///|
test "Base64-VLQ encodes canonical small values" {
  assert_eq(@moon_sourcemap.encode_vlq(0), "A")
  assert_eq(@moon_sourcemap.encode_vlq(1), "C")
  assert_eq(@moon_sourcemap.encode_vlq(-1), "D")
  assert_eq(@moon_sourcemap.encode_vlq(16), "gB")
  assert_eq(@moon_sourcemap.encode_vlq(-16), "hB")
}

///|
test "Base64-VLQ round trips representative values" {
  for value in [-100000, -4096, -33, -1, 0, 1, 31, 32, 4096, 100000] {
    assert_eq(
      @moon_sourcemap.decode_vlq(@moon_sourcemap.encode_vlq(value)),
      value,
    )
  }
}

///|
test "Base64-VLQ reports the first unread offset" {
  let first = @moon_sourcemap.decode_vlq_at("CD", offset=0)
  let second = @moon_sourcemap.decode_vlq_at("CD", offset=first.next_offset)
  assert_eq(first.value, 1)
  assert_eq(first.next_offset, 1)
  assert_eq(second.value, -1)
  assert_eq(second.next_offset, 2)
}

///|
test "Base64-VLQ rejects invalid characters" {
  try @moon_sourcemap.decode_vlq("?") catch {
    InvalidVlq(offset~, ..) => assert_eq(offset, 0)
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid VLQ")
  }
}

///|
test "Base64-VLQ rejects unterminated continuation" {
  try @moon_sourcemap.decode_vlq("g") catch {
    InvalidVlq(offset~, ..) => assert_eq(offset, 1)
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid VLQ")
  }
}
