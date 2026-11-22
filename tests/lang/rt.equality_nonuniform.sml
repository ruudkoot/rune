(* = on a non-uniform datatype, whose constructor takes it at a bigger
   type: at -O2 the equality functions of each type (docs/ir.md, equality)
   stop at a type of 256 nodes, past which = is the runtime's, so that the
   compile ends (the haskell98 roadmap's M7: it overflowed the compiler's
   stack) *)
datatype 'a nest = N | C of 'a * ('a * 'a) nest
val a = C (1, C ((2, 3), N))
val b = C (1, C ((2, 4), N))
val () = print (if a = b then "same\n" else "differ\n")
val () = print (if a = a then "same\n" else "differ\n")
val () = print (if C ((1, 2), N) = C ((1, 2), N) then "same\n" else "differ\n")
