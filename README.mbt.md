# MoonSourceMap

MoonSourceMap is a pure MoonBit implementation of the ECMA-426 Source Map
format. It is an original implementation for consuming, producing, validating,
querying, composing, and symbolizing source maps.

The project is under active development. The first public milestone provides
the data model, Base64-VLQ codec, mappings codec, validation, lookup, a CLI, and
conformance-oriented tests.

## Status

- Module: `shop1111/moon_sourcemap`
- License: Apache-2.0
- Standard: ECMA-426
- Stable targets: wasm, wasm-gc, JavaScript, and native

## Non-goals for v0.1

The first release does not implement the experimental Scopes, Range Mappings,
Debug ID, or Env proposals.
