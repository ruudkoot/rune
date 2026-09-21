(* CharArray2: two-dimensional arrays of characters (optional in the
   specification), whose rows and columns are strings.

   Implements: MONO_ARRAY2 where type vector = CharVector.vector where type
   elem = char

   Status: optional *)
structure CharArray2 :> MONO_ARRAY2 where type vector = CharVector.vector where type elem = char = RuneMonoArray2Fn (structure V = CharVector)
