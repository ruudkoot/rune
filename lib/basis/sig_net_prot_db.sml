(* The protocol database: turning the name of a network protocol into its
   number, and back.

   This is what the system knows from `/etc/protocols`: that `"tcp"` is 6 and
   `"udp"` is 17. The numbers are the ones `Socket`'s `socket'` functions
   take.

   Area: The operating system

   Status: optional

   See also: `SOCKET`, `NET_SERV_DB`, `NET_HOST_DB`, `GENERIC_SOCK` *)
signature NET_PROT_DB =
sig
  (* The type of what the database records about one protocol. *)
  type entry

  (* `name e` is the official name of the protocol. *)
  val name : entry -> string

  (* `aliases e` is the other names it goes by. *)
  val aliases : entry -> string list

  (* `protocol e` is the number of the protocol.

     Example: `Option.map protocol (getByName "tcp")` is `SOME 6` where
     `/etc/protocols` lists TCP. *)
  val protocol : entry -> int

  (* `getByName name` is `SOME` of what the database records about the protocol `name`, or `NONE`. *)
  val getByName : string -> entry option

  (* `getByNumber n` is `SOME` of what it records about the protocol numbered `n`, or `NONE`.

     Example: `isSome (getByNumber ~1) = false`, for no protocol has that
     number. *)
  val getByNumber : int -> entry option
end
