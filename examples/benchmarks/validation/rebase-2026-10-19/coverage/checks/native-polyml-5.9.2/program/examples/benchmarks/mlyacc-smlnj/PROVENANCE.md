# mlyacc-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mlyacc`.
Original module order, individual headers/notices and adaptation patch are
retained.

David Tarditi and Andrew Appel's parser-generator collection. Preserve
ordered parser/lexer, grammar, core, LALR lookahead, table construction,
compression and code generation modules, with the original Standard ML
grammar.
Suppress console diagnostics; errors propagate. Move the original generator
invocation into the driver. Every generated source/signature byte is checked
against the reviewed native original output. Large preserves 250 calls;
normal selects two. Input origins and individual notices are retained in
the source headers/dataset. File generation/validation are measured work.
No compiler/runtime feature is added through this port. Diagnostic questions
are source-based; see [compiler literature](../literature.md).
