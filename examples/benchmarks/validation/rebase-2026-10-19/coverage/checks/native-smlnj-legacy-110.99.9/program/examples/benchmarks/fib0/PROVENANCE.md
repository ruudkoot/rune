# fib0 provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/fib0.sml`. Original, patch and notices retained.

Naive Fibonacci with two unit base values, returning F(n+1). Different
base-case structure and values from kitfib35 and MLton fib. Normal retains
the original input 30 and upstream reference 1346269. The runtime-specific
printNum output adapter is replaced with a consumed IntInf result sum;
the recursive arithmetic kernel remains unchanged.
