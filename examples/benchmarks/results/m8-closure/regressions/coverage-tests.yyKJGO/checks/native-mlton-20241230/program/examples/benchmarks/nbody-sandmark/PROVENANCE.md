# nbody-sandmark provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/nbody.ml. The header credits Christophe Troestler.
Retain the directory Revised BSD notice and its original CRLF bytes, source,
build/run metadata and identities. The five-body constants are embedded program
data; no external astronomical dataset is acquired.

## Algorithm and known variants

Simulate the Sun and four outer planets by direct pairwise gravitational
updates, fixed timestep 0.01, and a separate position-update pass. Preserve
pair order, dx*otherMass*mag multiplication association, source pi literal,
solar_mass=4*pi*pi, forward mutable momentum sums including the initially
stationary Sun, and kinetic-before-potential energy accumulation.

The classic SML/NJ nbody uses immutable data. nofib's n-body uses a contiguous
seven-slot mutable body layout, different momentum/energy summation order and
position-update placement. Share neither implementation nor name merely because
the physical equations agree. This source's mutable records become SML records
with six real refs and an immutable mass. Record layout, boxing and aliasing
are explicit translation choices. No array-of-scalars replacement or change
to force accumulation is introduced.

## Profiles, observation and validation

Smoke 10 and normal 10,000 are reduced step counts; large preserves the selected
50,000,000-step upstream run. Reconstruct all bodies and offset momentum at
every invocation, including repeated calls. This resets the original mutable
globals and gives each run the same physical initial conditions. Selected
indices/counters fit 31 bits; all numerical work is binary64 on supported hosts.

The original prints two energies with nine fractional digits. The portable
driver checks full-precision initial/final energies and all 35 final body fields,
then reports steps:37:checked. No energy alone substitutes for the complete
state. Absolute/relative budgets are 1e-10/1e-10 for smoke/normal and 1e-5/1e-8
for large, allowing accumulated integration/math-library rounding on the
selected trajectories. They are not general orbit/energy conservation bounds.
Reference parsing and validation are measured work. No physical constants,
step count, timestep or stopping rule is changed.

Original two-line outputs agree with rounded observer energies at 0/10/10,000/
50,000,000 steps. An independent 60-digit integration from the exact zero-step
binary64 state validates all smoke/normal coordinates and velocities, energies
and momentum. At 10,000 steps, maximum state error is about 6.8e-12 and energy
error about 5.3e-16. Full large original state is retained; universal large SML
execution/high-precision large integration is not claimed.

Semantic checks include complete states, independent fresh records, momentum,
hand-computed two-body updates, kinetic/potential energy, one-body drift and
perturbed/missing/nonfinite state rejection. Mutable record allocation, ref
accesses, scalar arithmetic, loop specialization and energy order are diagnostic
hypotheses until investigated by compiler inspection or measurements.

## References

The [Benchmarks Game n-body description](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/nbody.html)
and retained program identify this direct workload. The shared numerical
literature map distinguishes direct pairwise integration from Barnes-Hut tree
approximation; historical timings do not transfer to this port. Standard
reports compare identical SML; OCaml/high-precision physics supply references.
