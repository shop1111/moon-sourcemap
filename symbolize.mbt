///|
/// A generated stack frame accepted by the symbolizer.
pub(all) struct StackFrame {
  file : String
  line : Int
  column : Int
  function_name : String?
  raw : String
} derive(Eq, Debug)

///|
/// A generated frame and its optional original location.
pub(all) struct SymbolizedFrame {
  generated : StackFrame
  source : String?
  line : Int?
  column : Int?
  name : String?
  ignored : Bool
  matched : Bool
} derive(Eq, Debug)

///|
fn parse_decimal(value : StringView) -> Int? {
  if value.is_empty() {
    return None
  }
  let mut result = 0
  for ch in value {
    if ch < '0' || ch > '9' {
      return None
    }
    let digit = ch.to_int() - '0'.to_int()
    if result > (0x7fffffff - digit) / 10 {
      return None
    }
    result = result * 10 + digit
  }
  Some(result)
}

///|
fn strip_frame_wrapper(value : String) -> (String, String?) {
  let trimmed = value.trim().to_owned()
  if trimmed.has_prefix("at ") {
    let body = trimmed[3:].trim()
    match body.rev_split_once(" (") {
      Some((name, location)) =>
        if location.has_suffix(")") {
          (location[:location.length() - 1].to_owned(), Some(name.to_owned()))
        } else {
          (body.to_owned(), None)
        }
      None => (body.to_owned(), None)
    }
  } else {
    (trimmed, None)
  }
}

///|
/// Parse `file:line:column` and common `at name (file:line:column)` frames.
///
/// Coordinates are zero-based, matching the library API and ECMA-426.
/// Splitting from the right preserves Windows drive letters and URI schemes.
pub fn parse_stack_frame(input : String) -> StackFrame raise SourceMapError {
  let (location, function_name) = strip_frame_wrapper(input)
  let (file_and_line, column_text) = match location.rev_split_once(":") {
    Some(pair) => pair
    None =>
      raise InvalidField(path="$frame", message="expected file:line:column")
  }
  let (file, line_text) = match file_and_line.rev_split_once(":") {
    Some(pair) => pair
    None =>
      raise InvalidField(path="$frame", message="expected file:line:column")
  }
  if file.is_empty() {
    raise InvalidField(path="$frame.file", message="file must not be empty")
  }
  let line = match parse_decimal(line_text) {
    Some(line) => line
    None =>
      raise InvalidField(
        path="$frame.line",
        message="line must be a non-negative integer",
      )
  }
  let column = match parse_decimal(column_text) {
    Some(column) => column
    None =>
      raise InvalidField(
        path="$frame.column",
        message="column must be a non-negative integer",
      )
  }
  { file: file.to_owned(), line, column, function_name, raw: input }
}

///|
fn unmatched_frame(frame : StackFrame) -> SymbolizedFrame {
  {
    generated: frame,
    source: None,
    line: None,
    column: None,
    name: None,
    ignored: false,
    matched: false,
  }
}

///|
/// Symbolize one generated frame.
pub fn symbolize_frame(
  map : DecodedSourceMap,
  frame : StackFrame,
  bias? : LookupBias = GreatestLowerBound,
) -> SymbolizedFrame {
  let mapping = original_position_for(
    map,
    generated=Position::new(line=frame.line, column=frame.column),
    bias~,
  )
  match mapping {
    Some(mapping) =>
      match mapping.original {
        Some(original) =>
          if original.source_index >= 0 &&
            original.source_index < map.sources.length() {
            let source = map.sources[original.source_index]
            {
              generated: frame,
              source: source.url,
              line: Some(original.line),
              column: Some(original.column),
              name: match mapping.name {
                Some(name) => Some(name)
                None => frame.function_name
              },
              ignored: source.ignored,
              matched: true,
            }
          } else {
            unmatched_frame(frame)
          }
        None => unmatched_frame(frame)
      }
    None => unmatched_frame(frame)
  }
}

///|
/// Parse and symbolize newline-separated stack frames.
///
/// Empty lines are ignored. A malformed non-empty line is reported as an
/// error, preventing CI from silently accepting partially processed input.
pub fn symbolize(
  map : DecodedSourceMap,
  frames : String,
  bias? : LookupBias = GreatestLowerBound,
) -> Array[SymbolizedFrame] raise SourceMapError {
  let result : Array[SymbolizedFrame] = []
  for line in frames.split("\n") {
    let text = line.trim()
    if text.is_empty() {
      continue
    }
    result.push(symbolize_frame(map, parse_stack_frame(text.to_owned()), bias~))
  }
  result
}

///|
fn frame_json_string(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn frame_json_number(value : Int?) -> Json {
  match value {
    Some(value) => Json::number(value.to_double())
    None => Json::null()
  }
}

///|
/// Convert a symbolized frame to stable machine-readable JSON.
pub fn SymbolizedFrame::to_json(self : SymbolizedFrame) -> Json {
  Json::object({
    "generated": Json::object({
      "file": Json::string(self.generated.file),
      "line": Json::number(self.generated.line.to_double()),
      "column": Json::number(self.generated.column.to_double()),
      "name": frame_json_string(self.generated.function_name),
    }),
    "original": if self.matched {
      Json::object({
        "source": frame_json_string(self.source),
        "line": frame_json_number(self.line),
        "column": frame_json_number(self.column),
        "name": frame_json_string(self.name),
        "ignored": if self.ignored {
          Json::boolean(true)
        } else {
          Json::boolean(false)
        },
      })
    } else {
      Json::null()
    },
    "matched": if self.matched {
      Json::boolean(true)
    } else {
      Json::boolean(false)
    },
  })
}

///|
/// Render a concise human-readable symbolized frame.
pub fn SymbolizedFrame::render(self : SymbolizedFrame) -> String {
  let generated = "\{self.generated.file}:\{self.generated.line}:\{self.generated.column}"
  if !self.matched {
    generated + " -> <unmapped>"
  } else {
    let source = self.source.unwrap_or("<anonymous>")
    let line = self.line.unwrap_or(0)
    let column = self.column.unwrap_or(0)
    let name = match self.name {
      Some(name) => " " + name
      None => ""
    }
    generated + " -> " + source + ":\{line}:\{column}" + name
  }
}

///|
/// Convert a list of symbolized frames to JSON.
pub fn symbolized_frames_to_json(frames : ArrayView[SymbolizedFrame]) -> Json {
  Json::array(frames.map(frame => frame.to_json()))
}
