(* Signed 64-bit machine arithmetic represented explicitly in portable Word64. *)
structure BenchSigned64 =
struct
  structure W = Word64
  val sign : W.word = 0wx8000000000000000
  val minusOne : W.word = 0wxffffffffffffffff
  fun negative a = W.andb (a, sign) <> 0w0
  fun negate a = W.- (0w0, a)
  fun magnitude a = if negative a then negate a else a
  fun less (a, b) = W.< (W.xorb (a, sign), W.xorb (b, sign))
  fun leq (a, b) = a = b orelse less (a, b)
  fun quotient (a, b) =
    if b = 0w0 then raise Div
    else if a = sign andalso b = minusOne then raise Overflow
    else let val q = W.div (magnitude a, magnitude b)
         in if negative a <> negative b then negate q else q end
  fun remainder (a, b) = W.- (a, W.* (quotient (a, b), b))
  fun divide (a, b) =
    let val q = quotient (a, b) val r = W.- (a, W.* (q, b))
    in if r <> 0w0 andalso negative a <> negative b then W.- (q, 0w1) else q end
  fun modulo (a, b) = W.- (a, W.* (divide (a, b), b))
  fun gcd (a, b) =
    let fun loop (x, y) = if y = 0w0 then x else loop (y, W.mod (x, y))
    in loop (magnitude a, magnitude b) end
  fun lcm (a, b) = if a = 0w0 orelse b = 0w0 then 0w0
    else magnitude (W.* (quotient (a, gcd (a, b)), b))
end
