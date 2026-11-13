(* A suspension of a suspension, in lazy ML's reading ('a susp susp, which
   Haskell cannot make): forcing the outer must not run the inner, before or
   after a collection, so the collector gives no field an indirection's
   value where that is a suspension or an indirection (ind_may_shortcut;
   D57, M26; E2's kernels/nested.sml, E14's k_nested).
   tests/runner/thunks.sml runs it on every engine. *)
structure L =
struct
  type 'a susp = 'a _prim "susp"
  val make = _prim "thunk_make" : (unit -> 'a) -> 'a susp
  val force = _prim "thunk_force" : 'a susp -> 'a
  val update = _prim "thunk_self_update" : 'a -> unit
  fun delay f = make (fn () => let val v = f () val () = update v in v end)
end
fun say s = print (s ^ "\n")
fun churn 0 acc = acc | churn n acc = churn (n - 1) (n :: acc)
fun spin () = let fun go (0, s) = s | go (i, s) = go (i - 1, s + length (churn 3000 [])) in go (400, 0) end
val inner = L.delay (fn () => (say "inner ran"; 1))
val outer = L.delay (fn () => (say "outer ran"; inner))
val keep = ref [outer]
val i0 = L.force (hd (!keep))
val () = say "outer forced"
val _ = spin ()
val i1 = L.force (hd (!keep))
val () = say "outer forced again"
val v = L.force i1
val () = say ("value " ^ Int.toString v)
val _ = spin ()
val v2 = L.force (L.force (hd (!keep)))
val () = say ("value " ^ Int.toString v2)
(* three levels, the middle one evaluated, the innermost not *)
val c = L.delay (fn () => (say "c ran"; 3))
val b = L.delay (fn () => (say "b ran"; c))
val a = L.delay (fn () => (say "a ran"; b))
val aa = ref [a]
val _ = L.force (L.force (hd (!aa)))
val () = say "two forced"
val _ = spin ()
val _ = L.force (L.force (hd (!aa)))
val () = say "two forced again"
val w = L.force (L.force (L.force (hd (!aa))))
val () = say ("value " ^ Int.toString w)
(* two levels forced at once, twice *)
val p = L.delay (fn () => L.delay (fn () => (say "p ran"; 9)))
val q = L.force (L.force p)
val r = L.force (L.force p)
val () = say (Int.toString (q + r))
