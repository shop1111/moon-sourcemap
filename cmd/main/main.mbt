///|
fn usage() -> String {
  (
    #|MoonSourceMap 0.1.0
    #|Usage:
    #|  moon-sourcemap validate <map> [--format text|json]
    #|  moon-sourcemap inspect <map> [--format text|json]
    #|  moon-sourcemap lookup <map> --line N --column N [--bias glb|lub] [--strict] [--format text|json]
    #|  moon-sourcemap flatten <map> -o <output> [--format text|json]
    #|  moon-sourcemap compose <outer> <inner> -o <output> [--format text|json]
    #|  moon-sourcemap symbolize <map> <frames> [--context N] [--strict] [--format text|json]
    #|
    #|Coordinates are zero-based. Exit codes: 0 success, 1 usage/I/O,
    #|2 invalid source map, 3 strict lookup/symbolization miss.
  )
}

///|
fn option(args : Array[String], name : String) -> String? {
  match args.search_by(value => value == name) {
    Some(index) =>
      if index + 1 < args.length() {
        Some(args[index + 1])
      } else {
        None
      }
    None => None
  }
}

///|
fn has_flag(args : Array[String], name : String) -> Bool {
  args.any(value => value == name)
}

///|
fn format_of(args : Array[String]) -> String {
  option(args, "--format").unwrap_or("text")
}

///|
fn output_of(args : Array[String]) -> String? {
  match option(args, "-o") {
    Some(path) => Some(path)
    None => option(args, "--output")
  }
}

///|
fn parse_coordinate(args : Array[String], name : String) -> Int raise {
  let value = match option(args, name) {
    Some(value) => value
    None => fail("missing required option \{name}")
  }
  let coordinate = @strconv.parse_int(value)
  if coordinate < 0 {
    fail("\{name} must be non-negative")
  }
  coordinate
}

///|
fn read_document(path : String) -> @lib.SourceMapDocument raise {
  @lib.parse_document(@fs.read_file_to_string(path))
}

///|
fn write_output(path : String, content : String) -> Unit raise {
  if path == "-" {
    println(content)
  } else {
    @fs.write_string_to_file(path, content)
  }
}

///|
fn diagnostic_text(diagnostics : ArrayView[@lib.Diagnostic]) -> String {
  if diagnostics.is_empty() {
    "valid"
  } else {
    diagnostics.map(diagnostic => diagnostic.render()).join("\n")
  }
}

///|
fn validate_command(args : Array[String]) -> Int raise {
  if args.length() < 3 {
    fail("validate requires a map path")
  }
  let document = read_document(args[2])
  let diagnostics = @lib.validate(document)
  if format_of(args) == "json" {
    println(@lib.diagnostics_to_json(diagnostics).stringify(indent=2))
  } else {
    println(diagnostic_text(diagnostics))
  }
  if @lib.diagnostics_have_errors(diagnostics) {
    2
  } else {
    0
  }
}

///|
fn inspect_command(args : Array[String]) -> Int raise {
  if args.length() < 3 {
    fail("inspect requires a map path")
  }
  let map = @lib.decode_document(read_document(args[2]), map_url=args[2])
  let report = @lib.analyze_source_map(map)
  let diagnostics = report.diagnostics()
  if format_of(args) == "json" {
    println(
      Json::object({
        "report": report.to_json(),
        "diagnostics": @lib.diagnostics_to_json(diagnostics),
      }).stringify(indent=2),
    )
  } else {
    println(report.render())
    if !diagnostics.is_empty() {
      println(diagnostic_text(diagnostics))
    }
  }
  0
}

///|
fn bias_of(args : Array[String]) -> @lib.LookupBias raise {
  match option(args, "--bias").unwrap_or("glb") {
    "glb" => GreatestLowerBound
    "lub" => LeastUpperBound
    other => fail("unsupported lookup bias: \{other}")
  }
}

///|
fn lookup_json(map : @lib.DecodedSourceMap, mapping : @lib.Mapping?) -> Json {
  match mapping {
    Some(mapping) =>
      match mapping.original {
        Some(original) => {
          let source = if original.source_index < map.sources.length() {
            map.sources[original.source_index].url
          } else {
            None
          }
          Json::object({
            "found": Json::boolean(true),
            "source": match source {
              Some(source) => Json::string(source)
              None => Json::null()
            },
            "line": Json::number(original.line.to_double()),
            "column": Json::number(original.column.to_double()),
            "name": match mapping.name {
              Some(name) => Json::string(name)
              None => Json::null()
            },
          })
        }
        None => Json::object({ "found": Json::boolean(false) })
      }
    None => Json::object({ "found": Json::boolean(false) })
  }
}

///|
fn lookup_text(map : @lib.DecodedSourceMap, mapping : @lib.Mapping?) -> String {
  match mapping {
    Some(mapping) =>
      match mapping.original {
        Some(original) => {
          let source = if original.source_index < map.sources.length() {
            map.sources[original.source_index].url.unwrap_or("<anonymous>")
          } else {
            "<invalid-source>"
          }
          let name = match mapping.name {
            Some(name) => " " + name
            None => ""
          }
          "\{source}:\{original.line}:\{original.column}\{name}"
        }
        None => "<unmapped>"
      }
    None => "<unmapped>"
  }
}

///|
fn lookup_command(args : Array[String]) -> Int raise {
  if args.length() < 3 {
    fail("lookup requires a map path")
  }
  let line = parse_coordinate(args, "--line")
  let column = parse_coordinate(args, "--column")
  let map = @lib.decode_document(read_document(args[2]))
  let mapping = @lib.original_position_for(
    map,
    generated=@lib.Position::new(line~, column~),
    bias=bias_of(args),
  )
  if format_of(args) == "json" {
    println(lookup_json(map, mapping).stringify(indent=2))
  } else {
    println(lookup_text(map, mapping))
  }
  if mapping is None && has_flag(args, "--strict") {
    3
  } else {
    0
  }
}

///|
fn flatten_command(args : Array[String]) -> Int raise {
  if args.length() < 3 {
    fail("flatten requires a map path")
  }
  let output = output_of(args).unwrap_or("-")
  let regular = @lib.flatten(read_document(args[2]))
  write_output(output, @lib.encode_document(Regular(regular)))
  if format_of(args) == "json" {
    println(
      Json::object({ "ok": Json::boolean(true), "output": Json::string(output) }).stringify(),
    )
  }
  0
}

///|
fn compose_command(args : Array[String]) -> Int raise {
  if args.length() < 4 {
    fail("compose requires outer and inner map paths")
  }
  let output = output_of(args).unwrap_or("-")
  let outer = @lib.decode_document(read_document(args[2]))
  let inner = @lib.decode_document(read_document(args[3]))
  let regular = @lib.encode_decoded(@lib.compose(outer, inner))
  write_output(output, @lib.encode_document(Regular(regular)))
  if format_of(args) == "json" {
    println(
      Json::object({ "ok": Json::boolean(true), "output": Json::string(output) }).stringify(),
    )
  }
  0
}

///|
fn symbolize_command(args : Array[String]) -> Int raise {
  if args.length() < 4 {
    fail("symbolize requires a map and frames path")
  }
  let map = @lib.decode_document(read_document(args[2]))
  let frame_text = @fs.read_file_to_string(args[3])
  match option(args, "--context") {
    Some(_) => {
      let radius = parse_coordinate(args, "--context")
      let report = @lib.symbolize_with_context(
        map,
        frame_text,
        context_radius=radius,
      )
      if format_of(args) == "json" {
        println(report.to_json().stringify(indent=2))
      } else {
        println(report.render())
      }
      if has_flag(args, "--strict") && !report.is_complete() {
        3
      } else {
        0
      }
    }
    None => {
      let frames = @lib.symbolize(map, frame_text)
      if format_of(args) == "json" {
        println(@lib.symbolized_frames_to_json(frames).stringify(indent=2))
      } else {
        println(frames.map(frame => frame.render()).join("\n"))
      }
      if has_flag(args, "--strict") && frames.any(frame => !frame.matched) {
        3
      } else {
        0
      }
    }
  }
}

///|
fn dispatch(args : Array[String]) -> Int raise {
  if args.length() < 2 {
    println(usage())
    return 1
  }
  match args[1] {
    "validate" => validate_command(args)
    "inspect" => inspect_command(args)
    "lookup" => lookup_command(args)
    "flatten" => flatten_command(args)
    "compose" => compose_command(args)
    "symbolize" => symbolize_command(args)
    "help" | "--help" | "-h" => {
      println(usage())
      0
    }
    other => {
      println("unknown command: \{other}\n\n\{usage()}")
      1
    }
  }
}

///|
fn main {
  let code = dispatch(@env.args()) catch {
    @lib.InvalidJson(message~) => {
      println("source map error: \{message}")
      2
    }
    @lib.InvalidField(path~, message~) => {
      println("source map error at \{path}: \{message}")
      2
    }
    @lib.InvalidVlq(offset~, message~) => {
      println("source map error at VLQ offset \{offset}: \{message}")
      2
    }
    @lib.InvalidMappings(line~, segment~, offset~, message~) => {
      println(
        "source map error at mapping \{line}:\{segment} offset \{offset}: \{message}",
      )
      2
    }
    @lib.InvalidDocument(message~) => {
      println("source map error: \{message}")
      2
    }
    @lib.Io(message~) => {
      println("I/O error: \{message}")
      1
    }
    error => {
      println("error: \{error}")
      1
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
