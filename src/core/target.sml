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
    maxArgs : int,          (* the most arguments a known call may pass (M8) *)
    switch : bool,          (* whether it has a jump table on a tag (M9) *)
    barriers : bool,        (* whether a store into the heap needs a barrier *)
    safepoints : bool       (* whether a loop without calls needs a safepoint *)
  }

  (* The precision of int and word on the VM the program is compiled for,
     which folding a constant needs: 63, the VM's immediate
     (docs/plans/heap-layout.md, D2 B), or 64 for a VM built with
     -DRUNE_INT64 (D2 A), which --int-bits=64 says. *)
  val intBits : int ref = ref 63

  (* runevm-stack's bytecode: known calls of up to 64 arguments (CALLK), no
     switch yet, and a collector that needs neither barriers nor
     safepoints. *)
  val stack : t = {name = "stack", machine = Stack, maxArgs = 64, switch = false,
                   barriers = false, safepoints = false}
end
