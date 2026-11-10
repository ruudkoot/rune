(* What a compiler that forgot a force would make (D5, D11): a suspension
   where its type says a list, or a function, and one of its own type, a
   suspension, read as a ref. The interpreter and tier 1 test every value
   and stop; tier 2 trusts a register's representation, so it stops for the
   suspension, whose representation is any, and not for the list or the
   function, whose are con and ptr. Each primitive's type at its use is no
   instance of its description, which MidLint refuses: compiled without
   --lint. args: list|fun|susp n
   The suspension is Haskell's (docs/ir.md, Suspensions): its code says
   BLACKHOLE once it has read what it captured, and UPDATE with its value.
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
val mkList = _prim "thunk_make" : (unit -> int list) -> int list
val mkFun = _prim "thunk_make" : (unit -> int) -> (unit -> int)
val mkSusp = _prim "thunk_make" : (unit -> int) -> int D.susp
val getSusp = _prim "ref_get" : int D.susp -> int
fun headOf (l : int list) = case l of x :: _ => x | [] => ~1
fun callOf (f : unit -> int) = f ()
val (mode, n) = case CommandLine.arguments () of [m, ns] => (m, valOf (Int.fromString ns)) | _ => raise Fail "args"
fun drive f k acc = if k = 0 then acc else drive f (k - 1) ((acc + f k) mod 1000003)
val free = ref 7
val r =
  case mode of
    "list" => drive (fn i => let val c = !free + i in headOf (mkList (fn () => [c])) end) n 0
  | "fun" => drive (fn i => let val c = !free + i in callOf (mkFun (fn () => c)) end) n 0
  | "susp" => drive (fn i => let val c = !free + i in getSusp (mkSusp (fn () => c)) end) n 0
  | _ => raise Fail "mode"
val () = print ("wrongslot " ^ mode ^ " " ^ Int.toString r ^ "\n")
