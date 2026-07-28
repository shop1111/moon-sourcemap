///|
/// Stable text label for a diagnostic severity.
pub fn DiagnosticSeverity::label(self : DiagnosticSeverity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
  }
}

///|
/// Convert a diagnostic to JSON.
pub fn Diagnostic::to_json(self : Diagnostic) -> Json {
  let fields : Map[String, Json] = {
    "severity": Json::string(self.severity.label()),
    "code": Json::string(self.code),
    "message": Json::string(self.message),
    "path": Json::string(self.path),
  }
  match self.mapping_line {
    Some(value) => fields["mapping_line"] = Json::number(value.to_double())
    None => ()
  }
  match self.segment {
    Some(value) => fields["segment"] = Json::number(value.to_double())
    None => ()
  }
  match self.offset {
    Some(value) => fields["offset"] = Json::number(value.to_double())
    None => ()
  }
  Json::object(fields)
}

///|
/// Render one diagnostic in a stable single-line text format.
pub fn Diagnostic::render(self : Diagnostic) -> String {
  let location = StringBuilder()
  location.write_string(self.path)
  match self.mapping_line {
    Some(line) => location.write_string(":line \{line}")
    None => ()
  }
  match self.segment {
    Some(segment) => location.write_string(":segment \{segment}")
    None => ()
  }
  match self.offset {
    Some(offset) => location.write_string(":offset \{offset}")
    None => ()
  }
  "[\{self.severity.label()}] \{self.code} \{location}: \{self.message}"
}

///|
/// Convert diagnostics to a JSON array.
pub fn diagnostics_to_json(diagnostics : ArrayView[Diagnostic]) -> Json {
  Json::array(diagnostics.map(Diagnostic::to_json))
}

///|
/// Return true when at least one conformance error is present.
pub fn diagnostics_have_errors(diagnostics : ArrayView[Diagnostic]) -> Bool {
  diagnostics.any(Diagnostic::is_error)
}

///|
fn duplicate_int(values : ArrayView[Int]) -> Int? {
  let seen : Map[Int, Unit] = Map([])
  for value in values {
    if seen.contains(value) {
      return Some(value)
    }
    seen[value] = ()
  }
  None
}

///|
fn validate_regular(
  map : RegularSourceMap,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if map.version != 3 {
    diagnostics.push(
      Diagnostic::error(
        code="version_not_three",
        message="ECMA-426 source maps must use version 3",
        path="\{path}.version",
      ),
    )
  }
  match map.sources_content {
    Some(content) =>
      if content.length() > map.sources.length() {
        diagnostics.push(
          Diagnostic::error(
            code="sources_content_too_long",
            message="sourcesContent cannot contain more entries than sources",
            path="\{path}.sourcesContent",
          ),
        )
      } else if content.length() < map.sources.length() {
        diagnostics.push(
          Diagnostic::warning(
            code="sources_content_short",
            message="missing sourcesContent entries are treated as null",
            path="\{path}.sourcesContent",
          ),
        )
      }
    None => ()
  }
  for index, ignored in map.ignore_list {
    if ignored < 0 || ignored >= map.sources.length() {
      diagnostics.push(
        Diagnostic::error(
          code="ignore_index_out_of_range",
          message="ignoreList entry \{ignored} is outside the sources table",
          path="\{path}.ignoreList[\{index}]",
        ),
      )
    }
  }
  match duplicate_int(map.ignore_list) {
    Some(value) =>
      diagnostics.push(
        Diagnostic::warning(
          code="duplicate_ignore_index",
          message="ignoreList contains duplicate index \{value}",
          path="\{path}.ignoreList",
        ),
      )
    None => ()
  }
  let mappings = decode_mappings(
    map.mappings,
    sources_count=map.sources.length(),
    names=map.names,
  ) catch {
    error => {
      diagnostics.push(error.to_diagnostic())
      []
    }
  }
  for mapping_index, mapping in mappings {
    match mapping.original {
      Some(original) =>
        if map.sources[original.source_index] is None {
          diagnostics.push(
            Diagnostic::warning(
              code="mapping_to_null_source",
              message="mapping refers to a null source entry",
              path="\{path}.mappings",
              mapping_line=mapping.generated.line,
              segment=mapping_index,
            ),
          )
        }
      None => ()
    }
  }
}

///|
fn offset_position(base : Position, relative : Position) -> Position {
  Position::new(
    line=base.line + relative.line,
    column=if relative.line == 0 {
      base.column + relative.column
    } else {
      relative.column
    },
  )
}

///|
fn document_last_position(
  document : SourceMapDocument,
) -> Position? raise SourceMapError {
  match document {
    Regular(map) => {
      let mappings = decode_mappings(
        map.mappings,
        sources_count=map.sources.length(),
        names=map.names,
      )
      if mappings.is_empty() {
        None
      } else {
        Some(mappings[mappings.length() - 1].generated)
      }
    }
    Indexed(map) =>
      if map.sections.is_empty() {
        None
      } else {
        let last = map.sections[map.sections.length() - 1]
        match document_last_position(last.map) {
          Some(position) => Some(offset_position(last.offset, position))
          None => Some(last.offset)
        }
      }
  }
}

///|
fn validate_index(
  map : IndexSourceMap,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if map.version != 3 {
    diagnostics.push(
      Diagnostic::error(
        code="version_not_three",
        message="ECMA-426 source maps must use version 3",
        path="\{path}.version",
      ),
    )
  }
  let mut previous_offset : Position? = None
  let mut previous_end : Position? = None
  for index, section in map.sections {
    let section_path = "\{path}.sections[\{index}]"
    if !section.offset.is_valid() {
      diagnostics.push(
        Diagnostic::error(
          code="invalid_section_offset",
          message="section offsets must be non-negative",
          path="\{section_path}.offset",
        ),
      )
    }
    match previous_offset {
      Some(previous) =>
        if previous.compare(section.offset) >= 0 {
          diagnostics.push(
            Diagnostic::error(
              code="sections_not_sorted",
              message="section offsets must be strictly increasing",
              path="\{section_path}.offset",
            ),
          )
        }
      None => ()
    }
    match previous_end {
      Some(end) =>
        if end.compare(section.offset) >= 0 {
          diagnostics.push(
            Diagnostic::error(
              code="sections_overlap",
              message="section overlaps the preceding section",
              path="\{section_path}.offset",
            ),
          )
        }
      None => ()
    }
    validate_into(section.map, "\{section_path}.map", diagnostics)
    previous_offset = Some(section.offset)
    previous_end = document_last_position(section.map).map(position => {
      offset_position(section.offset, position)
    }) catch {
      _ => None
    }
  }
}

///|
fn validate_into(
  document : SourceMapDocument,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match document {
    Regular(map) => validate_regular(map, path, diagnostics)
    Indexed(map) => validate_index(map, path, diagnostics)
  }
}

///|
/// Validate a parsed source map without aborting after the first problem.
pub fn validate(document : SourceMapDocument) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  validate_into(document, "$", diagnostics)
  diagnostics
}

///|
/// Parse and validate a source map in one operation.
pub fn validate_json(input : StringView) -> Array[Diagnostic] {
  try parse_document(input) catch {
    error => return [error.to_diagnostic()]
  } noraise {
    document => validate(document)
  }
}
