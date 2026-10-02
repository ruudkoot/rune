# kitloop2 provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitloop2.sml`. Original, patch and notices retained.

Tail-recursive lexicographic pair countdown. Retains the original
borrow/reset transition and pair argument. Normal preserves the corrected
upstream maximum 375; large uses the older stated value 2000. Stop only at
(0,0), and return the observed pair instead of printing a done marker.
Tail calls, tuple representation and allocation are diagnostic hypotheses.
