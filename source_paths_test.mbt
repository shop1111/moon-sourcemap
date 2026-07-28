///|
test "source resolver classifies and resolves URI forms" {
  assert_true(classify_source_path(None) == Anonymous)
  assert_true(classify_source_path(Some("data:text/plain,x")) == DataUri)
  assert_true(classify_source_path(Some("https://a/b.ts")) == AbsoluteUri)
  assert_true(classify_source_path(Some("C:\\src\\a.ts")) == WindowsAbsolute)
  let options = SourceResolverOptions::new(
    map_url="https://cdn.example/dist/app.js.map?x=1",
    source_root="../src",
  )
  assert_true(
    resolve_source_url(Some("./main.ts#L1"), options~) ==
    Some("https://cdn.example/src/main.ts#L1"),
  )
}

///|
test "source resolver preserves absolute values and normalizes dots" {
  assert_true(
    resolve_source_url(Some("https://x.test/a/../b.ts?q=1#x")) ==
    Some("https://x.test/b.ts?q=1#x"),
  )
  assert_true(
    resolve_source_url(Some("C:\\work\\src\\..\\main.ts")) ==
    Some("C:/work/main.ts"),
  )
  assert_true(resolve_source_url(Some("/a/./b/../c.ts")) == Some("/a/c.ts"))
}

///|
test "source text index handles CRLF and empty final line" {
  let index = SourceTextIndex::new("first\r\nsecond\n")
  assert_eq(index.line_count(), 3)
  assert_true(index.line(0).map(line => line.text) == Some("first"))
  assert_true(index.line(1).map(line => line.text) == Some("second"))
  assert_true(index.line(2).map(line => line.text) == Some(""))
  assert_true(index.contains(line=1, column=6))
  assert_false(index.contains(line=1, column=7))
}

///|
test "source context renders focus and bounds" {
  let index = SourceTextIndex::new("zero\none\ntwo\nthree")
  let context = index.context(source="src.ts", line=2, column=1, radius=1)
  guard context is Some(context) else { fail("expected context") }
  assert_eq(context.start_line, 1)
  assert_eq(context.end_line, 3)
  assert_true(context.render().contains("> 2 | two"))
  assert_true(context.render().contains("^"))
  assert_true(context.to_json() is Object(_))
}
