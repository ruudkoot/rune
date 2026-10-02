# lexgen-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/lexgen`.
Original module order, individual headers/notices and adaptation patch are
retained.

James Mattson and David Tarditi's lexical generator. Retain its RedBlack
functor, DFA construction, rule processing and original Standard ML lexer
input. Modern module organization differs from the old MLton monolith.
Suppress console diagnostics; errors propagate. Move the original generator
invocation into the driver. Every generated source/signature byte is checked
against the reviewed native original output. Large preserves 500 calls;
normal selects two. Input origins and individual notices are retained in
the source headers/dataset. File generation/validation are measured work.
No compiler/runtime feature is added through this port. Diagnostic questions
are source-based; see [compiler literature](../literature.md).
