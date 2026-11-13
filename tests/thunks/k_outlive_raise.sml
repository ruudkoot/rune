(* k_outlive where the outer run raises after the inner run updated: the
   failed evaluation leaves the suspension as it was, so the inner's value
   stands (D57, M26; E14's rule L5). tests/runner/thunks.sml runs it on
   every engine. *)
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
fun showl l = String.concatWith "," (List.map Int.toString l)
fun run k =
  let
    val c = ref (NONE : int list L.susp option)
    val r = ref 0
    val _ = spin 100
    val t =
      L.delay (fn () =>
        (r := !r + 1;
         if !r = 1 then
           let val inner = L.force (valOf (!c))
               val _ = spin 50
           in raise Fail (showl inner) end
         else [k, !r]))
    val _ = c := SOME t
    val a = L.force t handle Fail m => (print ("raised " ^ m ^ "\n"); [])
    val _ = spin 100
  in print (showl a ^ " / " ^ showl (L.force t) ^ " / " ^ Int.toString (!r) ^ "\n") end
val _ = run 9
val _ = run 10
