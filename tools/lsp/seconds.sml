(* A time in seconds as a JSON number, for the tools that write what they
   measured (the oracle, the replay, the planning bench, the contexts tool).
   Real.toString writes 0.003 as 3E~3, and a negative time (the wall clock
   stepped back under the interval) with ~; JSON has neither, and Json.write
   refuses both with Domain. Fixed, to the microsecond, with a minus sign. *)
structure RuneLspSeconds =
struct
  fun json (seconds : real) : Json.value =
    Json.Number (String.map (fn #"~" => #"-" | c => c) (Real.fmt (StringCvt.FIX (SOME 6)) seconds))
end
