# many_refs provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/many_refs.sml`. Original, patch and notice retained.

ML Kit development allocation/retention workload. Three tables of boxed
real refs and sequential updates are retained. Original table length 100 and
100000 increments are normal; large scales retained refs. Every table is
checked against the exact number of increments, including the two tables
that upstream did not print. Their exact IntInf sum is returned.
