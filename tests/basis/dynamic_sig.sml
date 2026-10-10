(* requires: Dynamic *)
(* Dynamic matches DYNAMIC, which is Rune's own signature: an exception and
   a function, nothing abstract. *)
structure TestDynamicSig =
struct
  val () = T.check ("Dynamic:DYNAMIC/an-exception-and-a-function",
                    fn () =>
                      let
                        val l : string -> unit = Dynamic.load
                        val m : string -> exn = Dynamic.Mismatch
                      in (ignore (l, m); true) end)
end
