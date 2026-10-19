# Hidden-line rendering on SML/NJ

The lazy variant passes the small profile on the managed 32-bit 110.99.9 and
2026.2 development hosts. The 64-bit 110.99.9 host fails with a domain error
or a coordinate mismatch. A smoke replay changing only the nursery fails at
128 KiB and passes at 64 MiB. This is consistent with the existing
[legacy GC corruption report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md),
but nursery sensitivity alone does not establish the same cause. The canonical
configuration keeps its default nursery and its failure.

The strict variant also fails on the 32-bit legacy and development hosts.
A reduced command-constructor observer uses coordinates 1.25 and 2.5, with no
scene parsing or visibility work. Both numeric policies return those
values from an accessor inside the kernel functor. External matching of the
lazy command also works. External matching of the strict two-field command reads
garbage on all three SML/NJ hosts. MLton, Poly/ML and ML Kit pass the same checks.

This has the same reduced type-constructor/real-payload pattern documented in
the [PIC constructor report](../../../docs/bugreport/smlnj/Datatype/real-pair-through-type-constructor/BUGREPORT.md).
The diagnostic keeps its accessor on a private copy of the kernel; it does not
alter the measured benchmark or hide its failing external pattern match.

The primary consumer validates every emitted x/y word and path command.
Auxiliary tests additionally inspect full edge coordinates and rotated vertices.
Keep incomplete auxiliary invocations, failed assertions, runtime failures and
unreached checks visible in their ledger. No failing correctness check supplies
an accepted timing sample. Source arithmetic and the benchmark fixtures are
unchanged.
