# Foreign runtime support

Area: Foreign interfaces

Ordinary SML support over the trusted `RuneForeign` bridge. No primitives
are declared here. `ForeignMemory` owns or bounds native storage and supplies
scoped copies of borrowed SML byte arrays. Overlapping arguments referring
to the same array share backing storage and preserve native aliasing.

Input ranges are snapshots. Output ranges copy back before temporary storage
is released, including exceptional returns. Writes to an output range from
an SML callback are superseded by native bytes at return. Retained native
storage is explicit and released by its owner. Pointer views retain registry
identities but never infer or invoke a foreign deallocator.

Native strings are read by code unit through their first NUL, bounded by
policy, rather than reading an entire maximum extent beyond a terminator.
`ForeignText` performs the subsequent encoding conversion. These operations
remain available to generated raw bindings for explicit low-level access.
