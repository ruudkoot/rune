# kittmergesort provenance

Source collection: mlkit

Revision: `6dab5582db22a5f5672ca1fc5244171687d83ce5`

Path: `test/kittmergesort.sml`

Upstream credits Paulson, ML for the Working Programmer, page 99. GPL and ML Kit notices accompany the port.

Inputs, validation, literature and all changes are recorded in [the suite README](../README.md#kittmergesort).

Additional source provenance at the same ML Kit revision:

* `test/kittmergesort_smlnj.sml`: identical kernel and fixed input; entrypoint wrapping only.

The copying kernel and validation live in shared/kittmergesort.sml, with
separate thin named drivers. Each compilation contains one Benchmark
structure; there is no alias/rebinding of another benchmark driver.
