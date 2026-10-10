(* ZMTP 3.1's bytes (rfc.zeromq.org/spec/37): the greeting, frames and
   commands, and the metadata of READY.

   A connection begins with a greeting of 64 bytes from each side, then
   the handshake of the security mechanism -- for NULL, a READY command
   each way, with the socket's type and identity -- and then frames: a
   message is one or more data frames, all but the last flagged MORE.

   Area: Networking *)
signature ZMTP_WIRE =
sig
  (* `greeting {mechanism, server}` is the 64 bytes that begin a
     connection.

     They say ZMTP 3.1, the mechanism's name, and whether this side is the
     server of the mechanism (NULL has none).

     Example: `size (greeting {mechanism = "NULL", server = false}) = 64` *)
  val greeting : {mechanism : string, server : bool} -> string

  (* What a peer's greeting says. *)
  type peer = {major : int, minor : int, mechanism : string, server : bool}

  (* `readGreeting s` is what the greeting `s`, 64 bytes, says, or `NONE`
     when it is not one: its signature wrong, or a version before 3.

     Example: `readGreeting (greeting {mechanism = "NULL", server = true})
     = SOME {major = 3, minor = 1, mechanism = "NULL", server = true}` *)
  val readGreeting : string -> peer option

  (* A frame: data, and whether more of the message follows, or a
     command, its name and its data. *)
  datatype frame = Data of {more : bool, body : string} | Command of {name : string, data : string}

  (* `encode f` is the bytes of `f`: its flags, its size in one byte or
     eight, and its body.

     Example: `encode (Data {more = true, body = "ab"}) = "\001\002ab"` *)
  val encode : frame -> string

  (* `message parts` is the frames of a message of those parts.

     Example: `message ["a", "b"] = "\001\001a\000\001b"` *)
  val message : string list -> string

  (* What `feed` raises for bytes that are no frame: a size past what a
     string holds, or a command whose name runs past its body. *)
  exception Malformed of string

  (* A reader of frames: the bytes of a frame begun and not yet complete. *)
  type reader

  (* The reader that has read nothing. *)
  val reader : reader

  (* `feed (r, s)` is the frames that `r`'s bytes and `s` complete, and the
     reader that holds the rest.

     Raises: `Malformed` for bytes that are no frame. *)
  val feed : reader * string -> frame list * reader

  (* `ready props` is NULL's READY command with the metadata `props`,
     such as `("Socket-Type", "ROUTER")`. *)
  val ready : (string * string) list -> frame

  (* `properties d` is the metadata of a READY command's data.

     Raises: `Malformed` when `d` is not metadata.

     Example: `properties (case ready [("Socket-Type", "REQ")] of Command {data, ...} => data | _ => "")
     = [("Socket-Type", "REQ")]` *)
  val properties : string -> (string * string) list
end
