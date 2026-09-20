(* Word8Array2: two-dimensional arrays of bytes (optional in the
   specification), whose rows and columns are Word8Vector.vector values.

   Implements: MONO_ARRAY2 where type vector = Word8Vector.vector where type
   elem = Word8.word

   Status: optional *)
structure Word8Array2 = RuneMonoArray2Fn (structure V = Word8Vector)
