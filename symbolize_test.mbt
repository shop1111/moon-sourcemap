///|
test "stack frame parser preserves Windows drive and function" {
  let plain = parse_stack_frame("C:\\dist\\app.js:12:7")
  assert_eq(plain.file, "C:\\dist\\app.js")
  assert_eq(plain.line, 12)
  assert_eq(plain.column, 7)
  let wrapped = parse_stack_frame("  at render (dist/app.js:4:9)  ")
  assert_eq(wrapped.file, "dist/app.js")
  assert_true(wrapped.function_name == Some("render"))
}

///|
test "stack frame parser rejects malformed coordinates" {
  try parse_stack_frame("app.js:x:2") catch {
    InvalidField(path~, message=_) => assert_eq(path, "$frame.line")
    _ => fail("expected invalid field")
  } noraise {
    _ => fail("expected malformed frame to fail")
  }
}

///|
test "symbolizer resolves source position and name" {
  let map = DecodedSourceMap::new(
    sources=[SourceEntry::new(url="src/main.ts", ignored=true)],
    mappings=[
      Mapping::mapped(
        generated=Position::new(line=0, column=3),
        original=OriginalPosition::new(source_index=0, line=8, column=2),
        name="main",
      ),
    ],
  )
  let frame = parse_stack_frame("dist/app.js:0:7")
  let result = symbolize_frame(map, frame)
  assert_true(result.matched)
  assert_true(result.source == Some("src/main.ts"))
  assert_true(result.line == Some(8))
  assert_true(result.name == Some("main"))
  assert_true(result.ignored)
  assert_eq(result.render(), "dist/app.js:0:7 -> src/main.ts:8:2 main")
}

///|
test "symbolizer reports generated-only and absent mappings" {
  let map = DecodedSourceMap::new(mappings=[
    Mapping::generated_only(generated=Position::new(line=0, column=0)),
  ])
  let frames = symbolize(map, "app.js:0:0\napp.js:1:0\n")
  assert_eq(frames.length(), 2)
  assert_false(frames[0].matched)
  assert_false(frames[1].matched)
  assert_true(frames[0].to_json() is Object(_))
}
