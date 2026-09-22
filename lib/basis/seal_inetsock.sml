(* What a program sees of the structures of inetsock.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure GenericSock : GENERIC_SOCK = GenericSock
structure INetSock : INET_SOCK = INetSock
structure UnixSock : UNIX_SOCK = UnixSock
