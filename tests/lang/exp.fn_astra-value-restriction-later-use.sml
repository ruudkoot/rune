(* Regression for Millet 5028: these expansive initializers have unresolved
   types at the binding, but later uses constrain them monomorphically.
   Use applications because Rune does not yet support ref or lists. *)
fun laterFunction () =
  let
    val id = (fn f => f) (fn x => x)
    val first = id 20
  in first + id 22 end

datatype 'a choice = Vacant | Present of 'a
fun laterDatatype () =
  let
    val empty = (fn value => value) Vacant
  in if empty = Present 0 then 0 else 42 end

val _ = print (Int.toString (laterFunction ()) ^ "\n")
val _ = print (Int.toString (laterDatatype ()) ^ "\n")
