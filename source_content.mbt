///|
/// One indexed line of embedded source content.
pub(all) struct SourceLine {
  number : Int
  start : Int
  end : Int
  text : String
} derive(Eq, Debug)

///|
/// A line index over one `sourcesContent` entry.
pub(all) struct SourceTextIndex {
  content : String
  starts : Array[Int]
  ends : Array[Int]
}

///|
/// Source lines surrounding an original position.
pub(all) struct SourceContext {
  source : String?
  focus_line : Int
  focus_column : Int
  start_line : Int
  end_line : Int
  lines : Array[String]
} derive(Eq, Debug)

///|
/// Build a CRLF-aware source text index.
pub fn SourceTextIndex::new(content : String) -> SourceTextIndex {
  let starts : Array[Int] = [0]
  let ends : Array[Int] = []
  let mut cursor = 0
  while cursor < content.length() {
    match content.get_char(cursor) {
      Some('\r') => {
        ends.push(cursor)
        if cursor + 1 < content.length() &&
          content.get_char(cursor + 1) == Some('\n') {
          cursor = cursor + 2
        } else {
          cursor = cursor + 1
        }
        starts.push(cursor)
      }
      Some('\n') => {
        ends.push(cursor)
        cursor = cursor + 1
        starts.push(cursor)
      }
      Some(_) => cursor = cursor + 1
      None => cursor = cursor + 1
    }
  }
  ends.push(content.length())
  { content, starts, ends }
}

///|
/// Return the number of logical source lines.
pub fn SourceTextIndex::line_count(self : SourceTextIndex) -> Int {
  self.starts.length()
}

///|
/// Return one indexed line.
pub fn SourceTextIndex::line(
  self : SourceTextIndex,
  number : Int,
) -> SourceLine? {
  if number < 0 || number >= self.starts.length() {
    None
  } else {
    let start = self.starts[number]
    let end = self.ends[number]
    Some({ number, start, end, text: self.content[start:end].to_owned() })
  }
}

///|
/// Check whether a zero-based original position exists in the source.
pub fn SourceTextIndex::contains(
  self : SourceTextIndex,
  line~ : Int,
  column~ : Int,
) -> Bool {
  match self.line(line) {
    Some(source_line) => column >= 0 && column <= source_line.text.length()
    None => false
  }
}

///|
fn context_bounds(line : Int, radius : Int, count : Int) -> (Int, Int) {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let start = if line < safe_radius { 0 } else { line - safe_radius }
  let wanted_end = line + safe_radius + 1
  let end = if wanted_end > count { count } else { wanted_end }
  (start, end)
}

///|
/// Extract source context around a zero-based position.
pub fn SourceTextIndex::context(
  self : SourceTextIndex,
  source? : String,
  line~ : Int,
  column~ : Int,
  radius? : Int = 1,
) -> SourceContext? {
  if !self.contains(line~, column~) {
    return None
  }
  let (start_line, end_exclusive) = context_bounds(
    line,
    radius,
    self.line_count(),
  )
  let lines : Array[String] = []
  for number in start_line..<end_exclusive {
    match self.line(number) {
      Some(source_line) => lines.push(source_line.text)
      None => ()
    }
  }
  Some({
    source,
    focus_line: line,
    focus_column: column,
    start_line,
    end_line: end_exclusive - 1,
    lines,
  })
}

///|
/// Render source context with line numbers and a caret.
pub fn SourceContext::render(self : SourceContext) -> String {
  let output = StringBuilder()
  for index, line in self.lines {
    let number = self.start_line + index
    let marker = if number == self.focus_line { ">" } else { " " }
    output.write_string("\{marker} \{number} | \{line}")
    output.write_char('\n')
    if number == self.focus_line {
      output.write_string("    | ")
      for _ in 0..<self.focus_column {
        output.write_char(' ')
      }
      output.write_char('^')
      if index + 1 < self.lines.length() {
        output.write_char('\n')
      }
    }
  }
  output.to_string()
}

///|
/// Convert source context to stable JSON.
pub fn SourceContext::to_json(self : SourceContext) -> Json {
  Json::object({
    "source": match self.source {
      Some(source) => Json::string(source)
      None => Json::null()
    },
    "focus_line": Json::number(self.focus_line.to_double()),
    "focus_column": Json::number(self.focus_column.to_double()),
    "start_line": Json::number(self.start_line.to_double()),
    "end_line": Json::number(self.end_line.to_double()),
    "lines": Json::array(self.lines.map(Json::string)),
  })
}

///|
/// Resolve embedded source context for a mapped segment.
pub fn source_context_for_mapping(
  map : DecodedSourceMap,
  mapping : Mapping,
  radius? : Int = 1,
) -> SourceContext? {
  match mapping.original {
    None => None
    Some(original) =>
      if original.source_index < 0 ||
        original.source_index >= map.sources.length() {
        None
      } else {
        let source = map.sources[original.source_index]
        match source.content {
          None => None
          Some(content) =>
            SourceTextIndex::new(content).context(
              source?=source.url,
              line=original.line,
              column=original.column,
              radius~,
            )
        }
      }
  }
}

///|
/// Resolve embedded source context for a symbolized frame.
pub fn source_context_for_frame(
  map : DecodedSourceMap,
  frame : SymbolizedFrame,
  radius? : Int = 1,
) -> SourceContext? {
  if !frame.matched {
    return None
  }
  let mapping = original_position_for(
    map,
    generated=Position::new(
      line=frame.generated.line,
      column=frame.generated.column,
    ),
  )
  match mapping {
    Some(mapping) => source_context_for_mapping(map, mapping, radius~)
    None => None
  }
}
