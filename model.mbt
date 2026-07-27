///|
/// A zero-based line and UTF-16 column pair.
///
/// ECMA-426 uses zero-based positions internally. CLI inputs are also zero
/// based so there is no hidden conversion at the library boundary.
pub(all) struct Position {
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// Construct a generated position.
pub fn Position::new(line~ : Int, column~ : Int) -> Position {
  { line, column }
}

///|
/// Compare two positions in generated order.
pub fn Position::compare(self : Position, other : Position) -> Int {
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
pub(all) struct OriginalPosition {
  source_index : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// Construct an original position.
pub fn OriginalPosition::new(
  source_index~ : Int,
  line~ : Int,
  column~ : Int,
) -> OriginalPosition {
  { source_index, line, column }
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
pub(all) struct Mapping {
  generated : Position
  original : OriginalPosition?
  name : String?
} derive(Eq, Debug)

///|
/// Construct a generated-only mapping.
pub fn Mapping::generated_only(generated~ : Position) -> Mapping {
  { generated, original: None, name: None }
}

///|
/// Construct a mapping to an original location.
pub fn Mapping::mapped(
  generated~ : Position,
  original~ : OriginalPosition,
  name? : String,
) -> Mapping {
  { generated, original: Some(original), name }
}

///|
/// A raw source entry after source table decoding.
pub(all) struct SourceEntry {
  url : String?
  content : String?
  ignored : Bool
} derive(Eq, Debug)

///|
/// Construct a decoded source entry.
pub fn SourceEntry::new(
  url? : String,
  content? : String,
  ignored? : Bool = false,
) -> SourceEntry {
  { url, content, ignored }
}

///|
/// A regular ECMA-426 source map document.
pub(all) struct RegularSourceMap {
  version : Int
  file : String?
  source_root : String?
  sources : Array[String?]
  sources_content : Array[String?]?
  names : Array[String]
  mappings : String
  ignore_list : Array[Int]
} derive(Eq, Debug)

///|
/// Construct an empty version-3 regular map.
pub fn RegularSourceMap::new(
  file? : String,
  source_root? : String,
  sources? : Array[String?] = [],
  sources_content? : Array[String?],
  names? : Array[String] = [],
  mappings? : String = "",
  ignore_list? : Array[Int] = [],
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
pub(all) struct IndexSection {
  offset : Position
  map : SourceMapDocument
} derive(Eq, Debug)

///|
/// Construct an index section.
pub fn IndexSection::new(
  offset~ : Position,
  map~ : SourceMapDocument,
) -> IndexSection {
  { offset, map }
}

///|
/// An ECMA-426 index source map.
pub(all) struct IndexSourceMap {
  version : Int
  file : String?
  sections : Array[IndexSection]
} derive(Eq, Debug)

///|
/// Construct an empty version-3 index map.
pub fn IndexSourceMap::new(
  file? : String,
  sections? : Array[IndexSection] = [],
) -> IndexSourceMap {
  { version: 3, file, sections }
}

///|
/// The raw JSON document shape accepted by MoonSourceMap.
pub(all) enum SourceMapDocument {
  Regular(RegularSourceMap)
  Indexed(IndexSourceMap)
} derive(Eq, Debug)

///|
/// Return the document version.
pub fn SourceMapDocument::version(self : SourceMapDocument) -> Int {
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
pub(all) struct DecodedSourceMap {
  file : String?
  sources : Array[SourceEntry]
  mappings : Array[Mapping]
} derive(Eq, Debug)

///|
/// Construct a decoded map.
pub fn DecodedSourceMap::new(
  file? : String,
  sources? : Array[SourceEntry] = [],
  mappings? : Array[Mapping] = [],
) -> DecodedSourceMap {
  { file, sources, mappings }
}

///|
/// Bias used when a position has no exact mapping.
pub(all) enum LookupBias {
  GreatestLowerBound
  LeastUpperBound
} derive(Eq, Debug)

///|
/// Severity for validation diagnostics.
pub(all) enum DiagnosticSeverity {
  Error
  Warning
} derive(Eq, Debug)

///|
/// A stable, machine-readable validation diagnostic.
pub(all) struct Diagnostic {
  severity : DiagnosticSeverity
  code : String
  message : String
  path : String
  mapping_line : Int?
  segment : Int?
  offset : Int?
} derive(Eq, Debug)

///|
/// Construct an error diagnostic.
pub fn Diagnostic::error(
  code~ : String,
  message~ : String,
  path? : String = "$",
  mapping_line? : Int,
  segment? : Int,
  offset? : Int,
) -> Diagnostic {
  { severity: Error, code, message, path, mapping_line, segment, offset }
}

///|
/// Construct a warning diagnostic.
pub fn Diagnostic::warning(
  code~ : String,
  message~ : String,
  path? : String = "$",
  mapping_line? : Int,
  segment? : Int,
  offset? : Int,
) -> Diagnostic {
  { severity: Warning, code, message, path, mapping_line, segment, offset }
}

///|
/// Whether the diagnostic blocks conformance.
pub fn Diagnostic::is_error(self : Diagnostic) -> Bool {
  self.severity == Error
}
