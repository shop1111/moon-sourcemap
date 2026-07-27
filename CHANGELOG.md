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
- Verify all four stable MoonBit targets and selected licensed TC39 cases.
