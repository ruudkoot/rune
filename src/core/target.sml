(* What the middle end asks of a target (docs/plans/middle-end.md, the
   target record): the passes read this record rather than assume the
   stack bytecode, so that the register target (M5) and later VMs can say
   otherwise. *)
structure Target =
struct
  datatype machine = Stack | Registers

  type t = {
    name : string,
    machine : machine,
    intBits : int,          (* the precision of int, which folding a constant needs *)
    maxArgs : int,          (* the most arguments a known call may pass (M8) *)
    switch : bool,          (* whether it has a jump table on a tag (M9) *)
    barriers : bool,        (* whether a store into the heap needs a barrier *)
    safepoints : bool       (* whether a loop without calls needs a safepoint *)
  }

  (* runevm's bytecode: 64-bit int, unary calls, no switch yet, and a
     collector that needs neither barriers nor safepoints. *)
  val stack : t = {name = "stack", machine = Stack, intBits = 64, maxArgs = 1, switch = false,
                   barriers = false, safepoints = false}
end
