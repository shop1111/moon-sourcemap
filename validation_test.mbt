///|
test "valid regular map has no diagnostics" {
  let document = @moon_sourcemap.parse_document(
    "{\"version\":3,\"sources\":[\"a.mbt\"],\"names\":[],\"mappings\":\"AAAA\"}",
  )
  let diagnostics = @moon_sourcemap.validate(document)
  assert_true(diagnostics.is_empty())
  assert_false(@moon_sourcemap.diagnostics_have_errors(diagnostics))
}

///|
test "validator accumulates independent field problems" {
  let document = @moon_sourcemap.parse_document(
    "{\"version\":2,\"sources\":[\"a.mbt\"],\"sourcesContent\":[\"a\",\"extra\"],\"names\":[],\"mappings\":\"\",\"ignoreList\":[2,2]}",
  )
  let diagnostics = @moon_sourcemap.validate(document)
  assert_true(diagnostics.length() >= 4)
  assert_true(@moon_sourcemap.diagnostics_have_errors(diagnostics))
  assert_true(diagnostics.any(item => item.code == "version_not_three"))
  assert_true(diagnostics.any(item => item.code == "sources_content_too_long"))
  assert_true(diagnostics.any(item => item.code == "ignore_index_out_of_range"))
  assert_true(diagnostics.any(item => item.code == "duplicate_ignore_index"))
}

///|
test "validator turns mapping failures into diagnostics" {
  let diagnostics = @moon_sourcemap.validate_json(
    "{\"version\":3,\"sources\":[\"a.mbt\"],\"names\":[],\"mappings\":\"AA\"}",
  )
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].code, "invalid_mappings")
  assert_true(diagnostics[0].offset is Some(_))
}

///|
test "validator detects overlapping index sections" {
  let child = @moon_sourcemap.SourceMapDocument::Regular(
    @moon_sourcemap.RegularSourceMap::new(
      sources=[Some("a.mbt")],
      mappings="AAAA;AACA",
    ),
  )
  let document = @moon_sourcemap.SourceMapDocument::Indexed(
    @moon_sourcemap.IndexSourceMap::new(sections=[
      @moon_sourcemap.IndexSection::new(
        offset=@moon_sourcemap.Position::new(line=0, column=0),
        map=child,
      ),
      @moon_sourcemap.IndexSection::new(
        offset=@moon_sourcemap.Position::new(line=1, column=0),
        map=child,
      ),
    ]),
  )
  let diagnostics = @moon_sourcemap.validate(document)
  assert_true(diagnostics.any(item => item.code == "sections_overlap"))
}

///|
test "diagnostic rendering is stable" {
  let diagnostic = @moon_sourcemap.Diagnostic::error(
    code="bad_segment",
    message="segment is invalid",
    path="$.mappings",
    mapping_line=2,
    segment=3,
    offset=7,
  )
  assert_eq(
    diagnostic.render(),
    "[error] bad_segment $.mappings:line 2:segment 3:offset 7: segment is invalid",
  )
  let json = diagnostic.to_json().stringify()
  assert_true(json.contains("\"severity\":\"error\""))
  assert_true(json.contains("\"offset\":7"))
}
