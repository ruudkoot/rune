(* The service database: turning the name of a network service into its port,
   and back.

   This is what the system knows from `/etc/services`: that `"http"` over
   `"tcp"` is port 80. A name may be listed for more than one protocol, so
   the lookups take an optional protocol to narrow the search; `NONE` takes
   whichever entry comes first.

   Area: The operating system

   Status: optional

   See also: `SOCKET`, `NET_PROT_DB`, `NET_HOST_DB`, `INET_SOCK` *)
signature NET_SERV_DB =
sig
  (* The type of what the database records about one service. *)
  type entry

  (* `name e` is the official name of the service. *)
  val name : entry -> string

  (* `aliases e` is the other names it goes by. *)
  val aliases : entry -> string list

  (* `port e` is the port the service is reached at. *)
  val port : entry -> int

  (* `protocol e` is the name of the protocol it is reached over. *)
  val protocol : entry -> string

  (* `getByName (name, proto)` is `SOME` of what the database records about the service `name`, or `NONE`.

     `proto` narrows the search to one protocol; `NONE` takes the first
     entry for `name`. *)
  val getByName : string * string option -> entry option

  (* `getByPort (port, proto)` is `SOME` of what it records about the service at `port`, or `NONE`. *)
  val getByPort : int * string option -> entry option
end
