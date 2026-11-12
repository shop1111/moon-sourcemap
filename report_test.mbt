///|
test "mapping spans close within a generated line" {
  let map = lookup_fixture()
  let spans = @moon_sourcemap.mapping_spans(map)
  assert_eq(spans.length(), 4)
  assert_true(
    spans[0].end == Some(@moon_sourcemap.Position::new(line=0, column=5)),
  )
  assert_true(spans[0].column_width() == Some(5))
  assert_true(
    spans[0].contains(@moon_sourcemap.Position::new(line=0, column=4)),
  )
  assert_false(
    spans[0].contains(@moon_sourcemap.Position::new(line=0, column=5)),
  )
  assert_true(spans[2].end is None)
  assert_true(spans[3].end is None)
}

///|
test "source map report tracks duplicate and source usage" {
  let map = lookup_fixture()
  let report = @moon_sourcemap.analyze_source_map(map)
  assert_eq(report.sources, 2)
  assert_eq(report.mappings, 4)
  assert_eq(report.mapped_segments, 3)
  assert_eq(report.generated_only_segments, 1)
  assert_eq(report.duplicate_positions, 1)
  assert_eq(report.referenced_sources, 2)
  assert_eq(report.unreferenced_sources, 0)
  assert_eq(report.ignored_sources, 1)
  assert_eq(report.source_usage[0].mapped_segments, 2)
  assert_eq(report.generated_line_usage.length(), 2)
  assert_eq(report.generated_line_usage[0].segments, 3)
  assert_eq(report.generated_line_usage[0].duplicate_positions, 1)
  assert_true(report.generated_line(2) is Some(_))
  assert_true(report.busiest_generated_line().map(line => line.line) == Some(0))
  assert_eq(report.empty_generated_lines(), 1)
  assert_true(report.lines_with_duplicates() == [0])
  assert_true(report.generated_only_lines() == [0])
  assert_true(report.ignored_source_indices() == [1])
  assert_true(report.sources_without_content() == [0, 1])
  assert_true(report.unreferenced_source_indices().is_empty())
  assert_true(report.source_usage[0].is_referenced())
  assert_eq(report.generated_line_usage[0].mapping_coverage_percent(), 66)
  assert_eq(report.named_mapping_percent(), 33)
  assert_eq(report.ignored_source_percent(), 50)
  assert_true(report.source(1).map(source => source.ignored) == Some(true))
  assert_true(report.has_quality_warnings())
  assert_eq(report.usable_embedded_sources(), 0)
}

///|
test "source map report identifies unreferenced embedded source" {
  let map = @moon_sourcemap.DecodedSourceMap::new(
    file="bundle.js",
    sources=[
      @moon_sourcemap.SourceEntry::new(url="used.ts"),
      @moon_sourcemap.SourceEntry::new(url="unused.ts", content="unused"),
    ],
    mappings=[
      @moon_sourcemap.Mapping::mapped(
        generated=@moon_sourcemap.Position::new(line=0, column=0),
        original=@moon_sourcemap.OriginalPosition::new(
          source_index=0,
          line=0,
          column=0,
        ),
      ),
    ],
  )
  let report = @moon_sourcemap.analyze_source_map(map)
  assert_eq(report.referenced_sources, 1)
  assert_eq(report.unreferenced_sources, 1)
  assert_eq(report.embedded_sources, 1)
  assert_true(report.render().contains("unused.ts"))
  assert_true(report.to_json() is Object(_))
  assert_eq(report.source_coverage_percent(), 50)
  assert_eq(report.content_coverage_percent(), 50)
  assert_eq(report.mapping_coverage_percent(), 100)
  assert_false(report.has_complete_source_usage())
  assert_true(report.has_complete_mappings())
  assert_true(report.summary().contains("referenced=50%"))
  assert_eq(report.named_mapping_percent(), 0)
  assert_true(report.has_quality_warnings())
  assert_eq(report.usable_embedded_sources(), 0)
}
