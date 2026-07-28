///|
/// One symbolized frame with optional embedded source context.
pub(all) struct ContextualSymbolizedFrame {
  result : SymbolizedFrame
  context : SourceContext?
} derive(Eq, Debug)

///|
/// Aggregate single-map symbolization outcome.
pub(all) struct ContextualSymbolizationReport {
  frames : Array[ContextualSymbolizedFrame]
  matched : Int
  unmatched : Int
  with_context : Int
} derive(Eq, Debug)

///|
/// Symbolize one frame and attach embedded source context when available.
pub fn symbolize_frame_with_context(
  map : DecodedSourceMap,
  frame : StackFrame,
  bias? : LookupBias = GreatestLowerBound,
  context_radius? : Int = 1,
) -> ContextualSymbolizedFrame {
  let result = symbolize_frame(map, frame, bias~)
  let context = if result.matched && context_radius >= 0 {
    let mapping = original_position_for(
      map,
      generated=Position::new(
        line=result.generated.line,
        column=result.generated.column,
      ),
      bias~,
    )
    match mapping {
      Some(mapping) =>
        source_context_for_mapping(map, mapping, radius=context_radius)
      None => None
    }
  } else {
    None
  }
  { result, context }
}

///|
/// Parse and symbolize newline-separated frames with source context.
pub fn symbolize_with_context(
  map : DecodedSourceMap,
  frames : String,
  bias? : LookupBias = GreatestLowerBound,
  context_radius? : Int = 1,
) -> ContextualSymbolizationReport raise SourceMapError {
  if context_radius < 0 {
    raise InvalidField(
      path="$context",
      message="context radius must be non-negative",
    )
  }
  let results : Array[ContextualSymbolizedFrame] = []
  let mut matched = 0
  let mut unmatched = 0
  let mut with_context = 0
  for line in frames.split("\n") {
    let text = line.trim()
    if text.is_empty() {
      continue
    }
    let contextual = symbolize_frame_with_context(
      map,
      parse_stack_frame(text.to_owned()),
      bias~,
      context_radius~,
    )
    if contextual.result.matched {
      matched = matched + 1
    } else {
      unmatched = unmatched + 1
    }
    if contextual.context is Some(_) {
      with_context = with_context + 1
    }
    results.push(contextual)
  }
  { frames: results, matched, unmatched, with_context }
}

///|
/// Convert one contextual result to JSON.
pub fn ContextualSymbolizedFrame::to_json(
  self : ContextualSymbolizedFrame,
) -> Json {
  Json::object({
    "result": self.result.to_json(),
    "context": match self.context {
      Some(context) => context.to_json()
      None => Json::null()
    },
  })
}

///|
/// Render one contextual result.
pub fn ContextualSymbolizedFrame::render(
  self : ContextualSymbolizedFrame,
) -> String {
  let output = StringBuilder()
  output.write_string(self.result.render())
  match self.context {
    Some(context) => {
      output.write_char('\n')
      output.write_string(context.render())
    }
    None => ()
  }
  output.to_string()
}

///|
/// Convert a contextual report to stable JSON.
pub fn ContextualSymbolizationReport::to_json(
  self : ContextualSymbolizationReport,
) -> Json {
  Json::object({
    "matched": Json::number(self.matched.to_double()),
    "unmatched": Json::number(self.unmatched.to_double()),
    "with_context": Json::number(self.with_context.to_double()),
    "frames": Json::array(self.frames.map(frame => frame.to_json())),
  })
}

///|
/// Render every contextual result.
pub fn ContextualSymbolizationReport::render(
  self : ContextualSymbolizationReport,
) -> String {
  self.frames.map(frame => frame.render()).join("\n")
}

///|
/// Return true when all frames were mapped.
pub fn ContextualSymbolizationReport::is_complete(
  self : ContextualSymbolizationReport,
) -> Bool {
  self.frames.length() == self.matched
}

///|
/// Return true when every mapped frame has embedded source context.
pub fn ContextualSymbolizationReport::has_complete_context(
  self : ContextualSymbolizationReport,
) -> Bool {
  self.matched == self.with_context
}

///|
/// Return only unmatched generated frames.
pub fn ContextualSymbolizationReport::unmatched_frames(
  self : ContextualSymbolizationReport,
) -> Array[StackFrame] {
  let result : Array[StackFrame] = []
  for frame in self.frames {
    if !frame.result.matched {
      result.push(frame.result.generated)
    }
  }
  result
}
