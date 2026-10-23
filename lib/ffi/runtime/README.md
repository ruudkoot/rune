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

`ForeignOwner` gives native-owned pointers shared closed state, synchronous
borrow guards, duplicate-owner detection and scoped destruction. It uses
native destructor transactions, preserving ownership on annotated failure
and allowing retry with the captured raw status/error. It rejects a close
while a borrow is active; native views also prevent premature destruction.
Closed owners leave the ownership index and cannot become live again when
an allocator reuses their address. This is the strict memory contract;
GUI handles permitting destruction during messages require their explicit
callback protocol. Raw pointer escapes remain the caller's responsibility.

`ForeignGenerated` keeps immutable fixed call descriptors in explicit lazy
sessions. Defining a generated structure opens no libraries. The first call
checks native pointer width, byte order and calling convention, resolves its
symbol through the ordered library paths, and caches the prepared interface.
Session close releases calls and symbols before attempting library unload;
native dependent resources prevent premature unloading, and close can be retried.
