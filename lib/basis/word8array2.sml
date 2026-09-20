(* Word8Array2: two-dimensional arrays of bytes (optional in the
   specification), whose rows and columns are Word8Vector.vector values. *)
structure Word8Array2 = RuneMonoArray2Fn (structure V = Word8Vector)
