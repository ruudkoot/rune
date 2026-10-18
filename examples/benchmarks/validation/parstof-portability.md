# Parstof portable type annotations

The initial character-merge helper was unannotated. ML Kit defaulted its
comparison to int before its character-list use, rejecting the program.
An explicit char-list pattern gives the intended portable comparison type.

The cached nonterminal parser closures initially used ref NONE without
explicit result types. SML/NJ's value restriction gave the unresolved refs
incompatible dummy types. Explicit types for all 42 cached parser functions
come from the original Haskell nonterminal types and the documented memoized
SML data representation. The grammar, callback demand, algorithms and expected
observations are unchanged.

The first attempt reaches 972 of 1620 assertions, all passing; compile errors
leave 648 incomplete. With only the character annotation, 1134 pass and 486
remain incomplete on three SML/NJ builds. Final typed caches pass all 1620
assertions on every engine and host. Full sources, type queries, compiler logs
and per-configuration summaries remain in the archive. These are portability
corrections rather than reported arithmetic or runtime defects.
