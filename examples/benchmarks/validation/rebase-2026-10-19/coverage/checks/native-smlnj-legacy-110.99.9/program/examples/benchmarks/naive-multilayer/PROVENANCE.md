# naive-multilayer provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/numerical-analysis/naive_multilayer.ml,
naive_multilayer_dataset.ml and dune. Retain the MIT notice, Copyright 2015
Akinori ABE, and OCamlPro adaptation credit. The deterministic default RNG is
OCaml 4.14.1's generator; the existing shared SML port retains its default state
and draw operations, with original source and LGPL 2.1/linking-exception notice.

## Algorithm and variants

Train a 34-input, 10/5-hidden-unit, 2-output network with tanh hidden activations,
softmax output and sequential stochastic gradient descent at eta 0.01. Preserve
all 351 samples in source order, full activation Jacobian matrices, recursive
backpropagation, explicit gradient outer-product matrices and scalar parameter
updates. Compute every layer's delta before mutating any layer's parameters.
Do not simplify the softmax/cross-entropy delta or replace dense Jacobians by
diagonal-vector operations in the measured program. Source gradient diagnostics
and unused/shadowed linear activation definitions are not selected by Main.

OCaml's observed initialization builds the output layer, second hidden layer,
then first hidden layer; each layer draws bias values before weight values.
The SML port makes that order explicit. Rune and MLton reproduce all 417 initial parameters
bit for bit against the original observer, verifying RNG and evaluation order.
Gradient/error arrays are also constructed before their paired Jacobian
arguments, retaining the source's argument evaluation/allocation order.
This imperative sequential program has no separately meaningful lazy variant.

Float arrays become RealArray rows under outer Arrays. Higher-order activation
and derivative fields remain functions; mutable accumulators and fresh arrays
are retained. For loops become portable tail loops. Selected dimensions/counters
fit 31 bits and supported hosts use binary64 real arithmetic. No parallelism,
effect handler, external linear-algebra library or new runtime feature is needed.

## Data, profiles and result checks

Use the complete UCI Ionosphere dataset: 351 rows, 34 features and two classes.
Every source value, label and row position agrees exactly with the downloaded
canonical data. Preserve shared one-hot good/bad target vectors. Retain the raw
upstream module, original UCI data/names files, data identities, CC BY 4.0 notice
and attribution to Sigillito, Wing, Hutton and Baker. Numeric text conversion
preserves the source decimal values; no normalization, shuffle or split is added.

Smoke 1 epoch and normal 20 are reduced iteration settings. Large preserves
Main's 1,000 epochs. Every invocation constructs a fresh model from the original
default RNG state; this reproduces the source's first process invocation.
Repeated in-process calls reset the model/RNG explicitly, rather than advancing
the source's global Random state. Read-only sample data load once on the first
run through a memoized SML delay, keeping file I/O out of host export. Input
parsing, initialization and per-run reference checking are measured work.

The original discards its trained network. The suite checks all 417 weights/
biases, all 702 prediction components and total cross-entropy before reporting
epochs:samples:checked. Parameter/prediction bounds are 2e-8+2e-7*abs(reference);
loss bounds are 1e-7+1e-7*abs(reference). Also check finite values, dimensions,
probability range and sums within 1e-12. These are selected-profile budgets,
not convergence/generalization guarantees. Predictions use the training data.

All original 1,000-epoch execution and 0/1/20/1,000 observer runs complete with
reviewed outputs. Independent structured-derivative SGD validates smoke/normal
without the source's dense Jacobians: parameter differences below 2.6e-15,
predictions below 1.7e-15 and loss below 2.9e-14. Finite differences independently
check every parameter gradient in a small network. Negative checks cover
wrong/missing/nonfinite parameters and tolerance boundaries. Large SML
execution is claimed only where separately recorded.

## Recorded host differences

The standard matrix records a GC-sensitive NaN on legacy64 normal. Nursery-size
diagnostics are consistent with the existing GC-root report; the exact compiler
entry has not been reduced. Native32 passes the full numerical profiles, while
its strict initialization test exposes 62 one-ulp decimal-reader differences.
Exact dyadic reconstruction confirms that its generated RNG parameters are
correct. Keep fixtures/arithmetic unchanged; see the
[host findings](../validation/multilayer-smlnj.md). Numerical-check exceptions
carry an explicit incorrect-result marker so failed values cannot contribute
accepted measurements.

## References and diagnostic questions

[UCI Ionosphere](https://doi.org/10.24432/C5W01B) records the dataset and source
study. [Rumelhart, Hinton and Williams (1986)](https://doi.org/10.1038/323533a0)
anchors backpropagation. The retained program specifies this particular dense
Jacobian implementation, initialization and updates. Function-field
specialization, real boxing, temporary matrices, mutable refs, data initialization,
math-library calls and allocation lifetimes are diagnostic questions until
supported by compiler inspection or measurement. Standard comparisons use
identical SML; OCaml and independent training supply correctness references.
