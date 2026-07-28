///|
/// Classification used while resolving source entries.
pub(all) enum SourcePathKind {
  Anonymous
  DataUri
  AbsoluteUri
  ProtocolRelative
  WindowsAbsolute
  PosixAbsolute
  Relative
} derive(Eq, Debug)

///|
/// Options for resolving `sourceRoot` and source entries.
pub(all) struct SourceResolverOptions {
  map_url : String?
  source_root : String?
  normalize_windows : Bool
}

///|
/// Construct source resolver options.
pub fn SourceResolverOptions::new(
  map_url? : String,
  source_root? : String,
  normalize_windows? : Bool = true,
) -> SourceResolverOptions {
  { map_url, source_root, normalize_windows }
}

///|
fn source_has_scheme(value : String) -> Bool {
  match value.split_once(":") {
    None => false
    Some((scheme, _)) => {
      if scheme.is_empty() {
        return false
      }
      for index, ch in scheme {
        let valid = (ch >= 'a' && ch <= 'z') ||
          (ch >= 'A' && ch <= 'Z') ||
          (
            index > 0 &&
            ((ch >= '0' && ch <= '9') || ch == '+' || ch == '-' || ch == '.')
          )
        if !valid {
          return false
        }
      }
      true
    }
  }
}

///|
fn source_windows_absolute(value : String) -> Bool {
  value.length() >= 3 &&
  value.get_char(1) == Some(':') &&
  (value.get_char(2) == Some('/') || value.get_char(2) == Some('\\'))
}

///|
/// Classify a raw source entry before resolution.
pub fn classify_source_path(source : String?) -> SourcePathKind {
  match source {
    None => Anonymous
    Some(value) =>
      if value.has_prefix("data:") {
        DataUri
      } else if value.has_prefix("//") {
        ProtocolRelative
      } else if source_windows_absolute(value) {
        WindowsAbsolute
      } else if source_has_scheme(value) {
        AbsoluteUri
      } else if value.has_prefix("/") {
        PosixAbsolute
      } else {
        Relative
      }
  }
}

///|
fn split_source_suffix(value : String) -> (String, String) {
  let mut boundary = value.length()
  for index, ch in value {
    if (ch == '?' || ch == '#') && index < boundary {
      boundary = index
    }
  }
  (value[:boundary].to_owned(), value[boundary:].to_owned())
}

///|
fn source_prefix(value : String) -> (String, String, Bool) {
  if value.has_prefix("//") {
    match value[2:].split_once("/") {
      Some((authority, path)) =>
        ("//" + authority.to_owned(), "/" + path.to_owned(), true)
      None => (value, "", true)
    }
  } else if source_windows_absolute(value) {
    (value[:2].to_owned(), value[2:].to_owned(), true)
  } else if value.has_prefix("/") {
    ("/", value[1:].to_owned(), true)
  } else {
    match value.split_once("://") {
      Some((scheme, rest)) =>
        match rest.split_once("/") {
          Some((authority, path)) =>
            (
              scheme.to_owned() + "://" + authority.to_owned(),
              "/" + path.to_owned(),
              true,
            )
          None => (value, "", true)
        }
      None => ("", value, false)
    }
  }
}

///|
fn normalize_source_path(value : String, normalize_windows : Bool) -> String {
  let (path, suffix) = split_source_suffix(value)
  let input = if normalize_windows {
    path.replace_all(old="\\", new="/")
  } else {
    path
  }
  let (prefix, body, absolute) = source_prefix(input)
  let segments : Array[String] = []
  for segment in body.split("/") {
    if segment.is_empty() || segment == "." {
      continue
    }
    if segment == ".." {
      if !segments.is_empty() && segments[segments.length() - 1] != ".." {
        segments.pop() |> ignore
      } else if !absolute {
        segments.push("..")
      }
    } else {
      segments.push(segment.to_owned())
    }
  }
  let joined = segments.join("/")
  let normalized = if prefix == "/" {
    "/" + joined
  } else if prefix != "" {
    if joined == "" {
      prefix
    } else {
      prefix + "/" + joined
    }
  } else {
    joined
  }
  normalized + suffix
}

///|
fn source_directory(value : String) -> String {
  let (path, _) = split_source_suffix(value)
  match path.rev_split_once("/") {
    Some((directory, _)) => directory.to_owned()
    None => ""
  }
}

///|
fn source_join(base : String, child : String) -> String {
  if base == "" {
    child
  } else if base.has_suffix("/") {
    base + child
  } else {
    base + "/" + child
  }
}

///|
fn resolve_relative_source(
  source : String,
  base : String?,
  normalize_windows : Bool,
) -> String {
  match base {
    Some(base) =>
      normalize_source_path(source_join(base, source), normalize_windows)
    None => normalize_source_path(source, normalize_windows)
  }
}

///|
/// Resolve one source entry using ECMA-426 `sourceRoot` and a map URL.
///
/// Absolute URIs, data URIs, protocol-relative URLs and absolute filesystem
/// paths do not inherit either base. A relative `sourceRoot` is first resolved
/// against the directory containing the map.
pub fn resolve_source_url(
  source : String?,
  options? : SourceResolverOptions = SourceResolverOptions::new(),
) -> String? {
  match source {
    None => None
    Some(source) =>
      match classify_source_path(Some(source)) {
        DataUri
        | AbsoluteUri
        | ProtocolRelative
        | WindowsAbsolute
        | PosixAbsolute =>
          Some(normalize_source_path(source, options.normalize_windows))
        Anonymous => None
        Relative => {
          let map_base = options.map_url.map(source_directory)
          let root_base = match options.source_root {
            None => map_base
            Some(root) =>
              match classify_source_path(Some(root)) {
                Relative =>
                  Some(
                    resolve_relative_source(
                      root,
                      map_base,
                      options.normalize_windows,
                    ),
                  )
                _ =>
                  Some(normalize_source_path(root, options.normalize_windows))
              }
          }
          Some(
            resolve_relative_source(
              source,
              root_base,
              options.normalize_windows,
            ),
          )
        }
      }
  }
}

///|
/// Normalize a generated-file key for registry matching.
pub fn normalize_generated_file(value : String) -> String {
  normalize_source_path(value, true)
}
