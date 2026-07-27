///|
/// One decoded signed Base64-VLQ value and the first unread UTF-16 offset.
pub(all) struct VlqValue {
  value : Int
  next_offset : Int
} derive(Eq, Debug)

///|
const MAX_VLQ_INT : Int = 2147483647

///|
fn base64_digit_to_char(value : Int) -> Char {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  match alphabet.get_char(value) {
    Some(ch) => ch
    None => 'A'
  }
}

///|
fn base64_char_to_digit(ch : Char) -> Int? {
  match ch {
    'A'..='Z' => Some(ch.to_int() - 'A')
    'a'..='z' => Some(ch.to_int() - 'a' + 26)
    '0'..='9' => Some(ch.to_int() - '0' + 52)
    '+' => Some(62)
    '/' => Some(63)
    _ => None
  }
}

///|
/// Encode one signed integer using the Base64-VLQ alphabet required by
/// ECMA-426.
///
pub fn encode_vlq(value : Int) -> String {
  let wide = value.to_int64()
  let signed : Int64 = if wide < 0L { -wide * 2L + 1L } else { wide * 2L }
  let output = StringBuilder()
  let mut remaining = signed
  for ;; {
    let mut digit = (remaining % 32L).to_int()
    remaining = remaining / 32L
    if remaining > 0L {
      digit = digit + 32
    }
    output.write_char(base64_digit_to_char(digit))
    if remaining == 0 {
      break
    }
  }
  output.to_string()
}

///|
/// Decode one signed Base64-VLQ value at `offset`.
///
/// The returned `next_offset` can be passed into another call when decoding a
/// Source Map segment.
pub fn decode_vlq_at(
  input : String,
  offset~ : Int,
) -> VlqValue raise SourceMapError {
  if offset < 0 || offset >= input.length() {
    raise InvalidVlq(offset~, message="expected a Base64-VLQ value")
  }
  let mut cursor = offset
  let mut accumulated = 0L
  let mut multiplier = 1L
  let mut digits = 0
  for ;; {
    let ch = match input.get_char(cursor) {
      Some(ch) => ch
      None =>
        raise InvalidVlq(offset=cursor, message="unterminated Base64-VLQ value")
    }
    let digit = match base64_char_to_digit(ch) {
      Some(value) => value
      None =>
        raise InvalidVlq(offset=cursor, message="invalid Base64-VLQ character")
    }
    let continuation = digit >= 32
    let payload = digit % 32
    if payload > 0 && multiplier > 4294967297L / payload.to_int64() {
      raise InvalidVlq(offset=cursor, message="Base64-VLQ value overflows Int")
    }
    let contribution = payload.to_int64() * multiplier
    if accumulated > 4294967297L - contribution {
      raise InvalidVlq(offset=cursor, message="Base64-VLQ value overflows Int")
    }
    accumulated = accumulated + contribution
    cursor = cursor + 1
    digits = digits + 1
    if !continuation {
      break
    }
    if digits >= 7 {
      raise InvalidVlq(offset=cursor, message="Base64-VLQ value is too long")
    }
    if cursor >= input.length() {
      raise InvalidVlq(offset=cursor, message="unterminated Base64-VLQ value")
    }
    if multiplier > 4294967297L / 32L {
      raise InvalidVlq(
        offset=cursor,
        message="Base64-VLQ multiplier overflows Int",
      )
    }
    multiplier = multiplier * 32L
  }
  let negative = accumulated % 2L == 1L
  let magnitude = accumulated / 2L
  if !negative && magnitude > MAX_VLQ_INT.to_int64() {
    raise InvalidVlq(offset~, message="positive Base64-VLQ value overflows Int")
  }
  let value = if negative { (-magnitude).to_int() } else { magnitude.to_int() }
  { value, next_offset: cursor }
}

///|
/// Decode a string containing exactly one Base64-VLQ value.
pub fn decode_vlq(input : String) -> Int raise SourceMapError {
  let decoded = decode_vlq_at(input, offset=0)
  if decoded.next_offset != input.length() {
    raise InvalidVlq(
      offset=decoded.next_offset,
      message="unexpected data after Base64-VLQ value",
    )
  }
  decoded.value
}
