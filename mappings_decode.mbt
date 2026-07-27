///|
fn mapping_vlq(
  input : String,
  offset : Int,
  line : Int,
  segment : Int,
) -> VlqValue raise SourceMapError {
  decode_vlq_at(input, offset~) catch {
    InvalidVlq(offset=bad_offset, message~) =>
      raise InvalidMappings(line~, segment~, offset=bad_offset, message~)
    other => raise other
  }
}

///|
fn invalid_segment(
  line : Int,
  segment : Int,
  offset : Int,
  message : String,
) -> SourceMapError {
  InvalidMappings(line~, segment~, offset~, message~)
}

///|
/// Decode the ECMA-426 `mappings` field.
///
/// The decoder is strict: segments must contain exactly one, four, or five
/// fields; all accumulated coordinates and indices must remain non-negative;
/// and source/name indices must remain inside the caller-provided tables.
pub fn decode_mappings(
  input : String,
  sources_count~ : Int,
  names~ : ArrayView[String],
) -> Array[Mapping] raise SourceMapError {
  if sources_count < 0 {
    raise InvalidDocument(message="sources_count must be non-negative")
  }
  let mappings : Array[Mapping] = []
  let mut cursor = 0
  let mut generated_line = 0
  let mut generated_column = 0
  let mut source_index = 0
  let mut original_line = 0
  let mut original_column = 0
  let mut name_index = 0
  let mut segment_index = 0
  let mut expect_segment = true
  while cursor < input.length() {
    let ch = match input.get_char(cursor) {
      Some(ch) => ch
      None =>
        raise invalid_segment(
          generated_line, segment_index, cursor, "invalid UTF-16 boundary in mappings",
        )
    }
    if ch == ';' {
      generated_line = generated_line + 1
      generated_column = 0
      segment_index = 0
      expect_segment = true
      cursor = cursor + 1
      continue
    }
    if ch == ',' {
      if expect_segment {
        raise invalid_segment(
          generated_line, segment_index, cursor, "empty mapping segment",
        )
      }
      segment_index = segment_index + 1
      expect_segment = true
      cursor = cursor + 1
      continue
    }
    let segment_offset = cursor
    let fields : Array[Int] = []
    while cursor < input.length() {
      let current = match input.get_char(cursor) {
        Some(current) => current
        None =>
          raise invalid_segment(
            generated_line, segment_index, cursor, "invalid UTF-16 boundary in mappings",
          )
      }
      if current == ',' || current == ';' {
        break
      }
      let decoded = mapping_vlq(input, cursor, generated_line, segment_index)
      fields.push(decoded.value)
      cursor = decoded.next_offset
    }
    if fields.length() != 1 && fields.length() != 4 && fields.length() != 5 {
      raise invalid_segment(
        generated_line, segment_index, segment_offset, "mapping segment must contain 1, 4, or 5 fields",
      )
    }
    generated_column = generated_column + fields[0]
    if generated_column < 0 {
      raise invalid_segment(
        generated_line, segment_index, segment_offset, "generated column became negative",
      )
    }
    let generated = Position::new(line=generated_line, column=generated_column)
    if fields.length() == 1 {
      mappings.push(Mapping::generated_only(generated~))
    } else {
      source_index = source_index + fields[1]
      original_line = original_line + fields[2]
      original_column = original_column + fields[3]
      if source_index < 0 || source_index >= sources_count {
        raise invalid_segment(
          generated_line, segment_index, segment_offset, "source index is outside the sources table",
        )
      }
      if original_line < 0 || original_column < 0 {
        raise invalid_segment(
          generated_line, segment_index, segment_offset, "original position became negative",
        )
      }
      let original = OriginalPosition::new(
        source_index~,
        line=original_line,
        column=original_column,
      )
      let name = if fields.length() == 5 {
        name_index = name_index + fields[4]
        if name_index < 0 || name_index >= names.length() {
          raise invalid_segment(
            generated_line, segment_index, segment_offset, "name index is outside the names table",
          )
        }
        Some(names[name_index])
      } else {
        None
      }
      mappings.push(Mapping::mapped(generated~, original~, name?))
    }
    expect_segment = false
  }
  if expect_segment && input.length() > 0 {
    let last = input.get_char(input.length() - 1)
    if last == Some(',') {
      raise invalid_segment(
        generated_line,
        segment_index,
        input.length() - 1,
        "trailing comma creates an empty mapping segment",
      )
    }
  }
  mappings
}

///|
/// Count generated lines represented by a mappings string.
pub fn mappings_line_count(input : String) -> Int {
  let mut lines = 1
  for ch in input {
    if ch == ';' {
      lines = lines + 1
    }
  }
  lines
}
