///|
/// Policy used when canonicalizing duplicate generated positions.
pub(all) enum DuplicateMappingPolicy {
  KeepFirst
  KeepLast
  KeepAll
} derive(Eq, Debug)

///|
/// Result metadata for map normalization.
pub(all) struct TransformReport {
  mappings_before : Int
  mappings_after : Int
  sources_before : Int
  sources_after : Int
  duplicates_removed : Int
  sources_removed : Int
}

///|
/// A transformed map together with auditable change counts.
pub(all) struct TransformResult {
  map : DecodedSourceMap
  report : TransformReport
}

///|
fn mapping_with_source_index(mapping : Mapping, source_index : Int) -> Mapping {
  match mapping.original {
    Some(original) =>
      Mapping::mapped(
        generated=mapping.generated,
        original=OriginalPosition::new(
          source_index~,
          line=original.line,
          column=original.column,
        ),
        name?=mapping.name,
      )
    None => Mapping::generated_only(generated=mapping.generated)
  }
}

///|
fn deduplicate_mappings(
  mappings : ArrayView[Mapping],
  policy : DuplicateMappingPolicy,
) -> Array[Mapping] {
  if policy == KeepAll {
    return mappings.to_owned()
  }
  let result : Array[Mapping] = []
  let mut index = 0
  while index < mappings.length() {
    let start = index
    let position = mappings[index].generated
    index = index + 1
    while index < mappings.length() && mappings[index].generated == position {
      index = index + 1
    }
    match policy {
      KeepFirst => result.push(mappings[start])
      KeepLast => result.push(mappings[index - 1])
      KeepAll => ()
    }
  }
  result
}

///|
fn used_source_indices(mappings : ArrayView[Mapping]) -> Map[Int, Unit] {
  let result : Map[Int, Unit] = Map([])
  for mapping in mappings {
    match mapping.original {
      Some(original) => result[original.source_index] = ()
      None => ()
    }
  }
  result
}

///|
fn prune_sources(
  sources : ArrayView[SourceEntry],
  mappings : ArrayView[Mapping],
) -> (Array[SourceEntry], Array[Mapping]) {
  let used = used_source_indices(mappings)
  let remap : Map[Int, Int] = Map([])
  let retained : Array[SourceEntry] = []
  for index, source in sources {
    if used.contains(index) {
      remap[index] = retained.length()
      retained.push(source)
    }
  }
  let rewritten : Array[Mapping] = []
  for mapping in mappings {
    match mapping.original {
      Some(original) =>
        match remap.get(original.source_index) {
          Some(index) =>
            rewritten.push(mapping_with_source_index(mapping, index))
          None =>
            rewritten.push(Mapping::generated_only(generated=mapping.generated))
        }
      None => rewritten.push(mapping)
    }
  }
  (retained, rewritten)
}

///|
/// Sort mappings, resolve duplicates and optionally remove unused sources.
pub fn canonicalize(
  map : DecodedSourceMap,
  duplicate_policy? : DuplicateMappingPolicy = KeepLast,
  remove_unused_sources? : Bool = true,
) -> TransformResult {
  let sorted = sort_mappings(map.mappings)
  let unique = deduplicate_mappings(sorted, duplicate_policy)
  let (sources, mappings) = if remove_unused_sources {
    prune_sources(map.sources, unique)
  } else {
    (map.sources.copy(), unique)
  }
  {
    map: DecodedSourceMap::new(file?=map.file, sources~, mappings~),
    report: {
      mappings_before: map.mappings.length(),
      mappings_after: mappings.length(),
      sources_before: map.sources.length(),
      sources_after: sources.length(),
      duplicates_removed: map.mappings.length() - mappings.length(),
      sources_removed: map.sources.length() - sources.length(),
    },
  }
}

///|
fn position_in_half_open_range(
  value : Position,
  start : Position,
  end : Position,
) -> Bool {
  value.compare(start) >= 0 && value.compare(end) < 0
}

///|
/// Keep mappings in a half-open generated range.
pub fn slice_generated(
  map : DecodedSourceMap,
  start~ : Position,
  end~ : Position,
) -> DecodedSourceMap raise SourceMapError {
  if !start.is_valid() || !end.is_valid() || start.compare(end) > 0 {
    raise InvalidDocument(message="invalid generated slice range")
  }
  let mappings = map.mappings.filter(mapping => {
    position_in_half_open_range(mapping.generated, start, end)
  })
  canonicalize(
    DecodedSourceMap::new(file?=map.file, sources=map.sources.copy(), mappings~),
  ).map
}

///|
fn shift_position(
  position : Position,
  line_delta : Int,
  first_line_column_delta : Int,
) -> Position raise SourceMapError {
  let line = position.line + line_delta
  let column = if position.line == 0 {
    position.column + first_line_column_delta
  } else {
    position.column
  }
  let shifted = Position::new(line~, column~)
  if !shifted.is_valid() {
    raise InvalidDocument(
      message="generated shift produced a negative position",
    )
  }
  shifted
}

///|
/// Shift generated positions using the ECMA-426 section-offset rule.
pub fn shift_generated(
  map : DecodedSourceMap,
  line_delta? : Int = 0,
  first_line_column_delta? : Int = 0,
) -> DecodedSourceMap raise SourceMapError {
  let mappings = map.mappings.map(mapping => {
    generated: shift_position(
      mapping.generated,
      line_delta,
      first_line_column_delta,
    ),
    original: mapping.original,
    name: mapping.name,
  })
  DecodedSourceMap::new(file?=map.file, sources=map.sources.copy(), mappings~)
}

///|
fn remap_appended_mapping(mapping : Mapping, source_base : Int) -> Mapping {
  match mapping.original {
    Some(original) =>
      mapping_with_source_index(mapping, original.source_index + source_base)
    None => mapping
  }
}

///|
/// Concatenate decoded maps at explicit generated offsets.
///
/// This is the programmatic counterpart of constructing an index map and then
/// flattening it, useful for bundlers that already have decoded child maps.
pub fn concatenate(
  parts : ArrayView[(Position, DecodedSourceMap)],
  file? : String,
) -> DecodedSourceMap raise SourceMapError {
  let sources : Array[SourceEntry] = []
  let mappings : Array[Mapping] = []
  let mut previous : Position? = None
  for entry in parts {
    let (offset, part) = entry
    if !offset.is_valid() {
      raise InvalidDocument(message="concatenation offset must be non-negative")
    }
    match previous {
      Some(previous) =>
        if previous.compare(offset) > 0 {
          raise InvalidDocument(message="concatenation offsets must be sorted")
        }
      None => ()
    }
    let source_base = sources.length()
    for source in part.sources {
      sources.push(source)
    }
    for mapping in part.mappings {
      let remapped = remap_appended_mapping(mapping, source_base)
      mappings.push({
        generated: section_offset_position(remapped.generated, offset),
        original: remapped.original,
        name: remapped.name,
      })
    }
    previous = Some(offset)
  }
  let result = DecodedSourceMap::new(file?, sources~, mappings~)
  if !mappings_are_sorted(result.mappings) {
    raise InvalidDocument(
      message="concatenated map sections overlap or are not ordered",
    )
  }
  result
}

///|
/// Convert a transform report to JSON.
pub fn TransformReport::to_json(self : TransformReport) -> Json {
  Json::object({
    "mappings_before": Json::number(self.mappings_before.to_double()),
    "mappings_after": Json::number(self.mappings_after.to_double()),
    "sources_before": Json::number(self.sources_before.to_double()),
    "sources_after": Json::number(self.sources_after.to_double()),
    "duplicates_removed": Json::number(self.duplicates_removed.to_double()),
    "sources_removed": Json::number(self.sources_removed.to_double()),
  })
}
