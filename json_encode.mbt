///|
fn optional_json_string(value : String?) -> Json {
  match value {
    Some(text) => Json::string(text)
    None => Json::null()
  }
}

///|
fn nullable_string_array(values : ArrayView[String?]) -> Json {
  Json::array(values.map(optional_json_string))
}

///|
fn string_json_array(values : ArrayView[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
fn int_json_array(values : ArrayView[Int]) -> Json {
  Json::array(values.map(value => Json::number(value.to_double())))
}

///|
fn regular_to_json(map : RegularSourceMap) -> Json {
  let fields : Map[String, Json] = {
    "version": Json::number(map.version.to_double()),
    "sources": nullable_string_array(map.sources),
    "names": string_json_array(map.names),
    "mappings": Json::string(map.mappings),
  }
  match map.file {
    Some(file) => fields["file"] = Json::string(file)
    None => ()
  }
  match map.source_root {
    Some(root) => fields["sourceRoot"] = Json::string(root)
    None => ()
  }
  match map.sources_content {
    Some(content) => fields["sourcesContent"] = nullable_string_array(content)
    None => ()
  }
  if !map.ignore_list.is_empty() {
    fields["ignoreList"] = int_json_array(map.ignore_list)
  }
  Json::object(fields)
}

///|
fn position_to_json(position : Position) -> Json {
  Json::object({
    "line": Json::number(position.line.to_double()),
    "column": Json::number(position.column.to_double()),
  })
}

///|
fn index_to_json(map : IndexSourceMap) -> Json {
  let fields : Map[String, Json] = {
    "version": Json::number(map.version.to_double()),
    "sections": Json::array(
      map.sections.map(section => {
        Json::object({
          "offset": position_to_json(section.offset),
          "map": document_to_json(section.map),
        })
      }),
    ),
  }
  match map.file {
    Some(file) => fields["file"] = Json::string(file)
    None => ()
  }
  Json::object(fields)
}

///|
/// Convert a source map document to its JSON value.
pub fn document_to_json(document : SourceMapDocument) -> Json {
  match document {
    Regular(map) => regular_to_json(map)
    Indexed(map) => index_to_json(map)
  }
}

///|
/// Serialize a source map document.
pub fn encode_document(
  document : SourceMapDocument,
  indent? : Int = 2,
) -> String {
  document_to_json(document).stringify(indent~)
}
