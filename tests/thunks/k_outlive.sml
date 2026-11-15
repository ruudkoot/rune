(* A body that outlives its own update, in lazy ML's reading (docs/ir.md,
   Suspensions; the haskell98 roadmap's D57, M26; E14's k_outlive): the
   suspension does not go under evaluation, so the outer run forces it from
   inside, the inner run updates it to V, a list the program holds by
   itself, and the outer run goes on -- its frame's closure an indirection
   through collections -- and updates it again. The rules: the suspension
   holds the outer's value, and V is what it was. The body is the
   suspension's own code, which reads what it captured at its entry.
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
fun showl l = String.concatWith "," (List.map Int.toString l)
fun run k =
  let
    val c1 = ref (NONE : int list L.susp option)
    val r1 = ref 0
    val _ = spin 100
    (* young where the suspension is made, so that a collection moves it
       before the outer run reads it *)
    val keep = ref ([] : int list)
    (* the body in the suspension's own code, so that it reads what it
       captured from the closure: at its entry (Low.hoistEnv), not after the
       inner run made the closure an indirection *)
    val t1 =
      L.make (fn () =>
        let
          val v =
            (r1 := !r1 + 1;
             if !r1 = 1 then
               let val inner = L.force (valOf (!c1))
                   val _ = spin 50
                   val () = keep := inner
                   val _ = spin 50
               in 100 :: inner end
             else [7, 8, k])
          val () = L.update v
        in v end)
    val _ = c1 := SOME t1
    val a1 = L.force t1
    val _ = spin 100
    val _ = print (showl (!keep) ^ "\n")
    val b1 = L.force t1
  in print (showl a1 ^ " / " ^ showl b1 ^ " / " ^ showl (!keep) ^ " / " ^ Int.toString (!r1) ^ "\n") end
val _ = run 9
val _ = run 10
