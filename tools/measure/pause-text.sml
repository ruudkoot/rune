(* Versioned simulator-pause report wording. *)
structure MeasurePauseText =
struct
  val head = "| config | pauses | GC ms | GC share | longest ms | p99 ms | MMU 1ms | 10ms | 50ms | 100ms |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
  val intro = "Made by `tools/heapsim/pauses.py %s` from gcsim's `--events` (`tools/heapsim/sweep2.sh`, question events). Each collection costs timeline.py's linear model: the unit costs tests/gcbench measured (the roadmap's *The harness*: H2 copy and mark, H8 stack slots and frames, H10 sequential reads) where they apply; still PLACEHOLDERS: %s. The mutator's time is the bytecode instruction clock at %.1f ns/instruction (default tier) and %.1f (interpreter), from the bootstrap's baseline. Collections at the same allocation clock are one pause; sweeping in the pause (no --lazy-sweep); minors scan the whole stack (no --watermark). MMU after Cheng and Blelloch (2001). The fixed costs being placeholders, compare configurations more than milliseconds.\n"
  val calibration = "\nThe stock copier, measured (runevm --jit=off --gc-log, pause_ns) against the model at the same heap (measured where validate2.sh ran, which is not an idle machine); the mutator at the interpreter's placeholder %.1f ns/instruction for both:\n\n%s"
end
