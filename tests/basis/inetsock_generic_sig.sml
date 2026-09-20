(* requires: GenericSock Socket *)
(* uses: spec-sigs/GENERIC_SOCK.sml *)
(* GenericSock matches GENERIC_SOCK. *)
structure TestGenericSockSig =
struct
  structure C : SPEC_GENERIC_SOCK = GenericSock
  val () = T.check ("GenericSock:GENERIC_SOCK/matches", fn () => true)
end
