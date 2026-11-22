(* A value cast into a suspension and forced in a suspension's code
   (D4, D5; docs/ir.md, Suspensions), which B's Core met (the haskell98
   roadmap's M10, impl/b/defects/force-of-cast-in-thunk): g casts what the
   suspension's code captured, an evaluated int, where the code forces it,
   so that Lower gives the captured value its type's representation and
   the force is the value itself; h casts it outside, so that the code
   forces a value the closure's slot holds as an int, a FORCE that jumps
   on, which RegVerify takes for a test: ENTER only where it is a pointer.
   args: n. The suspension is Haskell's; tests/runner/thunks.sml runs it
   at every level, on both bytecodes and every engine and tier, with the
   lint. *)
structure D =
struct
  type 'a susp = 'a _prim "susp"
  val make = _prim "thunk_make" : (unit -> 'a) -> 'a susp
  val force = _prim "thunk_force" : 'a susp -> 'a
  val blackhole = _prim "thunk_blackhole" : unit -> unit
  val update = _prim "thunk_self_update" : 'a -> unit
  fun delay f = make (fn () => let val () = blackhole () val v = f () val () = update v in v end)
end
val toSusp = _prim "unsafe_cast" : int -> int D.susp
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
(* B's program: toChar, which the simplifier inlines into c, which stays a
   suspension since a and b read it *)
fun toChar i = let val k = D.force (toSusp i) in if k < 0 orelse k > 1114111 then raise Chr else k end
fun g i =
  let
    val c = D.delay (fn () => toChar i)
    val a = D.delay (fn () => D.force c)
    val b = D.delay (fn () => D.force c)
  in D.force a + D.force b end
fun h i =
  let
    val s = toSusp i
    val c = D.delay (fn () => D.force s + 1)
    val a = D.delay (fn () => D.force c)
    val b = D.delay (fn () => D.force c)
  in D.force a + D.force b end
val () = print ("castin " ^ Int.toString (g n) ^ " " ^ Int.toString (h n) ^ "\n")
