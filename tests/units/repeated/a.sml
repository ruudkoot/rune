(* given twice (the files of this test): two units, each with its own globals, as
   in a program compiled whole (S91; build-cache issue 22, in batch) *)
structure A = struct val n = ref 0 end
