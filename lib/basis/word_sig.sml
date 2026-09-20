(* Words: integers of a fixed number of bits, without a sign, whose
   arithmetic wraps round instead of overflowing, and which can be taken
   apart bit by bit.

   A word of `wordSize` bits holds the numbers from 0 to `2^wordSize - 1`;
   every operation that would leave that range is taken modulo `2^wordSize`,
   so nothing raises `Overflow` but the conversions to a type that cannot
   hold the value. This is the type for bit sets, masks, hashes and whatever
   is counted in bits rather than in numbers.

   Where a word is read as a signed number (`toIntX`, `toLargeX`, `~>>`) the
   top bit is the sign, as in two's complement. The functions with an `X` in
   their name are those that sign-extend; the others fill with zeros.

   The structures differ in their width: `Word` is the default one and
   `Word8`, `Word16`, `Word32` and `Word64` are the sized ones; `LargeWord`
   is the widest, and `SysWord` is what the operating system's flags are
   counted in.

   Area: Numbers

   See also: `INTEGER`, `INT_INF`, `BYTE`, `STRING_CVT`, `PACK_WORD` *)
signature WORD =
sig
  (* ---- The type and its width ---- *)

  (* The type of words of this structure.

     Implementation: `Word.word/64-bits`. `Word.word` is the top-level
     `word`, of 64 bits, and so are `LargeWord`, `SysWord` and `Word64`;
     `Word8`, `Word16` and `Word32` are kept in a word of the machine whose
     upper bits are zero. *)
  eqtype word

  (* `wordSize` is the number of bits of a word of this structure.

     Example: `Word8.wordSize = 8` and `Word.wordSize = 64` *)
  val wordSize : int

  (* ---- Conversions between word structures ---- *)

  (* `toLarge w` is `w` as a word of `LargeWord`, with zeros in the bits above `wordSize`. *)
  val toLarge : word -> LargeWord.word

  (* `toLargeX w` is `w` as a word of `LargeWord`, with the top bit of `w` copied into the bits above it.

     Law: `toLargeX w = toLarge w` when `w < 2^(wordSize-1)` *)
  val toLargeX : word -> LargeWord.word

  (* `toLargeWord w` is another name for `toLarge`. *)
  val toLargeWord : word -> LargeWord.word

  (* `toLargeWordX w` is another name for `toLargeX`. *)
  val toLargeWordX : word -> LargeWord.word

  (* `fromLarge w` is the word of this structure with the low `wordSize` bits of `w`.

     What does not fit is dropped: nothing is raised. *)
  val fromLarge : LargeWord.word -> word

  (* `fromLargeWord w` is another name for `fromLarge`. *)
  val fromLargeWord : LargeWord.word -> word

  (* ---- Conversions to and from integers ---- *)

  (* `toLargeInt w` is the number that `w` stands for, between 0 and `2^wordSize - 1`.

     Raises: `Overflow` if that number is no `LargeInt.int`, which cannot
     happen where `LargeInt` is `IntInf`. *)
  val toLargeInt : word -> LargeInt.int

  (* `toLargeIntX w` is the number that `w` stands for read as a signed one, between `~(2^(wordSize-1))` and `2^(wordSize-1) - 1`. *)
  val toLargeIntX : word -> LargeInt.int

  (* `fromLargeInt i` is the word with the low `wordSize` bits of `i`.

     A negative `i` is taken in two's complement, and what does not fit is
     dropped.

     Law: `fromLargeInt (toLargeIntX w) = w` *)
  val fromLargeInt : LargeInt.int -> word

  (* `toInt w` is the number that `w` stands for as an `Int.int`.

     Raises: `Overflow` if that number is outside the range of `Int.int`,
     which a word as wide as an `int` can reach. *)
  val toInt : word -> int

  (* `toIntX w` is the number that `w` stands for read as a signed one, as an `Int.int`.

     Raises: `Overflow` if that number is outside the range of `Int.int`.

     Example: `Word8.toIntX 0wxFF = ~1`, where `Word8.toInt 0wxFF` is 255. *)
  val toIntX : word -> int

  (* `fromInt i` is the word with the low `wordSize` bits of `i`.

     A negative `i` is taken in two's complement.

     Example: `Word8.fromInt 256 = 0w0` *)
  val fromInt : int -> word

  (* ---- Bits ---- *)

  (* `andb (a, b)` is the bitwise "and".

     Example: `andb (0wxF0, 0wx3C) = 0wx30` *)
  val andb : word * word -> word

  (* `orb (a, b)` is the bitwise "or". *)
  val orb : word * word -> word

  (* `xorb (a, b)` is the bitwise exclusive "or".

     Example: `xorb (0wxFF, 0wx0F) = 0wxF0` *)
  val xorb : word * word -> word

  (* `notb w` is `w` with every bit inverted.

     Law: `notb w = ~w - 0w1`

     Example: `Word.notb 0w0 = 0wxFFFFFFFFFFFFFFFF` *)
  val notb : word -> word

  (* `<< (w, n)` is `w` shifted left by `n` bits, with zeros coming in and what leaves the width dropped.

     A shift of `wordSize` bits or more gives 0.

     Law: `<< (w, n) = w * 0w2 ^ n` in the arithmetic of this structure

     Example: `<< (0w1, 0w4) = 0w16`

     Example: `Word.<< (0w1, 0w64) = 0w0` for every bit is shifted out. *)
  val << : word * Word.word -> word

  (* `>> (w, n)` is `w` shifted right by `n` bits, with zeros coming in.

     A shift of `wordSize` bits or more gives 0.

     Law: `>> (w, n) = w div 0w2 ^ n`

     Example: `Word8.>> (0wx80, 0w1) = 0wx40` *)
  val >> : word * Word.word -> word

  (* `~>> (w, n)` is `w` shifted right by `n` bits, with the top bit of `w` coming in.

     A shift of `wordSize` bits or more gives 0 for a word whose top bit is
     clear and a word of all ones for one whose top bit is set: it is the
     division of a signed number by a power of two, rounded towards negative
     infinity.

     Example: `Word8.~>> (0wx80, 0w1) = 0wxC0` *)
  val ~>> : word * Word.word -> word

  (* ---- Arithmetic ---- *)

  (* `a + b` is the sum, taken modulo `2^wordSize`. *)
  val + : word * word -> word

  (* `a - b` is the difference, taken modulo `2^wordSize`: it wraps round for `a < b`.

     Example: `Word.- (0w0, 0w1) = 0wxFFFFFFFFFFFFFFFF` *)
  val - : word * word -> word

  (* `a * b` is the product, taken modulo `2^wordSize`. *)
  val * : word * word -> word

  (* `a div b` is the quotient of two unsigned numbers.

     Raises: `Div` if `b` is zero. *)
  val div : word * word -> word

  (* `a mod b` is what `div` leaves over.

     Raises: `Div` if `b` is zero.

     Law: `(a div b) * b + (a mod b) = a` *)
  val mod : word * word -> word

  (* ---- Comparing ---- *)

  (* `compare (a, b)` orders two words as unsigned numbers. *)
  val compare : word * word -> order

  (* `a < b`, `a <= b`, `a > b` and `a >= b` compare two words as unsigned numbers.

     A word whose top bit is set is the larger, not the smaller: at `Word8`,
     `0wxFF > 0w1`. *)
  val < : word * word -> bool
  val <= : word * word -> bool
  val > : word * word -> bool
  val >= : word * word -> bool

  (* `~w` is the negation modulo `2^wordSize`: the two's complement of `w`.

     Law: `~w = notb w + 0w1`, and `~0w0 = 0w0` *)
  val ~ : word -> word

  (* `min (a, b)` is the smaller of the two, as unsigned numbers. *)
  val min : word * word -> word

  (* `max (a, b)` is the larger of the two, as unsigned numbers. *)
  val max : word * word -> word

  (* ---- Text ---- *)

  (* `fmt radix w` is the text of `w` in the given base, without a prefix and without a sign.

     Erratum: `WORD/fmt-Ow`. The specification writes the hexadecimal prefix
     of the samples as `Ow` with the letter O; it is `0w` with the digit
     zero.

     Example: `fmt StringCvt.HEX 0w255 = "FF"` *)
  val fmt : StringCvt.radix -> word -> string

  (* `toString w` is the text of `w` in base 16, with the digits `A` to `F` and no prefix.

     Law: `toString w = fmt StringCvt.HEX w`

     Example: `toString 0w255 = "FF"` *)
  val toString : word -> string

  (* `scan radix getc strm` reads a word in the given base from `strm`.

     It skips initial white space and then takes an optional prefix and the
     digits: `0w` in any base, and in `StringCvt.HEX` also `0wx`, `0wX`, `0x`
     or `0X`. There is no sign. The answer is `SOME (w, rest)`, or `NONE`
     when no digit is there.

     Raises: `Overflow` if the digits name a number of more than `wordSize`
     bits.

     Reading: `Word.scan/DEC-bare-prefix-0w`. A prefix that no digit follows
     is not a prefix, but its leading `0` is a digit: `"0wxg"` scans as 0 and
     leaves `"wxg"`. *)
  val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (word, 'a) StringCvt.reader

  (* `fromString s` is the word that the text `s` begins with in base 16, or `NONE`.

     Raises: `Overflow` if the digits name a number of more than `wordSize` bits.

     Law: `fromString s = StringCvt.scanString (scan StringCvt.HEX) s`

     Example: `fromString "0wxff" = SOME 0w255`

     Example: `fromString "ff" = SOME 0w255` *)
  val fromString : string -> word option
end
