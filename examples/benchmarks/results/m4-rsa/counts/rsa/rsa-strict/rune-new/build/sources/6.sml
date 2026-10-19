functor BenchRsaDriverFn (C : sig val encrypt : string -> string end) =
struct
  fun file path =
    let val stream = BinIO.openIn path
        val bytes = BinIO.inputAll stream
        val _ = BinIO.closeIn stream
    in Byte.bytesToString bytes end
  fun run [path,iterations,reference] =
    let
      val repetitions = BenchInput.between (1,250) (BenchInput.integer iterations)
      val expected = file reference
      (* Portable observable input acquisition replaces nofib's NOINLINE IO salt.
         Repeated file reads are an explicit added adapter cost. *)
      fun loop 0 total = IntInf.toString total
        | loop left total =
            let val input = file path
                val ciphertext = C.encrypt input
                val _ = if ciphertext=expected then () else raise Fail "RSA ciphertext differs"
                val hash = Word64.toLargeIntX(BenchNofibHash.hash ciphertext)
            in loop(left-1)(IntInf.+(total,hash)) end
    in loop repetitions 0 end
    | run _ = raise Fail "rsa expects input repetitions ciphertext-reference"
end
