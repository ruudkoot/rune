# barnes-hut provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/barnes-hut.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories three-dimensional Barnes-Hut simulation from the
SML/NJ collection. Retains the Plummer distribution, seed 123, octree,
force approximation, leapfrog integration, dtime=.025, eps=.05 and tol=1.
Normal and large preserve the original stop time 2.0; smoke uses .05.
Observe every final position and velocity component rather than discarding
the simulation. Reference state comes from the pinned source compiled by
MLton, with a read-only observer, and uses 17 significant decimal digits.
Compare each component with absolute tolerance 1e-8 plus relative 1e-6.
Returns the actual body and step counts after validation.
