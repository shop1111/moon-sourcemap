///|
fn section_offset_position(position : Position, offset : Position) -> Position {
  Position::new(
    line=position.line + offset.line,
    column=if position.line == 0 {
      position.column + offset.column
    } else {
      position.column
    },
  )
}

///|
fn append_decoded_section(
  destination : DecodedSourceMap,
  section : DecodedSourceMap,
  offset : Position,
) -> Unit {
  let source_base = destination.sources.length()
  for source in section.sources {
    destination.sources.push(source)
  }
  for mapping in section.mappings {
    let generated = section_offset_position(mapping.generated, offset)
    let original = match mapping.original {
      Some(original) =>
        Some(
          OriginalPosition::new(
            source_index=original.source_index + source_base,
            line=original.line,
            column=original.column,
          ),
        )
      None => None
    }
    destination.mappings.push({ generated, original, name: mapping.name })
  }
}

///|
fn decode_document_inner(
  document : SourceMapDocument,
  map_url : String?,
) -> DecodedSourceMap raise SourceMapError {
  match document {
    Regular(map) => decode_regular_source_map(map, map_url?)
    Indexed(index) => {
      let diagnostics = validate(Indexed(index))
      if diagnostics_have_errors(diagnostics) {
        raise InvalidDocument(message=diagnostics[0].render())
      }
      let result = DecodedSourceMap::new(file?=index.file)
      for section in index.sections {
        let decoded = decode_document_inner(section.map, map_url)
        append_decoded_section(result, decoded, section.offset)
      }
      result.mappings.sort_by((left, right) => {
        left.generated.compare(right.generated)
      })
      result
    }
  }
}

///|
/// Decode either a regular or index source map for querying.
///
/// Index maps are recursively expanded. Source entries are intentionally kept
/// section-local, even when URLs repeat, so that distinct embedded contents and
/// ignore-list flags cannot be conflated.
pub fn decode_document(
  document : SourceMapDocument,
  map_url? : String,
) -> DecodedSourceMap raise SourceMapError {
  decode_document_inner(document, map_url)
}

///|
fn unique_names(mappings : ArrayView[Mapping]) -> Array[String] {
  let result : Array[String] = []
  let seen : Map[String, Unit] = {}
  for mapping in mappings {
    match mapping.name {
      Some(name) =>
        if !seen.contains(name) {
          seen[name] = ()
          result.push(name)
        }
      None => ()
    }
  }
  result
}

///|
fn decoded_sources(decoded : DecodedSourceMap) -> Array[String?] {
  decoded.sources.map(source => source.url)
}

///|
fn decoded_contents(decoded : DecodedSourceMap) -> Array[String?]? {
  let contents = decoded.sources.map(source => source.content)
  let mut has_content = false
  for content in contents {
    if content is Some(_) {
      has_content = true
      break
    }
  }
  if has_content {
    Some(contents)
  } else {
    None
  }
}

///|
fn decoded_ignore_list(decoded : DecodedSourceMap) -> Array[Int] {
  let result : Array[Int] = []
  for index, source in decoded.sources {
    if source.ignored {
      result.push(index)
    }
  }
  result
}

///|
/// Encode a decoded source map as a normalized regular document.
pub fn encode_decoded(
  decoded : DecodedSourceMap,
) -> RegularSourceMap raise SourceMapError {
  let names = unique_names(decoded.mappings)
  RegularSourceMap::new(
    file?=decoded.file,
    sources=decoded_sources(decoded),
    sources_content?=decoded_contents(decoded),
    names~,
    mappings=encode_mappings(decoded.mappings, names~),
    ignore_list=decoded_ignore_list(decoded),
  )
}

///|
/// Flatten a regular or index source map into a normalized regular document.
pub fn flatten(
  document : SourceMapDocument,
) -> RegularSourceMap raise SourceMapError {
  encode_decoded(decode_document(document))
}
