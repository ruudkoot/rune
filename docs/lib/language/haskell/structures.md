# Structures and what they implement

[Haskell 98 front end](README.md)

Every public structure of the library, with the signature it says it implements. Each has a page of
its own, which shows its members with the types it gives them; the signature's page says what they
mean. A signature of *none* means that no signature of the library names the structure: its own page
is then the only place it is described. *in* before a signature means that the signature of the
structure around it specifies this one.

`:>` before a signature means that the source seals the structure with it, so that its types are its
own; `:` that it matches it, which the test suite checks. Either way a program sees the members that
the signature names and no others.

| Structure |  | Signature | Realisations |  | Source |
| --- | --- | --- | --- | --- | --- |
| [`Core`](str/Core.md) | : | [`CORE`](sig/CORE.md) |  |  | [lib/language/haskell/core.sml](../../../../lib/language/haskell/core.sml) |
| [`CoreGen`](str/CoreGen.md) | : | [`CORE_GEN`](sig/CORE_GEN.md) |  |  | [lib/language/haskell/coregen.sml](../../../../lib/language/haskell/coregen.sml) |
| [`CoreInterp`](str/CoreInterp.md) | : | [`CORE_INTERP`](sig/CORE_INTERP.md) |  |  | [lib/language/haskell/coreinterp.sml](../../../../lib/language/haskell/coreinterp.sml) |
| [`CoreLint`](str/CoreLint.md) | : | [`CORE_LINT`](sig/CORE_LINT.md) |  |  | [lib/language/haskell/corelint.sml](../../../../lib/language/haskell/corelint.sml) |
| [`CorePrim`](str/CorePrim.md) | : | [`CORE_PRIM`](sig/CORE_PRIM.md) |  |  | [lib/language/haskell/coreprim.sml](../../../../lib/language/haskell/coreprim.sml) |
| [`CoreRuntime`](str/CoreRuntime.md) | :> | [`CORE_RUNTIME`](sig/CORE_RUNTIME.md) |  |  | [lib/language/haskell/coreruntime.sml](../../../../lib/language/haskell/coreruntime.sml) |
| [`CoreText`](str/CoreText.md) | : | [`CORE_TEXT`](sig/CORE_TEXT.md) |  |  | [lib/language/haskell/coretext.sml](../../../../lib/language/haskell/coretext.sml) |
| [`CoreToMid`](str/CoreToMid.md) | : | [`CORE_TO_MID`](sig/CORE_TO_MID.md) |  |  | [lib/language/haskell/coretomid.sml](../../../../lib/language/haskell/coretomid.sml) |
| [`HsAst`](str/HsAst.md) | :> | [`HS_AST`](sig/HS_AST.md) |  |  | [lib/language/haskell/ast.sml](../../../../lib/language/haskell/ast.sml) |
| [`HsChar`](str/HsChar.md) | :> | [`HS_CHAR`](sig/HS_CHAR.md) |  |  | [lib/language/haskell/char.sml](../../../../lib/language/haskell/char.sml) |
| [`HsClasses`](str/HsClasses.md) | :> | [`HS_CLASSES`](sig/HS_CLASSES.md) |  |  | [lib/language/haskell/classes.sml](../../../../lib/language/haskell/classes.sml) |
| [`HsDump`](str/HsDump.md) | :> | [`HS_DUMP`](sig/HS_DUMP.md) |  |  | [lib/language/haskell/dump.sml](../../../../lib/language/haskell/dump.sml) |
| [`HsEvidence`](str/HsEvidence.md) | :> | [`HS_EVIDENCE`](sig/HS_EVIDENCE.md) |  |  | [lib/language/haskell/evidence.sml](../../../../lib/language/haskell/evidence.sml) |
| [`HsFixity`](str/HsFixity.md) | :> | [`HS_FIXITY`](sig/HS_FIXITY.md) |  |  | [lib/language/haskell/fixity.sml](../../../../lib/language/haskell/fixity.sml) |
| [`HsInfer`](str/HsInfer.md) | :> | [`HS_INFER`](sig/HS_INFER.md) |  |  | [lib/language/haskell/infer.sml](../../../../lib/language/haskell/infer.sml) |
| [`HsKinds`](str/HsKinds.md) | :> | [`HS_KINDS`](sig/HS_KINDS.md) |  |  | [lib/language/haskell/kinds.sml](../../../../lib/language/haskell/kinds.sml) |
| [`HsLayout`](str/HsLayout.md) | :> | [`HS_LAYOUT`](sig/HS_LAYOUT.md) |  |  | [lib/language/haskell/layout.sml](../../../../lib/language/haskell/layout.sml) |
| [`HsLexer`](str/HsLexer.md) | :> | [`HS_LEXER`](sig/HS_LEXER.md) |  |  | [lib/language/haskell/lexer.sml](../../../../lib/language/haskell/lexer.sml) |
| [`HsLiterate`](str/HsLiterate.md) | :> | [`HS_LITERATE`](sig/HS_LITERATE.md) |  |  | [lib/language/haskell/literate.sml](../../../../lib/language/haskell/literate.sml) |
| [`HsModules`](str/HsModules.md) | :> | [`HS_MODULES`](sig/HS_MODULES.md) |  |  | [lib/language/haskell/modules.sml](../../../../lib/language/haskell/modules.sml) |
| [`HsParser`](str/HsParser.md) | :> | [`HS_PARSER`](sig/HS_PARSER.md) |  |  | [lib/language/haskell/parser.sml](../../../../lib/language/haskell/parser.sml) |
| [`HsPrint`](str/HsPrint.md) | :> | [`HS_PRINT`](sig/HS_PRINT.md) |  |  | [lib/language/haskell/print.sml](../../../../lib/language/haskell/print.sml) |
| [`HsRename`](str/HsRename.md) | :> | [`HS_RENAME`](sig/HS_RENAME.md) |  |  | [lib/language/haskell/rename.sml](../../../../lib/language/haskell/rename.sml) |
| [`HsScc`](str/HsScc.md) | :> | [`HS_SCC`](sig/HS_SCC.md) |  |  | [lib/language/haskell/scc.sml](../../../../lib/language/haskell/scc.sml) |
| [`HsSource`](str/HsSource.md) | :> | [`HS_SOURCE`](sig/HS_SOURCE.md) |  |  | [lib/language/haskell/source.sml](../../../../lib/language/haskell/source.sml) |
| [`HsStringMap`](str/HsStringMap.md) | :> | [`HS_STRING_MAP`](sig/HS_STRING_MAP.md) |  |  | [lib/language/haskell/strmap.sml](../../../../lib/language/haskell/strmap.sml) |
| [`HsToken`](str/HsToken.md) | :> | [`HS_TOKEN`](sig/HS_TOKEN.md) |  |  | [lib/language/haskell/token.sml](../../../../lib/language/haskell/token.sml) |
| [`HsTypes`](str/HsTypes.md) | :> | [`HS_TYPES`](sig/HS_TYPES.md) |  |  | [lib/language/haskell/types.sml](../../../../lib/language/haskell/types.sml) |

---

<sub>Generated by runedoc; do not edit.</sub>
