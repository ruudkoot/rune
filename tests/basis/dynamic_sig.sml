(* requires: Dynamic *)
(* Dynamic matches DYNAMIC, which is Rune's own signature: an exception and
   two functions, nothing abstract. *)
structure TestDynamicSig =
struct
  val () = T.check ("Dynamic:DYNAMIC/an-exception-and-two-functions",
                    fn () =>
                      let
                        val l : string -> unit = Dynamic.load
                        val r : string -> unit = Dynamic.reload
                        val m : string -> exn = Dynamic.Mismatch
                      in (ignore (l, r, m); true) end)
end
