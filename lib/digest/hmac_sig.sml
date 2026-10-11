(* HMAC (RFC 2104): a message authenticated by a key, over a hash
   function, and the comparison of two of them in a time that does not
   depend on where they differ.

   Area: Digests *)
signature HMAC =
sig
  (* The bytes of a code: the hash's digest size.

     Example: `HmacSha256.size = 32` *)
  val size : int

  (* `mac {key, message}` is the code of `message` under `key`, raw bytes.

     Example: `Hex.fromBytes (HmacSha256.mac {key = "Jefe", message = "what do ya want for nothing?"}) =
     "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"` *)
  val mac : {key : string, message : string} -> string

  (* `macParts {key, parts}` is the code of the parts joined, without
     joining them.

     Law: `macParts {key = k, parts = ps} = mac {key = k, message = String.concat ps}` *)
  val macParts : {key : string, parts : string list} -> string

  (* `equal (a, b)` is whether `a` and `b` are the same bytes, looking at
     every byte whatever it finds, so that the time it takes says nothing
     of where two codes differ.

     Example: `HmacSha256.equal ("abc", "abc") andalso not (HmacSha256.equal ("abc", "abd"))` *)
  val equal : string * string -> bool
end
