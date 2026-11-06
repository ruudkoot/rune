(* The virtual functor, which takes the function impl.sml exports *)
functor Set = _virtual (O : ORD) : SET where type elem = O.t
