# kitdangle provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitdangle.sml`. Original, patch and notices retained.

One retained closure chain.
Preserves each strict 2000-element payload list and the captured (m,list)
pair inside the singleton. Primitive polymorphic equality is replaced by
SML97 equality. The driver forces each completed chain once to consume its
result; the original dropped the function without evaluating it. This
additional forcing is explicit, and the triangular-number sum independently
validates construction. Normal preserves depth 1000 and payload 2000.
