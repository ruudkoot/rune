# Poly/ML strict component-tree probe

Managed Poly/ML 5.9.2 reports
InternalError: entryNumber - not a record raised while compiling
for an auxiliary strict merge test. The eighteen other Rune/host invocations
pass all 113 assertions. The two Poly/ML invocations execute no assertions:
their compile errors leave 226 checks incomplete.

The full kernel and both functor instantiations compile independently.
All four normal application pilots (100 iterations, five-by-five tiling)
also compile and pass on this host. A diagnostic prefix passes its first
98 assertions, including all complete original-state comparisons. Adding
the strict merge check reproduces the compiler failure; the following
isolated caller also reproduces it after loading the suite's suspension,
finite-list, figure-data and component-kernel sources:

~~~sml
structure E = BenchCompLabFn (BenchStrict)
val a = E.makeTree 2 (E.F.fromList [1,2])
val b = E.makeTree 2 (E.F.fromList [2,3])
val tree = E.treeUnion (#2 (BenchStrict.force a))
                      (#2 (BenchStrict.force b))
val _ = if E.F.toList (E.flatten tree) = [1,2,2,3]
        then print "PASS strict merge\n" else raise Fail "strict merge"
~~~

The source merge deliberately retains duplicates. The ordinary typed tuple
projection and source assertion remain unchanged. No Poly/ML compiler fix,
alternative expected result or host-specific kernel is introduced. The exact
compiler pass responsible is not established and no issue was posted.

One initial direct probe used an address-space quota incompatible with
Poly/ML's allocator reservation and failed before loading sources. The final
probe uses the same data quota and bounded heap/stack settings as program
mode in Rune's host runner; that allocator setup failure is retained separately.
