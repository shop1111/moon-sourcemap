///|
/// Explicit, deprecated method forms of the derived `Eq` and `Debug`
/// implementations. Older MoonBit toolchains promoted these trait methods
/// implicitly; they are kept here so existing callers of e.g.
/// `position.equal(other)` keep compiling. Prefer `==` / `debug_inspect`.

///|
#deprecated
pub extend ContextualSymbolizationReport with Eq::{equal, not_equal}

///|
#deprecated
pub extend ContextualSymbolizationReport with @debug.Debug::{to_repr}

///|
#deprecated
pub extend ContextualSymbolizedFrame with Eq::{equal, not_equal}

///|
#deprecated
pub extend ContextualSymbolizedFrame with @debug.Debug::{to_repr}

///|
#deprecated
pub extend DecodedSourceMap with Eq::{equal, not_equal}

///|
#deprecated
pub extend DecodedSourceMap with @debug.Debug::{to_repr}

///|
#deprecated
pub extend DiagnosticSeverity with Eq::{equal, not_equal}

///|
#deprecated
pub extend DiagnosticSeverity with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Diagnostic with Eq::{equal, not_equal}

///|
#deprecated
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
#deprecated
pub extend DuplicateMappingPolicy with Eq::{equal, not_equal}

///|
#deprecated
pub extend DuplicateMappingPolicy with @debug.Debug::{to_repr}

///|
#deprecated
pub extend GeneratedLineUsage with Eq::{equal, not_equal}

///|
#deprecated
pub extend GeneratedLineUsage with @debug.Debug::{to_repr}

///|
#deprecated
pub extend GeneratedSpan with Eq::{equal, not_equal}

///|
#deprecated
pub extend GeneratedSpan with @debug.Debug::{to_repr}

///|
#deprecated
pub extend IndexSection with Eq::{equal, not_equal}

///|
#deprecated
pub extend IndexSection with @debug.Debug::{to_repr}

///|
#deprecated
pub extend IndexSourceMap with Eq::{equal, not_equal}

///|
#deprecated
pub extend IndexSourceMap with @debug.Debug::{to_repr}

///|
#deprecated
pub extend LookupBias with Eq::{equal, not_equal}

///|
#deprecated
pub extend LookupBias with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Mapping with Eq::{equal, not_equal}

///|
#deprecated
pub extend Mapping with @debug.Debug::{to_repr}

///|
#deprecated
pub extend MissingMappingPolicy with Eq::{equal, not_equal}

///|
#deprecated
pub extend MissingMappingPolicy with @debug.Debug::{to_repr}

///|
#deprecated
pub extend OriginalPosition with Eq::{equal, not_equal}

///|
#deprecated
pub extend OriginalPosition with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Position with Eq::{equal, not_equal}

///|
#deprecated
pub extend Position with @debug.Debug::{to_repr}

///|
#deprecated
pub extend RegistryMissReason with Eq::{equal, not_equal}

///|
#deprecated
pub extend RegistryMissReason with @debug.Debug::{to_repr}

///|
#deprecated
pub extend RegistrySymbolizationReport with Eq::{equal, not_equal}

///|
#deprecated
pub extend RegistrySymbolizationReport with @debug.Debug::{to_repr}

///|
#deprecated
pub extend RegistrySymbolizedFrame with Eq::{equal, not_equal}

///|
#deprecated
pub extend RegistrySymbolizedFrame with @debug.Debug::{to_repr}

///|
#deprecated
pub extend RegularSourceMap with Eq::{equal, not_equal}

///|
#deprecated
pub extend RegularSourceMap with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourceContext with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourceContext with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourceEntry with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourceEntry with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourceLine with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourceLine with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourceMapDocument with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourceMapDocument with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourceMapError with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourceMapError with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourceMapReport with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourceMapReport with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourcePathKind with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourcePathKind with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SourceUsage with Eq::{equal, not_equal}

///|
#deprecated
pub extend SourceUsage with @debug.Debug::{to_repr}

///|
#deprecated
pub extend StackFrame with Eq::{equal, not_equal}

///|
#deprecated
pub extend StackFrame with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SymbolizedFrame with Eq::{equal, not_equal}

///|
#deprecated
pub extend SymbolizedFrame with @debug.Debug::{to_repr}

///|
#deprecated
pub extend VlqValue with Eq::{equal, not_equal}

///|
#deprecated
pub extend VlqValue with @debug.Debug::{to_repr}
