///|
/// Incremental builder for normalized regular source maps.
///
/// Sources and names are interned in first-seen order. Mappings must be added
/// in generated order, which catches a common source-map producer bug at the
/// point where it is introduced.
pub(all) struct SourceMapBuilder {
  file : String?
  sources : Array[SourceEntry]
  names : Array[String]
  mappings : Array[Mapping]
}

///|
/// Create an empty source map builder.
pub fn SourceMapBuilder::new(file? : String) -> SourceMapBuilder {
  { file, sources: [], names: [], mappings: [] }
}

///|
fn source_entry_index(
  sources : ArrayView[SourceEntry],
  target : SourceEntry,
) -> Int? {
  for index, source in sources {
    if source == target {
      return Some(index)
    }
  }
  None
}

///|
fn string_index(values : ArrayView[String], target : String) -> Int? {
  for index, value in values {
    if value == target {
      return Some(index)
    }
  }
  None
}

///|
/// Intern a source entry and return its stable index.
pub fn SourceMapBuilder::add_source(
  self : SourceMapBuilder,
  url? : String,
  content? : String,
  ignored? : Bool = false,
) -> Int {
  let entry = SourceEntry::new(url?, content?, ignored~)
  match source_entry_index(self.sources, entry) {
    Some(index) => index
    None => {
      let index = self.sources.length()
      self.sources.push(entry)
      index
    }
  }
}

///|
/// Intern a symbol name and return its stable index.
pub fn SourceMapBuilder::add_name(
  self : SourceMapBuilder,
  name : String,
) -> Int {
  match string_index(self.names, name) {
    Some(index) => index
    None => {
      let index = self.names.length()
      self.names.push(name)
      index
    }
  }
}

///|
fn check_builder_order(
  mappings : ArrayView[Mapping],
  generated : Position,
) -> Unit raise SourceMapError {
  if !generated.is_valid() {
    raise InvalidDocument(message="generated position must be non-negative")
  }
  if !mappings.is_empty() {
    let previous = mappings[mappings.length() - 1].generated
    if previous.compare(generated) > 0 {
      raise InvalidDocument(
        message="builder mappings must be added in generated order",
      )
    }
  }
}

///|
/// Add a generated-only segment.
pub fn SourceMapBuilder::add_generated(
  self : SourceMapBuilder,
  generated~ : Position,
) -> Unit raise SourceMapError {
  check_builder_order(self.mappings, generated)
  self.mappings.push(Mapping::generated_only(generated~))
}

///|
/// Add a segment mapped to an interned source.
pub fn SourceMapBuilder::add_mapping(
  self : SourceMapBuilder,
  generated~ : Position,
  source_index~ : Int,
  original_line~ : Int,
  original_column~ : Int,
  name? : String,
) -> Unit raise SourceMapError {
  check_builder_order(self.mappings, generated)
  if source_index < 0 || source_index >= self.sources.length() {
    raise InvalidDocument(message="builder source index is outside its table")
  }
  let original = OriginalPosition::new(
    source_index~,
    line=original_line,
    column=original_column,
  )
  if !original.is_valid() {
    raise InvalidDocument(message="original position must be non-negative")
  }
  match name {
    Some(name) => self.add_name(name) |> ignore
    None => ()
  }
  self.mappings.push(Mapping::mapped(generated~, original~, name?))
}

///|
/// Return an independent decoded snapshot.
pub fn SourceMapBuilder::build_decoded(
  self : SourceMapBuilder,
) -> DecodedSourceMap {
  DecodedSourceMap::new(
    file?=self.file,
    sources=self.sources.copy(),
    mappings=self.mappings.copy(),
  )
}

///|
/// Build a normalized version-3 regular source map.
pub fn SourceMapBuilder::build(
  self : SourceMapBuilder,
) -> RegularSourceMap raise SourceMapError {
  encode_decoded(self.build_decoded())
}

///|
/// Number of interned sources.
pub fn SourceMapBuilder::source_count(self : SourceMapBuilder) -> Int {
  self.sources.length()
}

///|
/// Number of emitted mappings.
pub fn SourceMapBuilder::mapping_count(self : SourceMapBuilder) -> Int {
  self.mappings.length()
}

///|
/// Remove every mapping while retaining source and name tables.
pub fn SourceMapBuilder::clear_mappings(self : SourceMapBuilder) -> Unit {
  self.mappings.clear()
}
