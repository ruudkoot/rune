# mandelbrot provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mandelbrot.sml`. Original, patch and notice retained.

SML/NJ-derived numerical loop. Preserves the unusual upstream coordinate
formula x_base * (delta + j), initial z=c and escape threshold, rather than
substituting a conventional Mandelbrot image. Side and iteration limit are
parameters. Python reproduces the exact iteration convention. For j >= 2 the initial squared real coordinate exceeds four, so the
independent large calculation skips those mathematically zero contributions.
