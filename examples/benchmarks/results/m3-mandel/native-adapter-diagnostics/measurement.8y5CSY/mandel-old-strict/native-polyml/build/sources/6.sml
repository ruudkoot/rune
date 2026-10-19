functor BenchMandelDriverFn (K : sig
  type pixels
  val make : real * real * real * real -> IntInf.int -> IntInf.int -> int -> pixels BenchMandelDouble.pixmap
  val app : (int * int * int -> unit) -> pixels -> unit
end) =
struct
  val _ = if Real.radix = 2 andalso Real.precision = 53 then ()
          else raise Fail "benchmark requires binary64 Real"
  structure Check = MandelDigestFn (K)
  fun real text = case Real.scan Substring.getc (Substring.full text) of
      SOME (value, rest) => if Substring.isEmpty rest andalso Real.isFinite value then value
                           else raise Fail "invalid Mandel real argument"
    | NONE => raise Fail "invalid Mandel real argument"
  fun line input = case TextIO.inputLine input of SOME s => s | NONE => raise Fail "short Mandel parameter file"
  fun run [parameters, reference] =
    let val input = TextIO.openIn parameters
        fun integerLine () = case String.tokens Char.isSpace (line input) of
            [s] => BenchInput.integer s | _ => raise Fail "invalid Mandel repetition count"
        fun main () =
          let val repeats = BenchInput.between (1, 100) (integerLine ())
              fun once () = case String.tokens Char.isSpace (line input) of
                  [x, y, a, b, w, h, cap] =>
                    let val minX = real x val minY = real y val maxX = real a val maxY = real b
                        val _ = if minX >= ~2.0 andalso minY >= ~2.0 andalso maxX <= 2.0 andalso maxY <= 2.0
                                   andalso minX < maxX andalso minY < maxY then () else raise Fail "Mandel viewport out of range"
                        val width = BenchInput.between (1, 180) (BenchInput.integer w)
                        val height = BenchInput.between (1, 180) (BenchInput.integer h)
                        val limit = BenchInput.between (0, 75) (BenchInput.integer cap)
                    in Check.run (minX, minY, maxX, maxY) width height limit reference end
                | _ => raise Fail "invalid Mandel parameter row"
              fun loop 0 = () | loop n = (once (); loop (n - 1))
              val _ = loop repeats
              val _ = case TextIO.inputLine input of NONE => () | SOME _ => raise Fail "extra Mandel parameter row"
          in Int.toString repeats ^ ":checked" end
        val result = main () handle ex => (TextIO.closeIn input; raise ex)
        val _ = TextIO.closeIn input
    in result end
    | run _ = raise Fail "Mandel expects parameter file and reviewed digest"
end
