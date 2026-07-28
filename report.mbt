///|
/// A half-open generated interval owned by one mapping.
///
/// `end=None` means the segment remains active to the end of its generated
/// line. A next mapping on another line does not close the previous line.
pub(all) struct GeneratedSpan {
  mapping : Mapping
  end : Position?
} derive(Eq, Debug)

///|
/// Per-source mapping usage metrics.
pub(all) struct SourceUsage {
  source_index : Int
  url : String?
  mapped_segments : Int
  named_segments : Int
  original_lines : Int
  ignored : Bool
  has_content : Bool
} derive(Eq, Debug)

///|
/// Structural quality report for one decoded source map.
pub(all) struct SourceMapReport {
  file : String?
  sources : Int
  mappings : Int
  mapped_segments : Int
  generated_only_segments : Int
  named_segments : Int
  ignored_sources : Int
  embedded_sources : Int
  referenced_sources : Int
  unreferenced_sources : Int
  generated_lines : Int
  original_lines : Int
  duplicate_positions : Int
  open_spans : Int
  source_usage : Array[SourceUsage]
} derive(Eq, Debug)

///|
/// Return whether a generated position is covered by this span.
pub fn GeneratedSpan::contains(
  self : GeneratedSpan,
  position : Position,
) -> Bool {
  if position.line != self.mapping.generated.line ||
    position.compare(self.mapping.generated) < 0 {
    return false
  }
  match self.end {
    Some(end) => position.compare(end) < 0
    None => true
  }
}

///|
/// Return the finite column width, or `None` for an open span.
pub fn GeneratedSpan::column_width(self : GeneratedSpan) -> Int? {
  match self.end {
    Some(end) =>
      if end.line == self.mapping.generated.line {
        Some(end.column - self.mapping.generated.column)
      } else {
        None
      }
    None => None
  }
}

///|
/// Convert ordered mappings to generated spans.
///
/// Duplicate positions produce zero-width spans except for the last duplicate,
/// matching GLB lookup behavior.
pub fn mapping_spans(map : DecodedSourceMap) -> Array[GeneratedSpan] {
  let mappings = if mappings_are_sorted(map.mappings) {
    map.mappings.copy()
  } else {
    sort_mappings(map.mappings)
  }
  let spans : Array[GeneratedSpan] = []
  for index, mapping in mappings {
    let end = if index + 1 < mappings.length() &&
      mappings[index + 1].generated.line == mapping.generated.line {
      Some(mappings[index + 1].generated)
    } else {
      None
    }
    spans.push({ mapping, end })
  }
  spans
}

///|
/// Return spans beginning on one generated line.
pub fn mapping_spans_for_line(
  map : DecodedSourceMap,
  line : Int,
) -> Array[GeneratedSpan] {
  if line < 0 {
    return []
  }
  mapping_spans(map).filter(span => span.mapping.generated.line == line)
}

///|
fn duplicate_generated_positions(mappings : ArrayView[Mapping]) -> Int {
  if mappings.length() < 2 {
    return 0
  }
  let sorted = sort_mappings(mappings)
  let mut duplicates = 0
  for index in 1..<sorted.length() {
    if sorted[index - 1].generated == sorted[index].generated {
      duplicates = duplicates + 1
    }
  }
  duplicates
}

///|
fn source_usage_for(map : DecodedSourceMap, source_index : Int) -> SourceUsage {
  let source = map.sources[source_index]
  let lines : Map[Int, Unit] = {}
  let mut mapped_segments = 0
  let mut named_segments = 0
  for mapping in map.mappings {
    match mapping.original {
      Some(original) =>
        if original.source_index == source_index {
          mapped_segments = mapped_segments + 1
          lines[original.line] = ()
          if mapping.name is Some(_) {
            named_segments = named_segments + 1
          }
        }
      None => ()
    }
  }
  {
    source_index,
    url: source.url,
    mapped_segments,
    named_segments,
    original_lines: lines.length(),
    ignored: source.ignored,
    has_content: source.content is Some(_),
  }
}

///|
fn all_source_usage(map : DecodedSourceMap) -> Array[SourceUsage] {
  let usage : Array[SourceUsage] = []
  for source_index in 0..<map.sources.length() {
    usage.push(source_usage_for(map, source_index))
  }
  usage
}

///|
/// Analyze decoded map structure without requiring generated source text.
///
/// Counts refer to mapping segments rather than bytes or characters, because a
/// source map does not carry the length of the generated artifact.
pub fn analyze_source_map(map : DecodedSourceMap) -> SourceMapReport {
  let stats = SourceMapConsumer::new(map).stats()
  let usage = all_source_usage(map)
  let mut referenced_sources = 0
  let mut ignored_sources = 0
  let mut embedded_sources = 0
  for source in usage {
    if source.mapped_segments > 0 {
      referenced_sources = referenced_sources + 1
    }
    if source.ignored {
      ignored_sources = ignored_sources + 1
    }
    if source.has_content {
      embedded_sources = embedded_sources + 1
    }
  }
  let spans = mapping_spans(map)
  let mut open_spans = 0
  for span in spans {
    if span.end is None {
      open_spans = open_spans + 1
    }
  }
  {
    file: map.file,
    sources: stats.sources,
    mappings: stats.mappings,
    mapped_segments: stats.mapped,
    generated_only_segments: stats.generated_only,
    named_segments: stats.named,
    ignored_sources,
    embedded_sources,
    referenced_sources,
    unreferenced_sources: stats.sources - referenced_sources,
    generated_lines: stats.generated_lines,
    original_lines: stats.original_lines,
    duplicate_positions: duplicate_generated_positions(map.mappings),
    open_spans,
    source_usage: usage,
  }
}

///|
fn report_optional_string(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
/// Convert source usage metrics to JSON.
pub fn SourceUsage::to_json(self : SourceUsage) -> Json {
  Json::object({
    "source_index": Json::number(self.source_index.to_double()),
    "url": report_optional_string(self.url),
    "mapped_segments": Json::number(self.mapped_segments.to_double()),
    "named_segments": Json::number(self.named_segments.to_double()),
    "original_lines": Json::number(self.original_lines.to_double()),
    "ignored": Json::boolean(self.ignored),
    "has_content": Json::boolean(self.has_content),
  })
}

///|
/// Convert the complete report to stable JSON.
pub fn SourceMapReport::to_json(self : SourceMapReport) -> Json {
  Json::object({
    "file": report_optional_string(self.file),
    "sources": Json::number(self.sources.to_double()),
    "mappings": Json::number(self.mappings.to_double()),
    "mapped_segments": Json::number(self.mapped_segments.to_double()),
    "generated_only_segments": Json::number(
      self.generated_only_segments.to_double(),
    ),
    "named_segments": Json::number(self.named_segments.to_double()),
    "ignored_sources": Json::number(self.ignored_sources.to_double()),
    "embedded_sources": Json::number(self.embedded_sources.to_double()),
    "referenced_sources": Json::number(self.referenced_sources.to_double()),
    "unreferenced_sources": Json::number(self.unreferenced_sources.to_double()),
    "generated_lines": Json::number(self.generated_lines.to_double()),
    "original_lines": Json::number(self.original_lines.to_double()),
    "duplicate_positions": Json::number(self.duplicate_positions.to_double()),
    "open_spans": Json::number(self.open_spans.to_double()),
    "source_usage": Json::array(
      self.source_usage.map(source => source.to_json()),
    ),
  })
}

///|
fn report_source_label(source : SourceUsage) -> String {
  match source.url {
    Some(url) => url
    None => "<anonymous:\{source.source_index}>"
  }
}

///|
/// Render a compact report for terminals and CI logs.
pub fn SourceMapReport::render(self : SourceMapReport) -> String {
  let output = StringBuilder()
  let file_label = self.file.unwrap_or("<anonymous>")
  output.write_string(
    "file: \{file_label}\n" +
    "sources: \{self.sources} (\{self.referenced_sources} referenced, " +
    "\{self.unreferenced_sources} unreferenced, \{self.embedded_sources} embedded)\n" +
    "mappings: \{self.mappings} (\{self.mapped_segments} mapped, " +
    "\{self.generated_only_segments} generated-only, \{self.named_segments} named)\n" +
    "lines: \{self.generated_lines} generated, \{self.original_lines} original\n" +
    "duplicates: \{self.duplicate_positions}; open spans: \{self.open_spans}\n",
  )
  for source in self.source_usage {
    let flags = StringBuilder()
    if source.ignored {
      flags.write_string(" ignored")
    }
    if source.has_content {
      flags.write_string(" embedded")
    }
    output.write_string(
      "[\{source.source_index}] \{report_source_label(source)}: " +
      "\{source.mapped_segments} mappings, \{source.original_lines} lines" +
      flags.to_string() +
      "\n",
    )
  }
  output.to_string()
}
