(* Later uses may resolve an expansive binding's type, but must agree. *)
datatype 'a choice = Vacant | Present of 'a
fun conflictingUses () =
  let
    val empty = (fn value => value) Vacant
    val first = empty = Present 0
  in (first,empty = Present true) end
