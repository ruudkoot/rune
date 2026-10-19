functor MandelDigestFn (K : sig
  type pixels
  val make : real * real * real * real -> IntInf.int -> IntInf.int -> int -> pixels BenchMandelDouble.pixmap
  val app : (int * int * int -> unit) -> pixels -> unit
end) =
struct
  structure W = Word64
  fun run viewport width height limit path =
    let val picture = K.make viewport (IntInf.fromInt width) (IntInf.fromInt height) limit
        val BenchMandelDouble.Pixmap (w, h, cap, pixels) = picture
        val hash : W.word ref = ref 0w1013904223 val count = ref 0
        fun mix value = hash := W.+ (W.* (!hash, 0w1664525), W.fromInt value)
        fun use (r, g, b) =
          if r < 0 orelse r > cap orelse g < 0 orelse g > cap orelse b < 0 orelse b > cap
          then raise Fail "incorrect result: Mandel colour out of range"
          else (mix r; mix g; mix b; count := !count + 1)
        val _ = K.app use pixels
        val observed = String.concat [IntInf.toString w, " ", IntInf.toString h, " ",
          Int.toString cap, " ", Int.toString (!count), " ", W.toString (!hash), "\n"]
        val input = TextIO.openIn path
        val expected = TextIO.inputLine input
        val extra = TextIO.inputLine input val _ = TextIO.closeIn input
    in if expected = SOME observed andalso not (Option.isSome extra) then ()
       else raise Fail "incorrect result: Mandel metadata, count or digest differs" end
end
