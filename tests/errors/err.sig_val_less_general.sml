(* rule 2's instance in 5.5: a structure's value less general than its
   specification. The value restriction leaves ref [] monomorphic, which
   no signature may generalise (the linting roadmap's E13) *)
structure S : sig val r : 'a list ref end = struct val r = ref [] end
