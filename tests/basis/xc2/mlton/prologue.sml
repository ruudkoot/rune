(* The start of the xc2 configuration's library (tests/basis/xc2): what
   MLton's compiler gives MLton's Basis Library, made of Rune's. It is
   compiled after Rune's library and before the shim and MLton's sources.

   MLton's primitive types are Rune's: int8, int16, int32 and int64 are
   Int8.int to Int64.int, word8 to word64 likewise, real32 and real64
   Real32.real and real; a type of another width up to 32 is kept in the
   next of these, and one from 33 to 63 in Rune's int or word, of 63 bits.
   A C pointer is a Word64.word, as C_Pointer.t is. char8 is char and char16 and char32 WideChar.char. MLton's string
   is a vector of char8, Rune's is not: String8.string is Rune's string and
   tests/basis/xc2/mlton/basis.patch makes MLton's text structures build it
   so. *)

type char8 = char
type char16 = WideChar.char
type char32 = WideChar.char
type int1 = Int8.int type int2 = Int8.int type int3 = Int8.int
type int4 = Int8.int type int5 = Int8.int type int6 = Int8.int
type int7 = Int8.int type int8 = Int8.int
type int9 = Int16.int type int10 = Int16.int type int11 = Int16.int
type int12 = Int16.int type int13 = Int16.int type int14 = Int16.int
type int15 = Int16.int type int16 = Int16.int
type int17 = Int32.int type int18 = Int32.int type int19 = Int32.int
type int20 = Int32.int type int21 = Int32.int type int22 = Int32.int
type int23 = Int32.int type int24 = Int32.int type int25 = Int32.int
type int26 = Int32.int type int27 = Int32.int type int28 = Int32.int
type int29 = Int32.int type int30 = Int32.int type int31 = Int32.int
type int32 = Int32.int
type int33 = int type int34 = int type int35 = int type int36 = int
type int37 = int type int38 = int type int39 = int type int40 = int
type int41 = int type int42 = int type int43 = int type int44 = int
type int45 = int type int46 = int type int47 = int type int48 = int
type int49 = int type int50 = int type int51 = int type int52 = int
type int53 = int type int54 = int type int55 = int type int56 = int
type int57 = int type int58 = int type int59 = int type int60 = int
type int61 = int type int62 = int type int63 = int type int64 = Int64.int
type word1 = Word8.word type word2 = Word8.word type word3 = Word8.word
type word4 = Word8.word type word5 = Word8.word type word6 = Word8.word
type word7 = Word8.word type word8 = Word8.word
type word9 = Word16.word type word10 = Word16.word type word11 = Word16.word
type word12 = Word16.word type word13 = Word16.word type word14 = Word16.word
type word15 = Word16.word type word16 = Word16.word
type word17 = Word32.word type word18 = Word32.word type word19 = Word32.word
type word20 = Word32.word type word21 = Word32.word type word22 = Word32.word
type word23 = Word32.word type word24 = Word32.word type word25 = Word32.word
type word26 = Word32.word type word27 = Word32.word type word28 = Word32.word
type word29 = Word32.word type word30 = Word32.word type word31 = Word32.word
type word32 = Word32.word
type word33 = word type word34 = word type word35 = word type word36 = word
type word37 = word type word38 = word type word39 = word type word40 = word
type word41 = word type word42 = word type word43 = word type word44 = word
type word45 = word type word46 = word type word47 = word type word48 = word
type word49 = word type word50 = word type word51 = word type word52 = word
type word53 = word type word54 = word type word55 = word type word56 = word
type word57 = word type word58 = word type word59 = word type word60 = word
type word61 = word type word62 = word type word63 = word type word64 = Word64.word
type intInf = IntInf.int
type real32 = Real32.real
type real64 = real
type cpointer = Word64.word
type thread = unit ref
type 'a weak = 'a option ref
type 'a array = 'a XC2.array
