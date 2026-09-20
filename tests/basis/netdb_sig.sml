(* requires: NetHostDB NetProtDB NetServDB *)
(* uses: spec-sigs/NET_HOST_DB.sml spec-sigs/NET_PROT_DB.sml spec-sigs/NET_SERV_DB.sml *)
(* NetHostDB matches NET_HOST_DB, NetProtDB NET_PROT_DB and NetServDB
   NET_SERV_DB. *)
structure TestNetDBSig =
struct
  (*<< host *)
  structure H : SPEC_NET_HOST_DB = NetHostDB
  val () = T.check ("NetHostDB:NET_HOST_DB/matches", fn () => true)
  val () = T.check ("NetHostDB:NET_HOST_DB/in_addr-is-an-eqtype",
                    fn () => H.fromString "127.0.0.1" = NetHostDB.fromString "127.0.0.1")
  (*>> host *)

  (*<< prot *)
  structure P : SPEC_NET_PROT_DB = NetProtDB
  val () = T.check ("NetProtDB:NET_PROT_DB/matches", fn () => true)
  (*>> prot *)

  (*<< serv *)
  structure S : SPEC_NET_SERV_DB = NetServDB
  val () = T.check ("NetServDB:NET_SERV_DB/matches", fn () => true)
  (*>> serv *)
end
