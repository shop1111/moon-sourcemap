///|
/// Policy for outer mappings that cannot be resolved through the inner map.
pub(all) enum MissingMappingPolicy {
  KeepGenerated
  Drop
} derive(Eq, Debug)

///|
/// Options controlling two-stage map composition.
pub(all) struct ComposeOptions {
  bias : LookupBias
  missing : MissingMappingPolicy
  preserve_outer_names : Bool
}

///|
/// Default composition options.
pub fn ComposeOptions::default() -> ComposeOptions {
  {
    bias: GreatestLowerBound,
    missing: KeepGenerated,
    preserve_outer_names: true,
  }
}

///|
/// Statistics returned by detailed composition.
pub(all) struct ComposeStats {
  outer_mappings : Int
  composed_mappings : Int
  generated_only : Int
  dropped : Int
}

///|
/// A composed map together with coverage statistics.
pub(all) struct ComposeResult {
  map : DecodedSourceMap
  stats : ComposeStats
}

///|
fn composed_name(
  outer : Mapping,
  inner : Mapping,
  preserve_outer_names : Bool,
) -> String? {
  if preserve_outer_names {
    match outer.name {
      Some(name) => Some(name)
      None => inner.name
    }
  } else {
    inner.name
  }
}

///|
fn compose_one(
  outer : Mapping,
  inner_map : DecodedSourceMap,
  options : ComposeOptions,
) -> Mapping? {
  match outer.original {
    None =>
      match options.missing {
        KeepGenerated =>
          Some(Mapping::generated_only(generated=outer.generated))
        Drop => None
      }
    Some(intermediate) => {
      let inner = original_position_for(
        inner_map,
        generated=Position::new(
          line=intermediate.line,
          column=intermediate.column,
        ),
        bias=options.bias,
      )
      match inner {
        Some(inner) =>
          match inner.original {
            Some(original) =>
              Some(
                Mapping::mapped(
                  generated=outer.generated,
                  original~,
                  name?=composed_name(
                    outer,
                    inner,
                    options.preserve_outer_names,
                  ),
                ),
              )
            None =>
              match options.missing {
                KeepGenerated =>
                  Some(Mapping::generated_only(generated=outer.generated))
                Drop => None
              }
          }
        None =>
          match options.missing {
            KeepGenerated =>
              Some(Mapping::generated_only(generated=outer.generated))
            Drop => None
          }
      }
    }
  }
}

///|
/// Compose two decoded source maps and return coverage statistics.
///
/// `outer` maps final generated code to an intermediate artifact. `inner` maps
/// that artifact to original sources. The composed source table is copied from
/// `inner`, and the generated file is copied from `outer`.
pub fn compose_with_options(
  outer : DecodedSourceMap,
  inner : DecodedSourceMap,
  options? : ComposeOptions = ComposeOptions::default(),
) -> ComposeResult {
  let mappings : Array[Mapping] = []
  let mut composed_mappings = 0
  let mut generated_only = 0
  let mut dropped = 0
  for mapping in outer.mappings {
    match compose_one(mapping, inner, options) {
      Some(composed) => {
        if composed.original is Some(_) {
          composed_mappings = composed_mappings + 1
        } else {
          generated_only = generated_only + 1
        }
        mappings.push(composed)
      }
      None => dropped = dropped + 1
    }
  }
  let map = DecodedSourceMap::new(
    file?=outer.file,
    sources=inner.sources.copy(),
    mappings~,
  )
  {
    map,
    stats: {
      outer_mappings: outer.mappings.length(),
      composed_mappings,
      generated_only,
      dropped,
    },
  }
}

///|
/// Compose final-to-intermediate and intermediate-to-original decoded maps.
pub fn compose(
  generated_to_intermediate : DecodedSourceMap,
  intermediate_to_original : DecodedSourceMap,
) -> DecodedSourceMap {
  compose_with_options(generated_to_intermediate, intermediate_to_original).map
}

///|
/// Parse, flatten and compose two source-map JSON documents.
pub fn compose_json(
  outer_json : StringView,
  inner_json : StringView,
  indent? : Int,
) -> String raise SourceMapError {
  let outer = decode_document(parse_document(outer_json))
  let inner = decode_document(parse_document(inner_json))
  let document = SourceMapDocument::Regular(
    encode_decoded(compose(outer, inner)),
  )
  encode_document(document, indent?)
}
