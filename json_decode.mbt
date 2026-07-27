///|
fn json_object(
  value : Json,
  path : String,
) -> Map[String, Json] raise SourceMapError {
  match value {
    Object(fields) => fields
    _ => raise InvalidField(path~, message="expected an object")
  }
}

///|
fn json_array(value : Json, path : String) -> Array[Json] raise SourceMapError {
  match value {
    Array(values) => values
    _ => raise InvalidField(path~, message="expected an array")
  }
}

///|
fn json_string(value : Json, path : String) -> String raise SourceMapError {
  match value {
    String(text) => text
    _ => raise InvalidField(path~, message="expected a string")
  }
}

///|
fn json_int(value : Json, path : String) -> Int raise SourceMapError {
  match value {
    Number(number, ..) =>
      if number != number.floor() {
        raise InvalidField(path~, message="expected an integer")
      } else {
        number.to_int()
      }
    _ => raise InvalidField(path~, message="expected an integer")
  }
}

///|
fn required_json(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Json raise SourceMapError {
  match fields.get(key) {
    Some(value) => value
    None =>
      raise InvalidField(
        path="\{path}.\{key}",
        message="missing required field",
      )
  }
}

///|
fn optional_string(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> String? raise SourceMapError {
  match fields.get(key) {
    None | Some(Null) => None
    Some(value) => Some(json_string(value, "\{path}.\{key}"))
  }
}

///|
fn string_array(
  value : Json,
  path : String,
  allow_null : Bool,
) -> Array[String?] raise SourceMapError {
  json_array(value, path).mapi((index, item) => {
    match item {
      Null if allow_null => None
      String(text) => Some(text)
      _ =>
        raise InvalidField(
          path="\{path}[\{index}]",
          message=if allow_null {
            "expected a string or null"
          } else {
            "expected a string"
          },
        )
    }
  })
}

///|
fn optional_nullable_strings(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Array[String?]? raise SourceMapError {
  match fields.get(key) {
    None | Some(Null) => None
    Some(value) => Some(string_array(value, "\{path}.\{key}", true))
  }
}

///|
fn optional_int_array(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Array[Int] raise SourceMapError {
  match fields.get(key) {
    None | Some(Null) => []
    Some(value) =>
      json_array(value, "\{path}.\{key}").mapi((index, item) => {
        json_int(item, "\{path}.\{key}[\{index}]")
      })
  }
}

///|
fn parse_regular(
  fields : Map[String, Json],
  path : String,
) -> RegularSourceMap raise SourceMapError {
  if fields.contains("sections") {
    raise InvalidField(
      path="\{path}.sections",
      message="regular maps cannot contain sections",
    )
  }
  let version = json_int(
    required_json(fields, "version", path),
    "\{path}.version",
  )
  let sources = string_array(
    required_json(fields, "sources", path),
    "\{path}.sources",
    true,
  )
  let names = match fields.get("names") {
    None => []
    Some(value) =>
      string_array(value, "\{path}.names", false).map(item => {
        match item {
          Some(name) => name
          None => ""
        }
      })
  }
  let ignore_list = if fields.contains("ignoreList") {
    optional_int_array(fields, "ignoreList", path)
  } else {
    optional_int_array(fields, "x_google_ignoreList", path)
  }
  {
    version,
    file: optional_string(fields, "file", path),
    source_root: optional_string(fields, "sourceRoot", path),
    sources,
    sources_content: optional_nullable_strings(fields, "sourcesContent", path),
    names,
    mappings: json_string(
      required_json(fields, "mappings", path),
      "\{path}.mappings",
    ),
    ignore_list,
  }
}

///|
fn parse_offset(value : Json, path : String) -> Position raise SourceMapError {
  let fields = json_object(value, path)
  Position::new(
    line=json_int(required_json(fields, "line", path), "\{path}.line"),
    column=json_int(required_json(fields, "column", path), "\{path}.column"),
  )
}

///|
fn parse_index(
  fields : Map[String, Json],
  path : String,
) -> IndexSourceMap raise SourceMapError {
  for
    forbidden in [
      "mappings", "sources", "names", "sourceRoot", "sourcesContent",
    ] {
    if fields.contains(forbidden) {
      raise InvalidField(
        path="\{path}.\{forbidden}",
        message="index maps cannot contain regular-map fields",
      )
    }
  }
  let sections_json = json_array(
    required_json(fields, "sections", path),
    "\{path}.sections",
  )
  let sections = sections_json.mapi((index, section_json) => {
    let section_path = "\{path}.sections[\{index}]"
    let section = json_object(section_json, section_path)
    if section.contains("url") {
      raise InvalidField(
        path="\{section_path}.url",
        message="external section URLs are not supported in v0.1",
      )
    }
    IndexSection::new(
      offset=parse_offset(
        required_json(section, "offset", section_path),
        "\{section_path}.offset",
      ),
      map=parse_document_json(
        required_json(section, "map", section_path),
        "\{section_path}.map",
      ),
    )
  })
  {
    version: json_int(required_json(fields, "version", path), "\{path}.version"),
    file: optional_string(fields, "file", path),
    sections,
  }
}

///|
fn parse_document_json(
  value : Json,
  path : String,
) -> SourceMapDocument raise SourceMapError {
  let fields = json_object(value, path)
  if fields.contains("sections") {
    Indexed(parse_index(fields, path))
  } else {
    Regular(parse_regular(fields, path))
  }
}

///|
/// Parse a regular or index source map JSON document.
pub fn parse_document(
  input : StringView,
) -> SourceMapDocument raise SourceMapError {
  let value = @json.parse(input) catch {
    error => raise InvalidJson(message=error.to_string())
  }
  parse_document_json(value, "$")
}
