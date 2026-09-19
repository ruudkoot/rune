(* signature INET_SOCK, transcribed from
   https://smlfamily.github.io/Basis/inet-sock.html

   The substructures UDP and TCP are specified in place, as the page has
   them. Socket and NetHostDB are the top-level structures. *)
signature SPEC_INET_SOCK =
sig
  type inet
  type 'sock_type sock = (inet, 'sock_type) Socket.sock
  type 'mode stream_sock = 'mode Socket.stream sock
  type dgram_sock = Socket.dgram sock
  type sock_addr = inet Socket.sock_addr

  val inetAF : Socket.AF.addr_family

  val toAddr : NetHostDB.in_addr * int -> sock_addr
  val fromAddr : sock_addr -> NetHostDB.in_addr * int
  val any : int -> sock_addr

  structure UDP :
  sig
    val socket : unit -> dgram_sock
    val socket' : int -> dgram_sock
  end

  structure TCP :
  sig
    val socket : unit -> 'mode stream_sock
    val socket' : int -> 'mode stream_sock
    val getNODELAY : 'mode stream_sock -> bool
    val setNODELAY : 'mode stream_sock * bool -> unit
  end
end
