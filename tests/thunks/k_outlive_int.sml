(* k_outlive with an int: the inner run's value is immediate, so a frame's
   closure slot given what the indirection holds would hold no pointer
   (D57, M26; E14). tests/runner/thunks.sml runs it on every engine. *)
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
fun run k =
  let
    val c1 = ref (NONE : int L.susp option)
    val r1 = ref 0
    val _ = spin 100
    val t1 =
      L.delay (fn () =>
        (r1 := !r1 + 1;
         if !r1 = 1 then
           let val inner = L.force (valOf (!c1))
               val _ = spin 50
           in 100 + inner end
         else k))
    val _ = c1 := SOME t1
    val a1 = L.force t1
    val _ = spin 100
    val b1 = L.force t1
  in print (Int.toString a1 ^ " / " ^ Int.toString b1 ^ " / " ^ Int.toString (!r1) ^ "\n") end
val _ = run 9
val _ = run 10
