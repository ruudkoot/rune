(* k_outlive where the value is a nullary constructor, immediate, so a
   frame's closure slot given what the indirection holds would hold no
   pointer (D57, M26; E14's outlive_nullary, of datatype lazy color).
   tests/runner/thunks.sml runs it on every engine. *)
structure L =
struct
  type 'a susp = 'a _prim "susp"
  val make = _prim "thunk_make" : (unit -> 'a) -> 'a susp
  val force = _prim "thunk_force" : 'a susp -> 'a
  val update = _prim "thunk_self_update" : 'a -> unit
  fun delay f = make (fn () => let val v = f () val () = update v in v end)
end
fun churn 0 acc = acc
  | churn n acc = churn (n - 1) (n :: acc)
fun spin n = let fun go (0, s) = s | go (i, s) = go (i - 1, s + length (churn 3000 [])) in go (n, 0) end
datatype color = Red | Green
fun name Red = "red" | name Green = "green"
fun run () =
  let
    val c = ref (NONE : color L.susp option)
    val r = ref 0
    val _ = spin 100
    val t =
      L.delay (fn () =>
        (r := !r + 1;
         if !r = 1 then
           let val inner = name (L.force (valOf (!c)))
               val _ = spin 50
           in print (inner ^ "\n"); Green end
         else Red))
    val _ = c := SOME t
    val a = name (L.force t)
    val _ = spin 100
  in print (a ^ " / " ^ name (L.force t) ^ " / " ^ Int.toString (!r) ^ "\n") end
val _ = run ()
