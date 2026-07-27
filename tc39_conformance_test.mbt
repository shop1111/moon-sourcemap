///|
fn expect_tc39_valid(json : StringView) -> Unit raise {
  let document = parse_document(json)
  let diagnostics = validate(document)
  if diagnostics_have_errors(diagnostics) {
    fail("expected selected TC39 fixture to be valid")
  }
}

///|
fn expect_tc39_invalid(json : StringView) -> Unit raise {
  try parse_document(json) catch {
    _ => return
  } noraise {
    document =>
      if !diagnostics_have_errors(validate(document)) {
        fail("expected selected TC39 fixture to be invalid")
      }
  }
}

///|
test "TC39 selected version and empty mapping cases" {
  expect_tc39_valid(
    (
      #|{
      #|  "version" : 3,
      #|  "sources": [],
      #|  "names": [],
      #|  "mappings": ""
      #|}
    ),
  )
  expect_tc39_invalid(
    (
      #|{
      #|  "version" : 4,
      #|  "sources": [],
      #|  "names": [],
      #|  "mappings": ""
      #|}
    ),
  )
  expect_tc39_invalid(
    (
      #|{
      #|  "sources": [],
      #|  "names": [],
      #|  "mappings": ""
      #|}
    ),
  )
}

///|
test "TC39 selected boundary VLQ case" {
  expect_tc39_valid(
    (
      #|{
      #|  "version": 3,
      #|  "names": ["foo"],
      #|  "file": "valid-mapping-boundary-values.js",
      #|  "sources": ["empty-original.js"],
      #|  "sourcesContent": [""],
      #|  "mappings": "+/////DA+/////D+/////DA"
      #|}
    ),
  )
}

///|
test "TC39 selected negative VLQ case" {
  expect_tc39_valid(
    (
      #|{
      #|  "version": 3,
      #|  "names": [],
      #|  "sources": ["vlq-valid-negative-digit-original.js"],
      #|  "sourcesContent": ["\n 4;3"],
      #|  "mappings": ";;eACG,bAAF"
      #|}
    ),
  )
}

///|
test "TC39 selected invalid mapping arity cases" {
  expect_tc39_invalid(
    (
      #|{"version":3,"sources":["a.js"],"names":[],"mappings":"AA"}
    ),
  )
  expect_tc39_invalid(
    (
      #|{"version":3,"sources":["a.js"],"names":[],"mappings":"AAA"}
    ),
  )
  expect_tc39_invalid(
    (
      #|{"version":3,"sources":["a.js"],"names":[],"mappings":","}
    ),
  )
}

///|
test "TC39 selected mapping index bounds cases" {
  expect_tc39_invalid(
    (
      #|{"version":3,"sources":[],"names":[],"mappings":"AAAA"}
    ),
  )
  expect_tc39_invalid(
    (
      #|{"version":3,"sources":["a.js"],"names":[],"mappings":"AAAAA"}
    ),
  )
}
