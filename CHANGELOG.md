# Changelog

## 0.1.2 - 2026-11-12

- Verify against MoonBit `moon 0.1.20261104` / `moonc v0.10.20+65efd5b93`;
  moonc v0.10.20 is now the minimum supported compiler.
- Migrate to `#derive(...)` and `x~ : T = default` optional-argument syntax.
- Export the formerly implicit `equal`, `not_equal` and `to_repr` methods
  through explicit, deprecated `extend` declarations so existing callers keep
  compiling without `implicit_impl_as_method` warnings.
- Qualify blackbox test references with `@moon_sourcemap` and drop the unused
  `moonbitlang/core/json` import from the CLI package.
- Run CI weekly against the latest official toolchain.

## 0.1.1 - 2026-08-23

- Implement ECMA-426 `GetOriginalPositions` for deterministic multi-result
  queries at duplicate generated positions.
- Add `lookup --all` text/JSON output, strict-miss handling and argument
  conflict validation.
- Encode the minimum 32-bit integer as the canonical VLQ `B` and reject
  unsigned intermediate values outside 32 bits.
- Preserve data and opaque URIs while continuing to normalize hierarchical
  HTTP, file, protocol-relative and filesystem paths.

## 0.1.0 - 2026-07-28

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
