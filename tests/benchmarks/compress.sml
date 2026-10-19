structure BenchCompressTests =
struct
  structure N = BenchCompressFn(BenchNeed)
  structure S = BenchCompressFn(BenchStrict)
  structure L = BenchLazy
  val _ = T.check("compress/empty",fn () => N.compress ""="" andalso S.compress ""="")
  val _ = T.check("compress/odd-code-low-nibble",fn () =>
    N.compress "A"="\004\001" andalso S.compress "A"="\004\001")
  val _ = T.check("compress/full-byte-alphabet",fn () =>
    N.compress "\000\255"="\000\000\255" andalso S.compress "\000\255"="\000\000\255")
  val _ = T.check("compress/initial-fold-order",fn () =>
    case BenchNeed.force N.initial of
      N.PT(entry,_,_) => (case BenchNeed.force entry of N.PTE(key,code,_) =>
        Char.ord(BenchNeed.force key)=255 andalso BenchNeed.force code=255)
    | _ => false)
  val next : int L.delay = L.delay(fn () => raise Fail "unneeded next code")
  val (_,code,_) = BenchNeed.force(N.codeString "A" 0 (N.value 0) next N.initial)
  val _ = T.check("compress/EOF-leaves-next-code-unforced",fn () =>
    BenchNeed.force code=65 andalso (case !next of L.Pending _ => true | _ => false))
  fun noise count =
    let fun loop 0 _ values = String.implode(List.rev values)
          | loop left seed values =
              let val next = Word32.+(Word32.*(seed,0w1664525),0w1013904223)
                  val byte = Word32.toInt(Word32.>>(next,0w24))
              in loop(left-1)next(Char.chr byte :: values) end
    in loop count (Word32.fromInt 47) [] end
  val input = noise 8192
  val file = BinIO.openIn "freeze.bin"
  val expected = Byte.bytesToString(BinIO.inputAll file)
  val _ = BinIO.closeIn file
  val _ = T.check("compress/frozen-dictionary-byte-result",fn () =>
    N.compress input=expected andalso S.compress input=expected)
  val codes = N.toList(N.encode input)
  val _ = T.check("compress/no-codes-past-capacity",fn () =>
    List.length codes>4096 andalso List.all(fn code => code>=0 andalso code<4096)codes)
end
