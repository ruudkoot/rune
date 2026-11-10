(* dump: --allow-prim -O2 --target=registers --dump-after=all *)
(* A suspension in Haskell's reading (docs/ir.md, Suspensions), at -O2 on
   the register target: force is one step, the primitive thunk_force,
   after every pass of Mid and in Low, where the suspension's code reads
   what it captured, n, at its entry, before it says thunk_blackhole (of no
   operand: Low.hoistEnv, Lower); the register code makes the force
   FORCE, then UNIT, ENTER and RESULT, the code BLACKHOLE and UPDATE, and
   thunk_make a PRIM. *)
val k = (_prim "ref_new" : int -> int ref) 41
val get = _prim "ref_get" : int ref -> int
val add = _prim "int_add" : int * int -> int
fun mk (n : int) =
  (_prim "thunk_make" : (unit -> int) -> int _prim "susp") (fn () =>
    let val () = (_prim "thunk_blackhole" : unit -> unit) ()
        val v = add (get k, n)
        val () = (_prim "thunk_self_update" : int -> unit) v
    in v end)
val t = mk (get k)
val u = add ((_prim "thunk_force" : int _prim "susp" -> int) t, 1)
