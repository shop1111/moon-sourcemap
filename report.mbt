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
/// Mapping distribution for one generated line.
pub(all) struct GeneratedLineUsage {
  line : Int
  segments : Int
  mapped_segments : Int
  generated_only_segments : Int
  named_segments : Int
  duplicate_positions : Int
  first_column : Int
  last_column : Int
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
  generated_line_usage : Array[GeneratedLineUsage]
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
  let lines : Map[Int, Unit] = Map([])
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
fn generated_line_usage(map : DecodedSourceMap) -> Array[GeneratedLineUsage] {
  let sorted = sort_mappings(map.mappings)
  let result : Array[GeneratedLineUsage] = []
  let mut cursor = 0
  while cursor < sorted.length() {
    let line = sorted[cursor].generated.line
    let first_column = sorted[cursor].generated.column
    let mut last_column = first_column
    let mut segments = 0
    let mut mapped_segments = 0
    let mut generated_only_segments = 0
    let mut named_segments = 0
    let mut duplicate_positions = 0
    let mut previous_column : Int? = None
    while cursor < sorted.length() && sorted[cursor].generated.line == line {
      let mapping = sorted[cursor]
      segments = segments + 1
      last_column = mapping.generated.column
      if previous_column == Some(mapping.generated.column) {
        duplicate_positions = duplicate_positions + 1
      }
      previous_column = Some(mapping.generated.column)
      if mapping.original is Some(_) {
        mapped_segments = mapped_segments + 1
      } else {
        generated_only_segments = generated_only_segments + 1
      }
      if mapping.name is Some(_) {
        named_segments = named_segments + 1
      }
      cursor = cursor + 1
    }
    result.push({
      line,
      segments,
      mapped_segments,
      generated_only_segments,
      named_segments,
      duplicate_positions,
      first_column,
      last_column,
    })
  }
  result
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
    generated_line_usage: generated_line_usage(map),
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
/// Convert generated-line usage to JSON.
pub fn GeneratedLineUsage::to_json(self : GeneratedLineUsage) -> Json {
  Json::object({
    "line": Json::number(self.line.to_double()),
    "segments": Json::number(self.segments.to_double()),
    "mapped_segments": Json::number(self.mapped_segments.to_double()),
    "generated_only_segments": Json::number(
      self.generated_only_segments.to_double(),
    ),
    "named_segments": Json::number(self.named_segments.to_double()),
    "duplicate_positions": Json::number(self.duplicate_positions.to_double()),
    "first_column": Json::number(self.first_column.to_double()),
    "last_column": Json::number(self.last_column.to_double()),
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
    "generated_line_usage": Json::array(
      self.generated_line_usage.map(line => line.to_json()),
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

///|
/// Produce reviewer-facing quality diagnostics from report metrics.
pub fn SourceMapReport::diagnostics(
  self : SourceMapReport,
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  if self.mappings == 0 {
    diagnostics.push(
      Diagnostic::warning(
        code="empty_map",
        message="source map contains no mapping segments",
        path="$.mappings",
      ),
    )
  }
  if self.duplicate_positions > 0 {
    diagnostics.push(
      Diagnostic::warning(
        code="duplicate_generated_positions",
        message="source map contains \{self.duplicate_positions} duplicate generated positions",
        path="$.mappings",
      ),
    )
  }
  if self.unreferenced_sources > 0 {
    diagnostics.push(
      Diagnostic::warning(
        code="unreferenced_sources",
        message="\{self.unreferenced_sources} source entries are never referenced",
        path="$.sources",
      ),
    )
  }
  if self.sources > 0 && self.embedded_sources == 0 {
    diagnostics.push(
      Diagnostic::warning(
        code="no_embedded_sources",
        message="sourcesContent is unavailable for every source",
        path="$.sourcesContent",
      ),
    )
  }
  if self.mappings > 0 && self.generated_only_segments * 2 > self.mappings {
    diagnostics.push(
      Diagnostic::warning(
        code="mostly_generated_only",
        message="more than half of mapping segments lack original positions",
        path="$.mappings",
      ),
    )
  }
  diagnostics
}

///|
/// Parse, flatten and analyze a source-map JSON document.
pub fn analyze_source_map_json(
  input : StringView,
  map_url? : String,
) -> SourceMapReport raise SourceMapError {
  analyze_source_map(decode_document(parse_document(input), map_url?))
}

///|
/// Percentage of sources referenced by at least one mapping.
pub fn SourceMapReport::source_coverage_percent(self : SourceMapReport) -> Int {
  if self.sources == 0 {
    100
  } else {
    self.referenced_sources * 100 / self.sources
  }
}

///|
/// Percentage of segments carrying original positions.
pub fn SourceMapReport::mapping_coverage_percent(self : SourceMapReport) -> Int {
  if self.mappings == 0 {
    100
  } else {
    self.mapped_segments * 100 / self.mappings
  }
}

///|
/// Percentage of sources with embedded content.
pub fn SourceMapReport::content_coverage_percent(self : SourceMapReport) -> Int {
  if self.sources == 0 {
    100
  } else {
    self.embedded_sources * 100 / self.sources
  }
}

///|
/// Return whether every segment maps to an original position.
pub fn SourceMapReport::has_complete_mappings(self : SourceMapReport) -> Bool {
  self.mappings > 0 && self.generated_only_segments == 0
}

///|
/// Return whether every declared source is referenced.
pub fn SourceMapReport::has_complete_source_usage(
  self : SourceMapReport,
) -> Bool {
  self.unreferenced_sources == 0
}

///|
/// Return whether every source carries embedded content.
pub fn SourceMapReport::has_complete_sources_content(
  self : SourceMapReport,
) -> Bool {
  self.sources == self.embedded_sources
}

///|
/// Return a concise CI summary line.
pub fn SourceMapReport::summary(self : SourceMapReport) -> String {
  "mappings=\{self.mappings} mapped=\{self.mapping_coverage_percent()}% " +
  "sources=\{self.sources} referenced=\{self.source_coverage_percent()}% " +
  "embedded=\{self.content_coverage_percent()}% duplicates=\{self.duplicate_positions}"
}

///|
/// Return generated-line metrics for an exact line number.
pub fn SourceMapReport::generated_line(
  self : SourceMapReport,
  line : Int,
) -> GeneratedLineUsage? {
  for usage in self.generated_line_usage {
    if usage.line == line {
      return Some(usage)
    }
  }
  None
}

///|
/// Return the generated line with the most mapping segments.
pub fn SourceMapReport::busiest_generated_line(
  self : SourceMapReport,
) -> GeneratedLineUsage? {
  let mut busiest : GeneratedLineUsage? = None
  for usage in self.generated_line_usage {
    match busiest {
      Some(previous) =>
        if usage.segments > previous.segments {
          busiest = Some(usage)
        }
      None => busiest = Some(usage)
    }
  }
  busiest
}

///|
/// Count generated lines that contain no mapping segments.
pub fn SourceMapReport::empty_generated_lines(self : SourceMapReport) -> Int {
  if self.generated_lines == 0 {
    return 0
  }
  self.generated_lines - self.generated_line_usage.length()
}

///|
/// Return source indexes that are never referenced by mappings.
pub fn SourceMapReport::unreferenced_source_indices(
  self : SourceMapReport,
) -> Array[Int] {
  let result : Array[Int] = []
  for usage in self.source_usage {
    if usage.mapped_segments == 0 {
      result.push(usage.source_index)
    }
  }
  result
}

///|
/// Return source indexes marked as ignored.
pub fn SourceMapReport::ignored_source_indices(
  self : SourceMapReport,
) -> Array[Int] {
  let result : Array[Int] = []
  for usage in self.source_usage {
    if usage.ignored {
      result.push(usage.source_index)
    }
  }
  result
}

///|
/// Return source indexes without embedded source content.
pub fn SourceMapReport::sources_without_content(
  self : SourceMapReport,
) -> Array[Int] {
  let result : Array[Int] = []
  for usage in self.source_usage {
    if !usage.has_content {
      result.push(usage.source_index)
    }
  }
  result
}

///|
/// Return generated line numbers containing duplicate positions.
pub fn SourceMapReport::lines_with_duplicates(
  self : SourceMapReport,
) -> Array[Int] {
  let result : Array[Int] = []
  for usage in self.generated_line_usage {
    if usage.duplicate_positions > 0 {
      result.push(usage.line)
    }
  }
  result
}

///|
/// Return generated lines containing at least one generated-only segment.
pub fn SourceMapReport::generated_only_lines(
  self : SourceMapReport,
) -> Array[Int] {
  let result : Array[Int] = []
  for usage in self.generated_line_usage {
    if usage.generated_only_segments > 0 {
      result.push(usage.line)
    }
  }
  result
}

///|
/// Return whether a source is referenced by at least one segment.
pub fn SourceUsage::is_referenced(self : SourceUsage) -> Bool {
  self.mapped_segments > 0
}

///|
/// Percentage of segments on this line that carry original positions.
pub fn GeneratedLineUsage::mapping_coverage_percent(
  self : GeneratedLineUsage,
) -> Int {
  if self.segments == 0 {
    100
  } else {
    self.mapped_segments * 100 / self.segments
  }
}

///|
/// Percentage of mapped segments that preserve a symbol name.
pub fn SourceMapReport::named_mapping_percent(self : SourceMapReport) -> Int {
  if self.mapped_segments == 0 {
    100
  } else {
    self.named_segments * 100 / self.mapped_segments
  }
}

///|
/// Percentage of source entries marked as ignored.
pub fn SourceMapReport::ignored_source_percent(self : SourceMapReport) -> Int {
  if self.sources == 0 {
    0
  } else {
    self.ignored_sources * 100 / self.sources
  }
}

///|
/// Find the usage summary for a source index.
pub fn SourceMapReport::source(
  self : SourceMapReport,
  source_index : Int,
) -> SourceUsage? {
  for usage in self.source_usage {
    if usage.source_index == source_index {
      return Some(usage)
    }
  }
  None
}

///|
/// Return whether the report contains a mapping or source-quality warning.
pub fn SourceMapReport::has_quality_warnings(self : SourceMapReport) -> Bool {
  self.generated_only_segments > 0 ||
  self.duplicate_positions > 0 ||
  self.unreferenced_sources > 0
}

///|
/// Count source entries that are both referenced and backed by embedded text.
pub fn SourceMapReport::usable_embedded_sources(self : SourceMapReport) -> Int {
  let mut count = 0
  for usage in self.source_usage {
    if usage.is_referenced() && usage.has_content {
      count += 1
    }
  }
  count
}
