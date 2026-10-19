structure MandelFloatTests =
struct
  structure W = Word32
  structure P = BenchMandelTwoPoint
  fun decode text =
    let val bits = valOf (W.fromString text)
        val sign = W.andb (bits, 0wx80000000) <> 0w0
        val exponent = W.toInt (W.andb (W.>> (bits, 0w23), 0w255))
        val mantissa = W.toInt (W.andb (bits, 0wx7fffff))
        val _ = if exponent = 255 then raise Domain else ()
        val value = if exponent = 0 then Real.fromManExp {man = Real.fromInt mantissa, exp = ~149}
          else Real.fromManExp {man = Real.fromInt (8388608 + mantissa), exp = exponent - 150}
    in if sign then ~value else value end
  fun same (value, text) =
    let val expected = decode text
    in Real.== (value, expected) andalso Real.signBit value = Real.signBit expected end
  val current = ref (0.0, 0.0, 0.0, 0.0)
  val label = ref ""
  fun number text = valOf (Int.fromString text)
  fun row text = case String.tokens Char.isSpace text of
      ["point", x, y, p, q, colour] =>
        let val a = P.p (number x) val b = P.q (number y)
            val _ = label := x ^ "," ^ y
            val _ = current := (a, b, 0.0, 0.0)
        in T.check ("mandel2/coordinates-" ^ !label, fn () => same (a, p) andalso same (b, q));
           T.check ("mandel2/point-colour-" ^ !label, fn () => P.colour (number x, number y) = number colour) end
    | ["step", k, x, y, radius] =>
        let val (p, q, a, b) = !current val (nx, ny, r) = P.next (p, q, a, b)
            val _ = current := (p, q, nx, ny)
        in T.check ("mandel2/binary32-orbit-" ^ !label ^ "-" ^ k,
             fn () => same (nx, x) andalso same (ny, y) andalso same (r, radius)) end
    | _ => raise Fail "invalid float fixture"
  val input = TextIO.openIn "float.expected"
  val text = TextIO.inputAll input
  val _ = TextIO.closeIn input
  val _ = List.app row (String.tokens (fn c => c = #"\n") text)
end
