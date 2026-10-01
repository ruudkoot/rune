(* MLton b15e2d289c3d701131733665a74e2dd8438410b6, source and changes in PROVENANCE.md.
   Copyright and permission notice retained in LICENSE. *)
structure Benchmark =
struct
  val name = "checksum"
  (* Author: sweeks@sweeks.com
   * This code is based on the following paper.
   * The Performance of FoxNet 2.0
   * Herb Derby
   * CMU-CS-99-137
   * June 1999
   *)

  fun checkOne (new, ac) =
     let open Word32
     in ac + >> (new, 0w16) + andb (new, 0wxFFFF)
     end

  fun fold f b (buf, first, last) =
     let
        fun loop (i, ac) =
           if i > last
              then ac
           else loop (i + 1,
                      f (Word32.fromLarge (PackWord32Little.subArr (buf, i)),
                         ac))
     in
        loop (first, b)
     end

  fun checksum buf = fold checkOne 0w0 buf

  fun run [size, reps] =
        let val n = BenchInput.between (1, 10000000) (BenchInput.integer size)
            val count = BenchInput.between (1, 1000) (BenchInput.integer reps)
            val _ = if n mod 4 = 0 then () else raise Fail "buffer length must be divisible by four"
            val buffer = Word8Array.array (n, 0w0)
            fun loop (0, sum) = sum
              | loop (k, sum) = loop (k - 1, Word32.+ (sum, checksum (buffer, 0, n div 4 - 1)))
        in Word32.toString (loop (count, 0w0)) end
    | run _ = raise Fail "checksum expects bytes repetitions"
end
