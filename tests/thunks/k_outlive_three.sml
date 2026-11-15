(* Three runs of one suspension, a collection between each update: each
   outer run's value stands in its turn, the outermost's at the end, and the
   frames' indirection is written twice (D57, M26; E14).
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
    val c = ref (NONE : int list L.susp option)
    val r = ref 0
    val seen = ref ([] : int list list)
    val _ = spin 100
    (* the body in the suspension's own code, as in k_outlive *)
    val t =
      L.make (fn () =>
        let
          val v =
            (r := !r + 1;
             let val me = !r in
               if me < 3 then
                 let val inner = L.force (valOf (!c))
                     val _ = seen := inner :: !seen
                     val _ = spin 50
                     val now = L.force (valOf (!c))
                     val _ = seen := now :: !seen
                 in me * 10 :: inner end
               else [k]
             end)
          val () = L.update v
        in v end)
    val _ = c := SOME t
    val a = L.force t
    val _ = spin 100
    val _ = List.app (fn l => print (showl l ^ "\n")) (rev (!seen))
  in print (showl a ^ " / " ^ showl (L.force t) ^ " / " ^ Int.toString (!r) ^ "\n") end
val _ = run 9
