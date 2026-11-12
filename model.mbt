///|
/// A zero-based line and UTF-16 column pair.
///
/// ECMA-426 uses zero-based positions internally. CLI inputs are also zero
/// based so there is no hidden conversion at the library boundary.
#derive(Eq, Debug)
pub(all) struct Position {
  line : Int32
  column : Int32
}

///|
/// Construct a generated position.
pub fn Position::new(line~ : Int32, column~ : Int32) -> Position {
  { line, column, }
}

///|
/// Compare two positions in generated order.
pub fn Position::compare(self : Position, other : Position) -> Int32 {
  if self.line < other.line {
    -1
  } else if self.line > other.line {
    1
  } else if self.column < other.column {
    -1
  } else if self.column > other.column {
    1
  } else {
    0
  }
}

///|
/// Return whether both coordinates are non-negative.
pub fn Position::is_valid(self : Position) -> Bool {
  self.line >= 0 && self.column >= 0
}

///|
/// A location in an original source.
///
/// `source_index` indexes the decoded source table.
#derive(Eq, Debug)
pub(all) struct OriginalPosition {
  source_index : Int32
  line : Int32
  column : Int32
}

///|
/// Construct an original position.
pub fn OriginalPosition::new(
  source_index~ : Int32,
  line~ : Int32,
  column~ : Int32,
) -> OriginalPosition {
  { source_index, line, column, }
}

///|
/// Return whether the source index and coordinates are non-negative.
pub fn OriginalPosition::is_valid(self : OriginalPosition) -> Bool {
  self.source_index >= 0 && self.line >= 0 && self.column >= 0
}

///|
/// One decoded Source Map mapping.
///
/// Generated-only segments have `original=None` and `name=None`.
#derive(Eq, Debug)
pub(all) struct Mapping {
  generated : Position
  original : OriginalPosition?
  name : String?
}

///|
/// Construct a generated-only mapping.
pub fn Mapping::generated_only(generated~ : Position) -> Mapping {
  { generated, original: None, name: None, }
}

///|
/// Construct a mapping to an original location.
pub fn Mapping::mapped(
  generated~ : Position,
  original~ : OriginalPosition,
  name? : String,
) -> Mapping {
  { generated, original: Some(original), name, }
}

///|
/// A raw source entry after source table decoding.
#derive(Eq, Debug)
pub(all) struct SourceEntry {
  url : String?
  content : String?
  ignored : Bool
}

///|
/// Construct a decoded source entry.
pub fn SourceEntry::new(
  url? : String,
  content? : String,
  ignored~ : Bool = false,
) -> SourceEntry {
  { url, content, ignored, }
}

///|
/// A regular ECMA-426 source map document.
#derive(Eq, Debug)
pub(all) struct RegularSourceMap {
  version : Int32
  file : String?
  source_root : String?
  sources : Array[String?]
  sources_content : Array[String?]?
  names : Array[String]
  mappings : String
  ignore_list : Array[Int32]
}

///|
/// Construct an empty version-3 regular map.
pub fn RegularSourceMap::new(
  file? : String,
  source_root? : String,
  sources~ : Array[String?] = [],
  sources_content? : Array[String?],
  names~ : Array[String] = [],
  mappings~ : String = "",
  ignore_list~ : Array[Int32] = [],
) -> RegularSourceMap {
  {
    version: 3,
    file,
    source_root,
    sources,
    sources_content,
    names,
    mappings,
    ignore_list,
  }
}

///|
/// An embedded source map and its generated offset.
#derive(Eq, Debug)
pub(all) struct IndexSection {
  offset : Position
  map : SourceMapDocument
}

///|
/// Construct an index section.
pub fn IndexSection::new(
  offset~ : Position,
  map~ : SourceMapDocument,
) -> IndexSection {
  { offset, map, }
}

///|
/// An ECMA-426 index source map.
#derive(Eq, Debug)
pub(all) struct IndexSourceMap {
  version : Int32
  file : String?
  sections : Array[IndexSection]
}

///|
/// Construct an empty version-3 index map.
pub fn IndexSourceMap::new(
  file? : String,
  sections~ : Array[IndexSection] = [],
) -> IndexSourceMap {
  { version: 3, file, sections, }
}

///|
/// The raw JSON document shape accepted by MoonSourceMap.
#derive(Eq, Debug)
pub(all) enum SourceMapDocument {
  Regular(RegularSourceMap)
  Indexed(IndexSourceMap)
}

///|
/// Return the document version.
pub fn SourceMapDocument::version(self : SourceMapDocument) -> Int32 {
  match self {
    Regular(map) => map.version
    Indexed(map) => map.version
  }
}

///|
/// Return the optional generated file name.
pub fn SourceMapDocument::file(self : SourceMapDocument) -> String? {
  match self {
    Regular(map) => map.file
    Indexed(map) => map.file
  }
}

///|
/// A flattened, decoded source map optimized for lookup.
#derive(Eq, Debug)
pub(all) struct DecodedSourceMap {
  file : String?
  sources : Array[SourceEntry]
  mappings : Array[Mapping]
}

///|
/// Construct a decoded map.
pub fn DecodedSourceMap::new(
  file? : String,
  sources~ : Array[SourceEntry] = [],
  mappings~ : Array[Mapping] = [],
) -> DecodedSourceMap {
  { file, sources, mappings, }
}

///|
/// Bias used when a position has no exact mapping.
#derive(Eq, Debug)
pub(all) enum LookupBias {
  GreatestLowerBound
  LeastUpperBound
}

///|
/// Severity for validation diagnostics.
#derive(Eq, Debug)
pub(all) enum DiagnosticSeverity {
  Error
  Warning
}

///|
/// A stable, machine-readable validation diagnostic.
#derive(Eq, Debug)
pub(all) struct Diagnostic {
  severity : DiagnosticSeverity
  code : String
  message : String
  path : String
  mapping_line : Int32?
  segment : Int32?
  offset : Int32?
}

///|
/// Construct an error diagnostic.
pub fn Diagnostic::error(
  code~ : String,
  message~ : String,
  path~ : String = "$",
  mapping_line? : Int32,
  segment? : Int32,
  offset? : Int32,
) -> Diagnostic {
  { severity: Error, code, message, path, mapping_line, segment, offset, }
}

///|
/// Construct a warning diagnostic.
pub fn Diagnostic::warning(
  code~ : String,
  message~ : String,
  path~ : String = "$",
  mapping_line? : Int32,
  segment? : Int32,
  offset? : Int32,
) -> Diagnostic {
  { severity: Warning, code, message, path, mapping_line, segment, offset, }
}

///|
/// Whether the diagnostic blocks conformance.
pub fn Diagnostic::is_error(self : Diagnostic) -> Bool {
  self.severity == Error
}
