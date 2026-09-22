(* What a program sees of the structures of netdb.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
(* the entries are abstract: no other signature names them *)
structure NetHostDB :> NET_HOST_DB where type in_addr = NetHostDB.in_addr where type addr_family = NetHostDB.addr_family = NetHostDB
structure NetProtDB :> NET_PROT_DB = NetProtDB
structure NetServDB :> NET_SERV_DB = NetServDB
