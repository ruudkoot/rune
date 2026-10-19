structure BenchMandelbrotSix =
struct
  exception PixelDone
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun render width emit=
    let val fw=Real.fromInt width/2.0 val fh=Real.fromInt width/2.0
        val byte=ref(0w0:Word8.word)
        fun header text=for 0(String.size text-1)(fn i=>emit(Word8.fromInt(Char.ord(String.sub(text,i)))))
        val _=header("P4\n"^Int.toString width^" "^Int.toString width^"\n")
        val _=for 0(width-1)(fn y=>
          let val ci=Real.fromInt y/fh-1.0
              val _=for 0(width-1)(fn x=>
                let val cr=Real.fromInt x/fw-1.5
                    val zr=ref 0.0 val zi=ref 0.0 val trmti=ref 0.0 val n=ref 0
                    fun pixel()=
                      let val _=zi:=2.0* !zr* !zi+ci
                          val _=zr:= !trmti+cr
                          val tr= !zr* !zr val ti= !zi* !zi
                      in if tr+ti>4.0 then(byte:=Word8.<<(!byte,0w1);raise PixelDone)
                         else(n:= !n+1;if !n=50 then
                           (byte:=Word8.orb(Word8.<<(!byte,0w1),0w1);raise PixelDone)
                           else(trmti:=tr-ti;pixel()))end
                    val _=pixel()handle PixelDone=>()
                in if x mod 8=7 then emit(!byte)else()end)
              val remainder=width mod 8
          in if remainder<>0 then emit(Word8.<<(!byte,Word.fromInt(8-remainder)))else()end)
    in()end
end
