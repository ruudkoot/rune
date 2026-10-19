# mpuz-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/mpuz.sml`.
Stephen Weeks, 1999-08-31, loosely based on Laurent Vaucher's OCaml solution.
Source/header, notice and adaptation patch are retained.

Keep the fixed AGH/FB/CBEE/GHFD/FGIJE multiplication puzzle, all distinct-digit
assignments including zero, mutable usage flags and tuple-based List/String
adapters. These differ from the modern MLton helper interfaces. Replace the
silent print override by complete deterministic capture of actual solution
assignments; no invented success marker is accepted. One original solve is
normal; large selects ten repeats. The captured assignment stream is checked
against the original native solver and the source's known assignment.
Search, tuple calls and allocation are hypotheses; see the classic literature.
