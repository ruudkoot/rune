(* A suspension that a function returns inside a datatype, which Lower
   returns in globals (results; docs/ir.md, The optimisations of Mid): the
   variable read back from the global is of no one representation, so a
   force of it stays a force (Lower's rule for a force of what is known to
   be no suspension asks a representation that is not any). args: n
   The suspension is Haskell's (docs/ir.md, Suspensions);
   tests/runner/thunks.sml runs it on every engine. *)
structure D =
struct
  type 'a susp = 'a _prim "susp"
  val make = _prim "thunk_make" : (unit -> 'a) -> 'a susp
  val force = _prim "thunk_force" : 'a susp -> 'a
  val blackhole = _prim "thunk_blackhole" : unit -> unit
  val update = _prim "thunk_self_update" : 'a -> unit
  fun delay f = make (fn () => let val () = blackhole () val v = f () val () = update v in v end)
end
val n = valOf (Int.fromString (hd (CommandLine.arguments ())))
(* recursive, so that Simplify does not inline them *)
fun pick (k, s) = if k > 100 then pick (k - 100, s) else if k > 0 then SOME s else NONE
fun pair (k, s) = if k > 100 then pair (k - 100, s) else if k > 0 then SOME (s, k) else NONE
val t = D.delay (fn () => n * 6)
fun go (0, acc) = acc
  | go (k, acc) =
      let
        val a = case pick (k, t) of SOME s => D.force s | NONE => 0
        val b = case pair (k, D.delay (fn () => k)) of SOME (s, j) => D.force s + j | NONE => 0
      in go (k - 1, acc + a + b) end
val () = print ("results " ^ Int.toString (go (n, 0)) ^ "\n")
