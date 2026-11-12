///|
fn section_map(
  source : String,
  mappings : Array[@moon_sourcemap.Mapping],
) -> @moon_sourcemap.SourceMapDocument raise @moon_sourcemap.SourceMapError {
  let names : Array[String] = []
  for mapping in mappings {
    match mapping.name {
      Some(name) => if !names.contains(name) { names.push(name) }
      None => ()
    }
  }
  Regular(
    @moon_sourcemap.RegularSourceMap::new(
      sources=[Some(source)],
      names~,
      mappings=@moon_sourcemap.encode_mappings(mappings, names~),
    ),
  )
}

///|
test "index decoding applies first-line column offset only" {
  let first = section_map("a.ts", [
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=0, column=1),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=0,
        column=0,
      ),
    ),
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=1, column=2),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=1,
        column=0,
      ),
    ),
  ])
  let index = @moon_sourcemap.SourceMapDocument::Indexed(
    @moon_sourcemap.IndexSourceMap::new(sections=[
      @moon_sourcemap.IndexSection::new(
        offset=@moon_sourcemap.Position::new(line=3, column=7),
        map=first,
      ),
    ]),
  )
  let decoded = @moon_sourcemap.decode_document(index)
  assert_eq(decoded.mappings[0].generated.line, 3)
  assert_eq(decoded.mappings[0].generated.column, 8)
  assert_eq(decoded.mappings[1].generated.line, 4)
  assert_eq(decoded.mappings[1].generated.column, 2)
}

///|
test "flatten remaps source indices across sections" {
  let first = section_map("a.ts", [
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=0, column=0),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=0,
        column=0,
      ),
      name="alpha",
    ),
  ])
  let second = section_map("b.ts", [
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=0, column=0),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=4,
        column=2,
      ),
      name="beta",
    ),
  ])
  let document = @moon_sourcemap.SourceMapDocument::Indexed(
    @moon_sourcemap.IndexSourceMap::new(file="bundle.js", sections=[
      @moon_sourcemap.IndexSection::new(
        offset=@moon_sourcemap.Position::new(line=0, column=0),
        map=first,
      ),
      @moon_sourcemap.IndexSection::new(
        offset=@moon_sourcemap.Position::new(line=2, column=0),
        map=second,
      ),
    ]),
  )
  let regular = @moon_sourcemap.flatten(document)
  assert_eq(regular.sources.length(), 2)
  assert_true(regular.sources[0] == Some("a.ts"))
  assert_true(regular.sources[1] == Some("b.ts"))
  assert_true(regular.names == ["alpha", "beta"])
  let decoded = @moon_sourcemap.decode_regular_source_map(regular)
  guard decoded.mappings[1].original is Some(original) else {
    fail("expected mapped section")
  }
  assert_eq(original.source_index, 1)
  assert_eq(decoded.mappings[1].generated.line, 2)
}

///|
test "nested index maps flatten recursively" {
  let leaf = section_map("nested.ts", [
    @moon_sourcemap.Mapping::mapped(
      generated=@moon_sourcemap.Position::new(line=0, column=2),
      original=@moon_sourcemap.OriginalPosition::new(
        source_index=0,
        line=9,
        column=1,
      ),
    ),
  ])
  let inner = @moon_sourcemap.SourceMapDocument::Indexed(
    @moon_sourcemap.IndexSourceMap::new(sections=[
      @moon_sourcemap.IndexSection::new(
        offset=@moon_sourcemap.Position::new(line=1, column=4),
        map=leaf,
      ),
    ]),
  )
  let outer = @moon_sourcemap.SourceMapDocument::Indexed(
    @moon_sourcemap.IndexSourceMap::new(sections=[
      @moon_sourcemap.IndexSection::new(
        offset=@moon_sourcemap.Position::new(line=2, column=6),
        map=inner,
      ),
    ]),
  )
  let decoded = @moon_sourcemap.decode_document(outer)
  assert_eq(decoded.mappings.length(), 1)
  assert_eq(decoded.mappings[0].generated.line, 3)
  assert_eq(decoded.mappings[0].generated.column, 6)
}
