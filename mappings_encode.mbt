///|
fn find_name_index(names : ArrayView[String], target : String) -> Int? {
  for index, name in names {
    if name == target {
      return Some(index)
    }
  }
  None
}

///|
fn append_vlq(output : StringBuilder, value : Int) -> Unit raise SourceMapError {
  output.write_string(encode_vlq(value))
}

///|
/// Encode decoded mappings into the canonical ECMA-426 delta representation.
///
/// Mappings must be sorted by generated line and column. Original coordinates
/// and source indices must be non-negative. Named mappings must refer to an
/// entry in `names`.
pub fn encode_mappings(
  mappings : ArrayView[Mapping],
  names~ : ArrayView[String],
) -> String raise SourceMapError {
  let output = StringBuilder()
  let mut generated_line = 0
  let mut generated_column = 0
  let mut source_index = 0
  let mut original_line = 0
  let mut original_column = 0
  let mut name_index = 0
  let mut segment_on_line = false
  let mut previous : Position? = None
  for mapping in mappings {
    if !mapping.generated.is_valid() {
      raise InvalidDocument(message="generated positions must be non-negative")
    }
    match previous {
      Some(position) =>
        if position.compare(mapping.generated) > 0 {
          raise InvalidDocument(
            message="mappings must be sorted by generated position",
          )
        }
      None => ()
    }
    while generated_line < mapping.generated.line {
      output.write_char(';')
      generated_line = generated_line + 1
      generated_column = 0
      segment_on_line = false
    }
    if segment_on_line {
      output.write_char(',')
    }
    append_vlq(output, mapping.generated.column - generated_column)
    generated_column = mapping.generated.column
    match mapping.original {
      None =>
        if mapping.name is Some(_) {
          raise InvalidDocument(
            message="generated-only mappings cannot carry a name",
          )
        }
      Some(original) => {
        if !original.is_valid() {
          raise InvalidDocument(
            message="original positions and source indices must be non-negative",
          )
        }
        append_vlq(output, original.source_index - source_index)
        append_vlq(output, original.line - original_line)
        append_vlq(output, original.column - original_column)
        source_index = original.source_index
        original_line = original.line
        original_column = original.column
        match mapping.name {
          None => ()
          Some(name) =>
            match find_name_index(names, name) {
              None =>
                raise InvalidDocument(
                  message="mapping name is not present in the names table",
                )
              Some(index) => {
                append_vlq(output, index - name_index)
                name_index = index
              }
            }
        }
      }
    }
    segment_on_line = true
    previous = Some(mapping.generated)
  }
  output.to_string()
}

///|
/// Return a copy sorted by generated position.
///
/// Sorting is stable for entries that share the same generated position.
pub fn sort_mappings(mappings : ArrayView[Mapping]) -> Array[Mapping] {
  let result = mappings.to_owned()
  result.sort_by((left, right) => left.generated.compare(right.generated))
  result
}

///|
/// Return true when mappings are in generated order.
pub fn mappings_are_sorted(mappings : ArrayView[Mapping]) -> Bool {
  if mappings.length() < 2 {
    return true
  }
  for index in 1..<mappings.length() {
    if mappings[index - 1].generated.compare(mappings[index].generated) > 0 {
      return false
    }
  }
  true
}
