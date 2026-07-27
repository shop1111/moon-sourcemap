///|
/// Checked errors raised while parsing or transforming source maps.
pub(all) suberror SourceMapError {
  InvalidJson(message~ : String)
  InvalidField(path~ : String, message~ : String)
  InvalidVlq(offset~ : Int, message~ : String)
  InvalidMappings(line~ : Int, segment~ : Int, offset~ : Int, message~ : String)
  InvalidDocument(message~ : String)
  Io(message~ : String)
} derive(Eq, Debug)

///|
/// Return a stable error category.
pub fn SourceMapError::code(self : SourceMapError) -> String {
  match self {
    InvalidJson(..) => "invalid_json"
    InvalidField(..) => "invalid_field"
    InvalidVlq(..) => "invalid_vlq"
    InvalidMappings(..) => "invalid_mappings"
    InvalidDocument(..) => "invalid_document"
    Io(..) => "io_error"
  }
}

///|
/// Return the most specific available document path.
pub fn SourceMapError::path(self : SourceMapError) -> String {
  match self {
    InvalidField(path~, ..) => path
    _ => "$"
  }
}

///|
/// Return a human-readable message.
pub fn SourceMapError::message(self : SourceMapError) -> String {
  match self {
    InvalidJson(message~) => message
    InvalidField(message~, ..) => message
    InvalidVlq(message~, ..) => message
    InvalidMappings(message~, ..) => message
    InvalidDocument(message~) => message
    Io(message~) => message
  }
}

///|
/// Convert a checked error into a validation diagnostic.
pub fn SourceMapError::to_diagnostic(self : SourceMapError) -> Diagnostic {
  match self {
    InvalidJson(message~) =>
      Diagnostic::error(code="invalid_json", message~, path="$")
    InvalidField(path~, message~) =>
      Diagnostic::error(code="invalid_field", message~, path~)
    InvalidVlq(offset~, message~) =>
      Diagnostic::error(
        code="invalid_vlq",
        message~,
        path="$.mappings",
        offset~,
      )
    InvalidMappings(line~, segment~, offset~, message~) =>
      Diagnostic::error(
        code="invalid_mappings",
        message~,
        path="$.mappings",
        mapping_line=line,
        segment~,
        offset~,
      )
    InvalidDocument(message~) =>
      Diagnostic::error(code="invalid_document", message~, path="$")
    Io(message~) => Diagnostic::error(code="io_error", message~, path="$")
  }
}
