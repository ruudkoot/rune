(* CharArray2: two-dimensional arrays of characters (optional in the
   specification), whose rows and columns are strings. *)
structure CharArray2 = RuneMonoArray2Fn (structure V = CharVector)
