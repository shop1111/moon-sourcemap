///|
/// Precomputed indexes for repeated source-map queries.
pub(all) struct SourceMapConsumer {
  map : DecodedSourceMap
  line_starts : Array[Int]
  reverse : Map[Int, Array[Int]]
}

///|
/// Summary metrics useful for CI reports and producer diagnostics.
pub(all) struct SourceMapStats {
  sources : Int
  mappings : Int
  mapped : Int
  generated_only : Int
  named : Int
  ignored_sources : Int
  generated_lines : Int
  original_lines : Int
}

///|
fn max_generated_line(mappings : ArrayView[Mapping]) -> Int {
  let mut result = -1
  for mapping in mappings {
    if mapping.generated.line > result {
      result = mapping.generated.line
    }
  }
  result
}

///|
fn build_line_starts(mappings : ArrayView[Mapping]) -> Array[Int] {
  let maximum = max_generated_line(mappings)
  if maximum < 0 {
    return [0]
  }
  let starts = Array::make(maximum + 2, mappings.length())
  let mut mapping_index = 0
  for line in 0..<=maximum {
    starts[line] = mapping_index
    while mapping_index < mappings.length() &&
          mappings[mapping_index].generated.line == line {
      mapping_index = mapping_index + 1
    }
  }
  starts[maximum + 1] = mappings.length()
  starts
}

///|
fn build_reverse_index(mappings : ArrayView[Mapping]) -> Map[Int, Array[Int]] {
  let reverse : Map[Int, Array[Int]] = {}
  for index, mapping in mappings {
    match mapping.original {
      Some(original) =>
        match reverse.get(original.source_index) {
          Some(indices) => indices.push(index)
          None => reverse[original.source_index] = [index]
        }
      None => ()
    }
  }
  reverse
}

///|
/// Construct a consumer, sorting a private mapping copy when necessary.
pub fn SourceMapConsumer::new(map : DecodedSourceMap) -> SourceMapConsumer {
  let normalized = if mappings_are_sorted(map.mappings) {
    DecodedSourceMap::new(
      file?=map.file,
      sources=map.sources.copy(),
      mappings=map.mappings.copy(),
    )
  } else {
    DecodedSourceMap::new(
      file?=map.file,
      sources=map.sources.copy(),
      mappings=sort_mappings(map.mappings),
    )
  }
  {
    map: normalized,
    line_starts: build_line_starts(normalized.mappings),
    reverse: build_reverse_index(normalized.mappings),
  }
}

///|
/// Parse and flatten a document directly into a consumer.
pub fn SourceMapConsumer::from_document(
  document : SourceMapDocument,
) -> SourceMapConsumer raise SourceMapError {
  SourceMapConsumer::new(decode_document(document))
}

///|
fn consumer_line_range(consumer : SourceMapConsumer, line : Int) -> (Int, Int)? {
  if line < 0 || line + 1 >= consumer.line_starts.length() {
    None
  } else {
    Some((consumer.line_starts[line], consumer.line_starts[line + 1]))
  }
}

///|
fn lower_bound_range(
  mappings : ArrayView[Mapping],
  start : Int,
  end : Int,
  column : Int,
) -> Int {
  let mut low = start
  let mut high = end
  while low < high {
    let middle = low + (high - low) / 2
    if mappings[middle].generated.column < column {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn upper_bound_range(
  mappings : ArrayView[Mapping],
  start : Int,
  end : Int,
  column : Int,
) -> Int {
  let mut low = start
  let mut high = end
  while low < high {
    let middle = low + (high - low) / 2
    if mappings[middle].generated.column <= column {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
/// Query a generated position using the precomputed line index.
pub fn SourceMapConsumer::original_position_for(
  self : SourceMapConsumer,
  generated~ : Position,
  bias? : LookupBias = GreatestLowerBound,
) -> Mapping? {
  if !generated.is_valid() {
    return None
  }
  let (start, end) = match consumer_line_range(self, generated.line) {
    Some(range) => range
    None => return None
  }
  if start == end {
    return None
  }
  match bias {
    GreatestLowerBound => {
      let index = upper_bound_range(
          self.map.mappings,
          start,
          end,
          generated.column,
        ) -
        1
      if index < start {
        None
      } else {
        Some(self.map.mappings[index])
      }
    }
    LeastUpperBound => {
      let index = lower_bound_range(
        self.map.mappings,
        start,
        end,
        generated.column,
      )
      if index >= end {
        None
      } else {
        Some(self.map.mappings[index])
      }
    }
  }
}

///|
/// Query multiple positions without rebuilding indexes.
pub fn SourceMapConsumer::original_positions_for(
  self : SourceMapConsumer,
  positions : ArrayView[Position],
  bias? : LookupBias = GreatestLowerBound,
) -> Array[Mapping?] {
  positions.map(position => {
    self.original_position_for(generated=position, bias~)
  })
}

///|
/// Return mappings for one source, optionally filtered by original line.
pub fn SourceMapConsumer::generated_positions_for(
  self : SourceMapConsumer,
  source_index~ : Int,
  line? : Int,
  column? : Int,
) -> Array[Mapping] {
  let result : Array[Mapping] = []
  match self.reverse.get(source_index) {
    Some(indices) =>
      for index in indices {
        let mapping = self.map.mappings[index]
        match mapping.original {
          Some(original) =>
            if (line is None || line == Some(original.line)) &&
              (column is None || column == Some(original.column)) {
              result.push(mapping)
            }
          None => ()
        }
      }
    None => ()
  }
  result
}

///|
/// Find the first source index with an exact URL.
pub fn SourceMapConsumer::source_index_for_url(
  self : SourceMapConsumer,
  url : String,
) -> Int? {
  for index, source in self.map.sources {
    if source.url == Some(url) {
      return Some(index)
    }
  }
  None
}

///|
/// Return every source index sharing a URL.
pub fn SourceMapConsumer::source_indices_for_url(
  self : SourceMapConsumer,
  url : String,
) -> Array[Int] {
  let result : Array[Int] = []
  for index, source in self.map.sources {
    if source.url == Some(url) {
      result.push(index)
    }
  }
  result
}

///|
/// Return aggregate map statistics.
pub fn SourceMapConsumer::stats(self : SourceMapConsumer) -> SourceMapStats {
  let mut mapped = 0
  let mut generated_only = 0
  let mut named = 0
  let mut ignored_sources = 0
  let mut original_lines = 0
  for source in self.map.sources {
    if source.ignored {
      ignored_sources = ignored_sources + 1
    }
  }
  for mapping in self.map.mappings {
    match mapping.original {
      Some(original) => {
        mapped = mapped + 1
        if original.line + 1 > original_lines {
          original_lines = original.line + 1
        }
      }
      None => generated_only = generated_only + 1
    }
    if mapping.name is Some(_) {
      named = named + 1
    }
  }
  {
    sources: self.map.sources.length(),
    mappings: self.map.mappings.length(),
    mapped,
    generated_only,
    named,
    ignored_sources,
    generated_lines: max_generated_line(self.map.mappings) + 1,
    original_lines,
  }
}

///|
/// Convert statistics to stable JSON.
pub fn SourceMapStats::to_json(self : SourceMapStats) -> Json {
  Json::object({
    "sources": Json::number(self.sources.to_double()),
    "mappings": Json::number(self.mappings.to_double()),
    "mapped": Json::number(self.mapped.to_double()),
    "generated_only": Json::number(self.generated_only.to_double()),
    "named": Json::number(self.named.to_double()),
    "ignored_sources": Json::number(self.ignored_sources.to_double()),
    "generated_lines": Json::number(self.generated_lines.to_double()),
    "original_lines": Json::number(self.original_lines.to_double()),
  })
}
