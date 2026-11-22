(* dump: --allow-prim -O0 --dump-after=all *)
(* The suspension of susp.sml at -O0 on the stack target: force is the one
   step thunk_force in Mid and Low, where the suspension's code reads what
   it captured at its entry (Low.hoistEnv); the stack code keeps it in a
   local, not read again from the closure after BLACKHOLE (Stack.remat),
   and makes the force FORCE, then UNIT and ENTER, the code BLACKHOLE and
   UPDATE, and thunk_make a PRIM. *)
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
