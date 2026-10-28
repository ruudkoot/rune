(* Observe the clock calls of the real Pass implementation. The two
   compiler services are irrelevant to this isolated stage contract. *)
structure CompilerState = struct fun cellRoot _ = () end
structure Error = struct exception Bug of string end
structure PassClock =
struct
  val reads = ref 0
  val sizes = ref 0
  val checks = ref 0
end
structure OriginalTimer = Timer
structure Timer =
struct
  val totalCPUTimer = OriginalTimer.totalCPUTimer
  fun checkCPUTimer timer =
    (PassClock.reads := !PassClock.reads + 1; OriginalTimer.checkCPUTimer timer)
end
