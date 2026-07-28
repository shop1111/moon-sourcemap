///|
/// One named source map and its generated-file aliases.
pub(all) struct RegisteredSourceMap {
  name : String
  generated_file : String
  aliases : Array[String]
  map : DecodedSourceMap
}

///|
/// Reason a registry symbolization did not produce an original location.
pub(all) enum RegistryMissReason {
  MapNotFound
  MappingNotFound
  GeneratedOnly
} derive(Eq, Debug)

///|
/// Result of symbolizing one frame through a source-map registry.
pub(all) struct RegistrySymbolizedFrame {
  frame : StackFrame
  map_name : String?
  result : SymbolizedFrame?
  context : SourceContext?
  miss_reason : RegistryMissReason?
} derive(Eq, Debug)

///|
/// Aggregate outcome for newline-separated multi-file stack frames.
pub(all) struct RegistrySymbolizationReport {
  frames : Array[RegistrySymbolizedFrame]
  matched : Int
  map_missing : Int
  mapping_missing : Int
  generated_only : Int
} derive(Eq, Debug)

///|
/// Registry for symbolizing frames from multiple generated artifacts.
pub(all) struct SourceMapRegistry {
  entries : Array[RegisteredSourceMap]
}

///|
/// Construct an empty registry.
pub fn SourceMapRegistry::new() -> SourceMapRegistry {
  { entries: [] }
}

///|
fn registry_keys(entry : RegisteredSourceMap) -> Array[String] {
  let keys : Array[String] = [entry.generated_file]
  for alternative in entry.aliases {
    keys.push(alternative)
  }
  keys
}

///|
fn registry_key_matches(left : String, right : String) -> Bool {
  left == right ||
  normalize_generated_file(left) == normalize_generated_file(right)
}

///|
fn registry_entry_owns_key(entry : RegisteredSourceMap, key : String) -> Bool {
  registry_keys(entry).any(existing => registry_key_matches(existing, key))
}

///|
fn validate_registry_key(key : String) -> Unit raise SourceMapError {
  if key.trim().is_empty() {
    raise InvalidDocument(message="source map registry keys must not be empty")
  }
}

///|
/// Register a decoded source map.
///
/// Exact and normalized keys must remain unique across entries. Re-registering
/// the same logical generated file is rejected instead of silently replacing
/// a map and making symbolization order-dependent.
pub fn SourceMapRegistry::register(
  self : SourceMapRegistry,
  name~ : String,
  generated_file~ : String,
  map~ : DecodedSourceMap,
  aliases? : Array[String] = [],
) -> Unit raise SourceMapError {
  if name.trim().is_empty() {
    raise InvalidDocument(
      message="registered source map name must not be empty",
    )
  }
  validate_registry_key(generated_file)
  for alternative in aliases {
    validate_registry_key(alternative)
  }
  let candidate : RegisteredSourceMap = {
    name,
    generated_file,
    aliases: aliases.copy(),
    map,
  }
  let keys = registry_keys(candidate)
  for key_index, key in keys {
    for previous_index in 0..<key_index {
      if registry_key_matches(key, keys[previous_index]) {
        raise InvalidDocument(
          message="source map aliases must be unique within an entry",
        )
      }
    }
    for entry in self.entries {
      if registry_entry_owns_key(entry, key) {
        raise InvalidDocument(
          message="source map registry key conflicts with \{entry.name}",
        )
      }
    }
  }
  self.entries.push(candidate)
}

///|
/// Number of registered source maps.
pub fn SourceMapRegistry::length(self : SourceMapRegistry) -> Int {
  self.entries.length()
}

///|
/// Return whether the registry is empty.
pub fn SourceMapRegistry::is_empty(self : SourceMapRegistry) -> Bool {
  self.entries.is_empty()
}

///|
/// Resolve an entry by exact key first, then normalized key.
pub fn SourceMapRegistry::find(
  self : SourceMapRegistry,
  generated_file : String,
) -> RegisteredSourceMap? {
  for entry in self.entries {
    if entry.generated_file == generated_file ||
      entry.aliases.any(alternative => alternative == generated_file) {
      return Some(entry)
    }
  }
  let normalized = normalize_generated_file(generated_file)
  for entry in self.entries {
    if normalize_generated_file(entry.generated_file) == normalized ||
      entry.aliases.any(alternative => {
        normalize_generated_file(alternative) == normalized
      }) {
      return Some(entry)
    }
  }
  None
}

///|
fn registry_unmatched_frame(
  frame : StackFrame,
  map_name : String?,
  reason : RegistryMissReason,
) -> RegistrySymbolizedFrame {
  { frame, map_name, result: None, context: None, miss_reason: Some(reason) }
}

///|
/// Symbolize one frame using the matching generated-file map.
pub fn SourceMapRegistry::symbolize_frame(
  self : SourceMapRegistry,
  frame : StackFrame,
  bias? : LookupBias = GreatestLowerBound,
  context_radius? : Int = 0,
) -> RegistrySymbolizedFrame {
  let entry = match self.find(frame.file) {
    Some(entry) => entry
    None => return registry_unmatched_frame(frame, None, MapNotFound)
  }
  let mapping = original_position_for(
    entry.map,
    generated=Position::new(line=frame.line, column=frame.column),
    bias~,
  )
  match mapping {
    None => registry_unmatched_frame(frame, Some(entry.name), MappingNotFound)
    Some(mapping) =>
      match mapping.original {
        None => registry_unmatched_frame(frame, Some(entry.name), GeneratedOnly)
        Some(_) => {
          let symbolized = symbolize_frame(entry.map, frame, bias~)
          {
            frame,
            map_name: Some(entry.name),
            result: Some(symbolized),
            context: if context_radius > 0 {
              source_context_for_mapping(
                entry.map,
                mapping,
                radius=context_radius,
              )
            } else {
              None
            },
            miss_reason: None,
          }
        }
      }
  }
}

///|
/// Parse and symbolize newline-separated frames from multiple generated files.
pub fn SourceMapRegistry::symbolize(
  self : SourceMapRegistry,
  frames : String,
  bias? : LookupBias = GreatestLowerBound,
  context_radius? : Int = 0,
) -> RegistrySymbolizationReport raise SourceMapError {
  let results : Array[RegistrySymbolizedFrame] = []
  let mut matched = 0
  let mut map_missing = 0
  let mut mapping_missing = 0
  let mut generated_only = 0
  for line in frames.split("\n") {
    let text = line.trim()
    if text.is_empty() {
      continue
    }
    let result = self.symbolize_frame(
      parse_stack_frame(text.to_owned()),
      bias~,
      context_radius~,
    )
    match result.miss_reason {
      Some(MapNotFound) => map_missing = map_missing + 1
      Some(MappingNotFound) => mapping_missing = mapping_missing + 1
      Some(GeneratedOnly) => generated_only = generated_only + 1
      None => matched = matched + 1
    }
    results.push(result)
  }
  { frames: results, matched, map_missing, mapping_missing, generated_only }
}

///|
fn registry_reason_label(reason : RegistryMissReason) -> String {
  match reason {
    MapNotFound => "map_not_found"
    MappingNotFound => "mapping_not_found"
    GeneratedOnly => "generated_only"
  }
}

///|
/// Convert a registry frame result to JSON.
pub fn RegistrySymbolizedFrame::to_json(self : RegistrySymbolizedFrame) -> Json {
  Json::object({
    "frame": Json::object({
      "file": Json::string(self.frame.file),
      "line": Json::number(self.frame.line.to_double()),
      "column": Json::number(self.frame.column.to_double()),
    }),
    "map": match self.map_name {
      Some(name) => Json::string(name)
      None => Json::null()
    },
    "result": match self.result {
      Some(result) => result.to_json()
      None => Json::null()
    },
    "context": match self.context {
      Some(context) => context.to_json()
      None => Json::null()
    },
    "miss_reason": match self.miss_reason {
      Some(reason) => Json::string(registry_reason_label(reason))
      None => Json::null()
    },
  })
}

///|
/// Render one registry symbolization result.
pub fn RegistrySymbolizedFrame::render(
  self : RegistrySymbolizedFrame,
) -> String {
  match self.result {
    Some(result) => {
      let output = StringBuilder()
      output.write_string(result.render())
      match self.context {
        Some(context) => {
          output.write_char('\n')
          output.write_string(context.render())
        }
        None => ()
      }
      output.to_string()
    }
    None => {
      let reason = self.miss_reason
        .map(registry_reason_label)
        .unwrap_or("unmapped")
      "\{self.frame.raw} -> <\{reason}>"
    }
  }
}

///|
/// Convert a registry report to stable JSON.
pub fn RegistrySymbolizationReport::to_json(
  self : RegistrySymbolizationReport,
) -> Json {
  Json::object({
    "matched": Json::number(self.matched.to_double()),
    "map_missing": Json::number(self.map_missing.to_double()),
    "mapping_missing": Json::number(self.mapping_missing.to_double()),
    "generated_only": Json::number(self.generated_only.to_double()),
    "frames": Json::array(self.frames.map(frame => frame.to_json())),
  })
}

///|
/// Render all registry frame results.
pub fn RegistrySymbolizationReport::render(
  self : RegistrySymbolizationReport,
) -> String {
  self.frames.map(frame => frame.render()).join("\n")
}

///|
/// Return true when every frame was symbolized.
pub fn RegistrySymbolizationReport::is_complete(
  self : RegistrySymbolizationReport,
) -> Bool {
  self.frames.length() == self.matched
}
