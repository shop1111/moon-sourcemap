///|
test "builder interns sources and names" {
  let builder = SourceMapBuilder::new(file="app.js")
  let first = builder.add_source(url="src/app.ts", content="let answer = 42")
  let duplicate = builder.add_source(
    url="src/app.ts",
    content="let answer = 42",
  )
  assert_eq(first, duplicate)
  builder.add_mapping(
    generated=Position::new(line=0, column=0),
    source_index=first,
    original_line=0,
    original_column=0,
    name="answer",
  )
  builder.add_mapping(
    generated=Position::new(line=0, column=8),
    source_index=first,
    original_line=0,
    original_column=4,
    name="answer",
  )
  assert_eq(builder.source_count(), 1)
  assert_eq(builder.mapping_count(), 2)
  assert_eq(builder.names.length(), 1)
  let document = builder.build()
  assert_eq(document.names.length(), 1)
  assert_eq(decode_regular_source_map(document).mappings.length(), 2)
}

///|
test "builder rejects decreasing generated positions" {
  let builder = SourceMapBuilder::new()
  builder.add_generated(generated=Position::new(line=2, column=0))
  try builder.add_generated(generated=Position::new(line=1, column=9)) catch {
    _ => ()
  } noraise {
    _ => fail("expected decreasing position to fail")
  }
}

///|
test "builder validates source and original positions" {
  let builder = SourceMapBuilder::new()
  try
    builder.add_mapping(
      generated=Position::new(line=0, column=0),
      source_index=0,
      original_line=0,
      original_column=0,
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected unknown source to fail")
  }
  let index = builder.add_source(url="source.ts")
  try
    builder.add_mapping(
      generated=Position::new(line=0, column=0),
      source_index=index,
      original_line=-1,
      original_column=0,
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected negative original line to fail")
  }
}

///|
test "builder snapshot is independent and clear is reusable" {
  let builder = SourceMapBuilder::new()
  builder.add_source(url="source.ts") |> ignore
  builder.add_generated(generated=Position::new(line=0, column=0))
  let snapshot = builder.build_decoded()
  builder.clear_mappings()
  assert_eq(builder.mapping_count(), 0)
  assert_eq(snapshot.mappings.length(), 1)
  assert_eq(builder.source_count(), 1)
}
