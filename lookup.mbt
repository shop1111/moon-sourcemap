///|
fn is_uri_like(value : String) -> Bool {
  value.contains("://") ||
  value.has_prefix("data:") ||
  value.has_prefix("file:")
}

///|
fn path_prefix(value : String) -> (String, String) {
  if value.length() >= 2 && value.get_char(1) == Some(':') {
    (value[0:2].to_owned(), value[2:].to_owned())
  } else if value.has_prefix("/") {
    ("/", value[1:].to_owned())
  } else {
    ("", value)
  }
}

///|
fn normalize_path(value : String) -> String {
  let normalized = value.replace_all(old="\\", new="/")
  let (prefix, body) = path_prefix(normalized)
  let parts : Array[String] = []
  for part in body.split("/") {
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      if !parts.is_empty() && parts[parts.length() - 1] != ".." {
        parts.pop() |> ignore
      } else if prefix == "" {
        parts.push(part.to_owned())
      }
    } else {
      parts.push(part.to_owned())
    }
  }
  let joined = parts.join("/")
  if prefix == "/" {
    "/" + joined
  } else if prefix != "" {
    prefix + "/" + joined
  } else {
    joined
  }
}

///|
fn join_source_root(root : String?, source : String?) -> String? {
  match source {
    None => None
    Some(source) =>
      if is_uri_like(source) || source.has_prefix("/") {
        Some(source)
      } else {
        match root {
          None => Some(normalize_path(source))
          Some(root) =>
            if root == "" {
              Some(normalize_path(source))
            } else if is_uri_like(root) {
              let separator = if root.has_suffix("/") { "" } else { "/" }
              Some(root + separator + source)
            } else {
              let separator = if root.has_suffix("/") { "" } else { "/" }
              Some(normalize_path(root + separator + source))
            }
        }
      }
  }
}

///|
fn ignored_source_indices(values : ArrayView[Int]) -> Map[Int, Unit] {
  let ignored : Map[Int, Unit] = {}
  for value in values {
    ignored[value] = ()
  }
  ignored
}

///|
fn source_content_at(contents : Array[String?]?, index : Int) -> String? {
  match contents {
    Some(contents) =>
      if index < contents.length() {
        contents[index]
      } else {
        None
      }
    None => None
  }
}

///|
/// Decode a regular document into a lookup-oriented representation.
///
/// This resolves `sourceRoot`, associates embedded source content and applies
/// both standard and legacy ignore-list metadata parsed from the document.
pub fn decode_regular_source_map(
  map : RegularSourceMap,
) -> DecodedSourceMap raise SourceMapError {
  let diagnostics = validate(Regular(map))
  if diagnostics_have_errors(diagnostics) {
    let first = diagnostics[0]
    raise InvalidDocument(message=first.render())
  }
  let ignored = ignored_source_indices(map.ignore_list)
  let sources : Array[SourceEntry] = []
  for index, source in map.sources {
    sources.push(
      SourceEntry::new(
        url?=join_source_root(map.source_root, source),
        content?=source_content_at(map.sources_content, index),
        ignored=ignored.contains(index),
      ),
    )
  }
  let mappings = decode_mappings(
    map.mappings,
    sources_count=map.sources.length(),
    names=map.names,
  )
  DecodedSourceMap::new(file?=map.file, sources~, mappings~)
}

///|
fn lower_bound(mappings : ArrayView[Mapping], generated : Position) -> Int {
  let mut low = 0
  let mut high = mappings.length()
  while low < high {
    let middle = low + (high - low) / 2
    if mappings[middle].generated.compare(generated) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn upper_bound(mappings : ArrayView[Mapping], generated : Position) -> Int {
  let mut low = 0
  let mut high = mappings.length()
  while low < high {
    let middle = low + (high - low) / 2
    if mappings[middle].generated.compare(generated) <= 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
/// Find a decoded segment for a generated position.
///
/// `GreatestLowerBound` returns the last segment at or before the query.
/// `LeastUpperBound` returns the first segment at or after the query. Bias is
/// applied within a generated line: mappings on another line are not used.
/// When duplicate generated positions exist, GLB selects the last duplicate
/// and LUB selects the first.
pub fn original_position_for(
  map : DecodedSourceMap,
  generated~ : Position,
  bias? : LookupBias = GreatestLowerBound,
) -> Mapping? {
  if !generated.is_valid() || map.mappings.is_empty() {
    return None
  }
  match bias {
    GreatestLowerBound => {
      let index = upper_bound(map.mappings, generated) - 1
      if index < 0 || map.mappings[index].generated.line != generated.line {
        None
      } else {
        Some(map.mappings[index])
      }
    }
    LeastUpperBound => {
      let index = lower_bound(map.mappings, generated)
      if index >= map.mappings.length() ||
        map.mappings[index].generated.line != generated.line {
        None
      } else {
        Some(map.mappings[index])
      }
    }
  }
}

///|
/// Find every generated segment that maps to an original source position.
///
/// When `column` is omitted, all mappings on the requested original line are
/// returned. Results remain in generated order.
pub fn generated_positions_for(
  map : DecodedSourceMap,
  source_index~ : Int,
  line~ : Int,
  column? : Int,
) -> Array[Mapping] {
  let result : Array[Mapping] = []
  if source_index < 0 || line < 0 {
    return result
  }
  for mapping in map.mappings {
    match mapping.original {
      Some(original) =>
        if original.source_index == source_index &&
          original.line == line &&
          (column is None || column == Some(original.column)) {
          result.push(mapping)
        }
      None => ()
    }
  }
  result
}

///|
/// Resolve the source entry referenced by a mapping.
pub fn source_for_mapping(
  map : DecodedSourceMap,
  mapping : Mapping,
) -> SourceEntry? {
  match mapping.original {
    Some(original) =>
      if original.source_index >= 0 &&
        original.source_index < map.sources.length() {
        Some(map.sources[original.source_index])
      } else {
        None
      }
    None => None
  }
}
