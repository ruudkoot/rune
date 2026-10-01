# ray provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/ray.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories stack-language ray tracer from the SML/NJ collection.
Retains the original sphere scene, interpreter, camera and shading routines.
The image side is a runtime parameter; normal preserves 512x512, and the
same unit-square sampling convention is retained. Consume the entire dump
image and compare its encoded pixels/header byte-exactly against the pinned
upstream MLton output. This is a zero-error bound in quantized output units,
not a tolerance on unencoded floating-point intermediates. File writes and
validation reads are part of the workload.
