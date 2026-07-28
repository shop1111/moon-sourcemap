# Changelog

## 0.1.0 - Unreleased

- Parse and encode regular and index ECMA-426 source maps.
- Encode and decode full MoonBit `Int` Base64-VLQ values.
- Validate document fields, mapping deltas, indexes, section ordering and
  overlap with structured diagnostics.
- Query generated and original positions with GLB/LUB bias.
- Flatten index maps, compose build stages and symbolize stack frames.
- Build normalized maps incrementally and canonicalize decoded maps.
- Provide `validate`, `lookup`, `flatten`, `compose` and `symbolize` CLI
  commands with stable JSON output and exit codes.
- Resolve source URLs relative to map URLs and index embedded source context.
- Analyze generated spans, source usage and mapping coverage through `inspect`.
- Route and symbolize multi-file stack traces with `SourceMapRegistry`.
- Verify all four stable MoonBit targets and selected licensed TC39 cases.
