# kitfib35 provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitfib35.sml`. Original, patch and notices retained.

Recursive Fibonacci with the original n<1 base case, returning F(n+2).
This differs from the MLton fib recurrence. Normal preserves argument 35.
The original wildcard discards the number; the driver consumes every result
in an IntInf sum. An iterative recurrence gives independent fixtures.
The mlton and smlnj source variants have the identical kernel and input,
with only entrypoint wrapping differences; their provenance is retained.

Additional source provenance at the same ML Kit revision:

* `test/kitfib35_mlton.sml`: identical kernel and fixed input; entrypoint wrapping only.
* `test/kitfib35_smlnj.sml`: identical kernel and fixed input; entrypoint wrapping only.
