(* Implements: WIN32_VALUES *)
structure Win32Values :> WIN32_VALUES =
struct
  fun lowWord value=Word16.fromLargeWord(Word64.toLargeWord(Word64.andb(value,0wxFFFF)))
  fun highWord value=lowWord(Word64.>>(value,0w16))
  fun rgb{red,green,blue}=
    Word32.orb(Word32.fromInt(Word8.toInt red),Word32.orb(
      Word32.<<(Word32.fromInt(Word8.toInt green),0w8),
      Word32.<<(Word32.fromInt(Word8.toInt blue),0w16)))
  fun red colour=Word8.fromLargeWord(Word32.toLargeWord(Word32.andb(colour,0wxFF)))
  fun green colour=red(Word32.>>(colour,0w8))
  fun blue colour=red(Word32.>>(colour,0w16))
  fun signed value=let val n=Word16.toInt value in if n>=32768 then n-65536 else n end
  fun xFromLParam value=signed(lowWord(Word64.fromLargeInt(Int64.toLarge value)))
  fun yFromLParam value=signed(highWord(Word64.fromLargeInt(Int64.toLarge value)))
end
