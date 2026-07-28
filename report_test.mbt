///|
test "mapping spans close within a generated line" {
  let map = lookup_fixture()
  let spans = mapping_spans(map)
  assert_eq(spans.length(), 4)
  assert_true(spans[0].end == Some(Position::new(line=0, column=5)))
  assert_true(spans[0].column_width() == Some(5))
  assert_true(spans[0].contains(Position::new(line=0, column=4)))
  assert_false(spans[0].contains(Position::new(line=0, column=5)))
  assert_true(spans[2].end is None)
  assert_true(spans[3].end is None)
}

///|
test "source map report tracks duplicate and source usage" {
  let map = lookup_fixture()
  let report = analyze_source_map(map)
  assert_eq(report.sources, 2)
  assert_eq(report.mappings, 4)
  assert_eq(report.mapped_segments, 3)
  assert_eq(report.generated_only_segments, 1)
  assert_eq(report.duplicate_positions, 1)
  assert_eq(report.referenced_sources, 2)
  assert_eq(report.unreferenced_sources, 0)
  assert_eq(report.ignored_sources, 1)
  assert_eq(report.source_usage[0].mapped_segments, 2)
}

///|
test "source map report identifies unreferenced embedded source" {
  let map = DecodedSourceMap::new(
    file="bundle.js",
    sources=[
      SourceEntry::new(url="used.ts"),
      SourceEntry::new(url="unused.ts", content="unused"),
    ],
    mappings=[
      Mapping::mapped(
        generated=Position::new(line=0, column=0),
        original=OriginalPosition::new(source_index=0, line=0, column=0),
      ),
    ],
  )
  let report = analyze_source_map(map)
  assert_eq(report.referenced_sources, 1)
  assert_eq(report.unreferenced_sources, 1)
  assert_eq(report.embedded_sources, 1)
  assert_true(report.render().contains("unused.ts"))
  assert_true(report.to_json() is Object(_))
}
