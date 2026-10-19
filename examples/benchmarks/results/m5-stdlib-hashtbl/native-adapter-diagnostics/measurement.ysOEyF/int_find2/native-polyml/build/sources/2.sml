(* OCaml 4.14.1 runtime/hash.c, integer and two-integer-tuple domain.
 * Xavier Leroy / INRIA 1996, LGPL 2.1 with linking exception.
 * Explicit Word32 arithmetic preserves the source MurmurHash3 mixing.
 * Fixed-domain specialization omits the generic runtime object queue. *)
structure BenchStdlibHash=
struct
 fun rotate value amount=
   Word32.orb(Word32.<<(value,Word.fromInt amount),Word32.>>(value,Word.fromInt(32-amount)))
 fun mix state value=
   let val value=Word32.*(value,0wxCC9E2D51)
       val value=rotate value 15
       val value=Word32.*(value,0wx1B873593)
       val state=rotate(Word32.xorb(state,value))13
   in Word32.+(Word32.*(state,0w5),0wxE6546B64)end
 fun finish state=
   let val state=Word32.xorb(state,Word32.>>(state,0w16))
       val state=Word32.*(state,0wx85EBCA6B)
       val state=Word32.xorb(state,Word32.>>(state,0w13))
       val state=Word32.*(state,0wxC2B2AE35)
       val state=Word32.xorb(state,Word32.>>(state,0w16))
   in Word32.toInt(Word32.andb(state,0wx3FFFFFFF))end
 fun tagged n=Word32.+(Word32.*(Word32.fromInt n,0w2),0w1)
 fun integer n=finish(mix 0w0(tagged n))
 fun pair(a,b)=finish(mix(mix(mix 0w0 0w2048)(tagged a))(tagged b))
end
