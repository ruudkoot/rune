(* requires: Bool StringCvt *)
(* uses: spec-sigs/BOOL.sml *)
(* Bool matches BOOL, and its type is the top-level one ("The bool type is
   considered primitive and is defined in the top-level environment. It is
   rebound here for consistency."). *)
structure TestBoolSig =
struct
  structure C : SPEC_BOOL = Bool
  val () = T.check ("Bool:BOOL/matches", fn () => true)
  val () = T.check ("Bool:BOOL/bool-is-toplevel", fn () => C.not (false : bool))
  val () = T.check ("Bool:BOOL/toplevel-is-bool", fn () => if (C.true : C.bool) then true else false)
  val () = T.check ("Bool:BOOL/scan-is-polymorphic-in-the-stream",
                    fn () => C.scan List.getItem [#"t", #"r", #"u", #"e"] = SOME (true, [])
                             andalso C.scan (fn i => if i < 5 then SOME (String.sub ("false", i), i + 1) else NONE) 0
                                     = SOME (false, 5))
end
