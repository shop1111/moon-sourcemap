///|
test "parse and encode a regular source map" {
  let input =
    #|{"version":3,"file":"app.js","sourceRoot":"../src","sources":["app.mbt"],"sourcesContent":["fn main {}"],"names":["main"],"mappings":"AAAAA","ignoreList":[0]}
  let document = @moon_sourcemap.parse_document(input)
  guard document is Regular(map) else { fail("expected regular map") }
  assert_eq(map.version, 3)
  assert_true(map.file == Some("app.js"))
  assert_true(map.source_root == Some("../src"))
  assert_true(map.sources == [Some("app.mbt")])
  assert_true(map.names == ["main"])
  assert_true(map.ignore_list == [0])
  let reparsed = @moon_sourcemap.parse_document(
    @moon_sourcemap.encode_document(document),
  )
  assert_true(reparsed == document)
}

///|
test "parse and encode an index source map" {
  let input =
    #|{"version":3,"file":"bundle.js","sections":[{"offset":{"line":0,"column":0},"map":{"version":3,"sources":["a.mbt"],"names":[],"mappings":"AAAA"}}]}
  let document = @moon_sourcemap.parse_document(input)
  guard document is Indexed(map) else { fail("expected index map") }
  assert_eq(map.sections.length(), 1)
  assert_true(
    map.sections[0].offset == @moon_sourcemap.Position::new(line=0, column=0),
  )
  let reparsed = @moon_sourcemap.parse_document(
    @moon_sourcemap.encode_document(document, indent=0),
  )
  assert_true(reparsed == document)
}

///|
test "JSON parser preserves nullable sources" {
  let document = @moon_sourcemap.parse_document(
    "{\"version\":3,\"sources\":[null,\"a.mbt\"],\"sourcesContent\":[null,\"x\"],\"names\":[],\"mappings\":\"\"}",
  )
  guard document is Regular(map) else { fail("expected regular map") }
  assert_true(map.sources == [None, Some("a.mbt")])
  assert_true(map.sources_content == Some([None, Some("x")]))
}

///|
test "JSON parser rejects fractional integer fields" {
  try
    @moon_sourcemap.parse_document(
      "{\"version\":3.5,\"sources\":[],\"names\":[],\"mappings\":\"\"}",
    )
  catch {
    InvalidField(path~, ..) => assert_eq(path, "$.version")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid version")
  }
}

///|
test "JSON parser rejects mixed regular and index fields" {
  try
    @moon_sourcemap.parse_document(
      "{\"version\":3,\"sources\":[],\"names\":[],\"mappings\":\"\",\"sections\":[]}",
    )
  catch {
    InvalidField(path~, ..) => assert_true(path.contains("mappings"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected mixed field rejection")
  }
}

///|
test "JSON parser reports malformed JSON" {
  try @moon_sourcemap.parse_document("{") catch {
    InvalidJson(..) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected malformed JSON")
  }
}
