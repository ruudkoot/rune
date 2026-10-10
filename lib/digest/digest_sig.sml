(* A hash function that reads its message in pieces: the context holds
   what it has read, and `finish` gives the digest, as raw bytes.

   Area: Digests *)
signature DIGEST =
sig
  (* The function's name, as its standard writes it.

     Example: `Sha256.name = "SHA-256"` *)
  val name : string

  (* The bytes of a digest.

     Example: `Sha256.size = 32` *)
  val size : int

  (* The bytes of a block, what HMAC pads its key to.

     Example: `Sha256.blockSize = 64` *)
  val blockSize : int

  (* What has been read of a message. *)
  type context

  (* The context that has read nothing. *)
  val empty : context

  (* `update (c, s)` is `c` having read `s` after what it had read. *)
  val update : context * string -> context

  (* `finish c` is the digest of what `c` has read.

     Law: `finish (update (update (empty, a), b)) = digest (a ^ b)` *)
  val finish : context -> string

  (* `digest s` is the digest of `s`.

     Example: `Hex.fromBytes (Sha256.digest "abc") =
     "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"` *)
  val digest : string -> string
end
