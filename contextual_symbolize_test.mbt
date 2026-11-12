///|
test "contextual symbolization includes embedded source lines" {
  let map = @moon_sourcemap.DecodedSourceMap::new(
    sources=[
      @moon_sourcemap.SourceEntry::new(
        url="src/app.ts",
        content="zero\nconst answer = 42\ntwo",
      ),
    ],
    mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=1,
          column=6,
        ),
        name="answer",
      ),
    ],
  )
  let report = @moon_sourcemap.symbolize_with_context(
    map,
    "bundle.js:0:2\nbundle.js:1:0",
    context_radius=1,
  )
  assert_eq(report.matched, 1)
  assert_eq(report.unmatched, 1)
  assert_eq(report.with_context, 1)
  assert_false(report.is_complete())
  assert_true(report.has_complete_context())
  assert_eq(report.unmatched_frames().length(), 1)
  assert_true(report.render().contains("const answer = 42"))
  assert_true(report.to_json() is Object(_))
}

///|
test "contextual symbolization validates radius" {
  try
    @moon_sourcemap.symbolize_with_context(
      @moon_sourcemap.DecodedSourceMap::new(),
      "",
      context_radius=-1,
    )
  catch {
    InvalidField(path~, ..) => assert_eq(path, "$context")
    _ => fail("expected invalid context")
  } noraise {
    _ => fail("expected negative radius to fail")
  }
}
