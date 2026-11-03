(* The virtual functor: the program's units apply Table, compiled against
   KEY and TABLE alone, and its build file says which implementation that
   is (docs/build.md, Virtual modules). *)
functor Table = _virtual (K : KEY) : TABLE where type key = K.t
