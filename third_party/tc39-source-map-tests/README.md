# TC39 Source Map Tests attribution

MoonSourceMap uses a small, manually embedded selection of data-only cases from
the official `tc39/source-map-tests` suite. The test code is original MoonBit
code; no implementation code is copied.

- Upstream: https://github.com/tc39/source-map-tests
- Reference revision: `2965987`
- Reference checkout date: 2026-07-28
- Upstream license: BSD-3-Clause-compatible terms in `LICENSE.md`
- Selected cases: valid/invalid version, empty mappings, boundary VLQ,
  negative VLQ, malformed segment arity, and out-of-range source/name indexes

The full upstream checkout is kept outside the product repository at
`references/tc39-source-map-tests` for reproducibility.
