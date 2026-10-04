# Measurement configuration isolation

Recorded 2026-10-04. Separate tool invocations can share a shell PID in their
PID namespaces. The resolver previously used tests/out/matrix/run.$$; its
cleanup could remove another invocation's configs file. Initial Hamming
resolution aborted with an empty configuration file, and an awards attempt
reported a spurious missing Rune configuration. Both raw attempts and their
source/input/tool snapshots are retained here.

The adapter now gives each configuration resolution its own directory inside
the measurement output. The regression creates an inherited matrix worker,
performs a real checked count run and verifies the worker remains intact and
exactly one configuration is returned. A before-fix reproduction demonstrates
that the old adapter deletes the inherited worker. Existing statistics, budget,
incorrect-result and instrumentation checks also pass.

Final concurrent Hamming, SCC and awards count reruns all pass their allocation
and applicable instruction comparisons. Those accepted results are archived
with the workloads. The failed attempts here contribute no performance claim.
