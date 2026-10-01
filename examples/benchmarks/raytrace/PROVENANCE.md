# raytrace provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/raytrace.sml`. Original, adaptation patch and notices retained.

PL Club winning OCaml entry to the 2000 ICFP programming contest, translated
by Stephen Weeks on 2000-10-11. Retains the language evaluator, CSG objects,
lighting, camera, intersections and shader. Keeps the original chess scene;
only its final render dimensions vary: 16x12 smoke, original 400x300 normal,
800x600 large. The original driver swallowed all exceptions; this driver
propagates them and consumes the full PPM image. Output is checked at every RGB pixel after 8-bit quantization against
reviewed upstream images (MLton and both monolithic and suite-driver SML/NJ builds), with at most two intensity
levels of error per channel. Headers and image dimensions remain exact. File I/O is included.

The smoke pixel (12,6) exposes a measured numerical discontinuity: on
MLton its reflected ray has no intersection, while SML/NJ reports an interval
with both endpoints 0.04810688415066595. The original filter tests only
its starting distance, so this zero-width interval changes the reflected
color. The initial hit endpoints differ by less than 1e-15. The original
kernel remains unchanged; each pixel must match one of the recorded original-kernel
program outputs within two 8-bit levels per channel. This is a specified
reference-set bound, not a claim that arbitrary large color errors are
acceptable. Other large reference differences are recorded as hypotheses
of the same discontinuity until individually traced.

The chess input credits Leif Kornstaedt, copyright 2000, revision 1.6.
Its notice is retained in the pristine input. Reference images are generated
from that input by the pinned SML translation on the recorded host versions.

The normal SML/NJ suite-driver build differs at five further pixels from
its monolithic entrypoint. Instrumenting the render can also change these
boundary results. A separate suite-driver reference is retained; this is
recorded source/compilation sensitivity, not a claim that the kernel isolates
a single compiler optimization. Outside the reviewed reference sets, errors
above two intensity levels remain failures.
