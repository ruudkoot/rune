(* The start of the xc2:mlkit configuration's library (tests/basis/xc2):
   what MLKit's compiler gives MLKit's Basis Library, made of Rune's. It is
   compiled after tests/basis/xc2/xc2.sml and before the shim and MLKit's
   sources.

   MLKit's int and int63 are Rune's int, of 63 bits as MLKit's; int64
   Int64.int, int32 Int32.int, word64 Word64.word, word32 Word32.word and
   word8 Word8.word; word and word63 Rune's word; int31 and word31 have 31 bits,
   by the functors of Rune's library (MLKit's IntInf counts on an int31
   overflowing where Int32.int does not). A chararray is a Rune array of
   chars, and MLKit's 'a array and 'a vector are XC2's array, whose cells
   are made at the first update. *)
structure XC2Int31 = RuneIntNFn (val precision = 31)
_overload int XC2Int31 31
structure XC2Word31 = RuneWordNFn (val wordSize = 31)
_overload word XC2Word31 31
type int31 = XC2Int31.int
type int32 = Int32.int
type int63 = int
type int64 = Int64.int
type word8 = Word8.word
type word31 = XC2Word31.word
type word32 = Word32.word
type word63 = word
type word64 = Word64.word
type chararray = char XC2.array
type foreignptr = word
type 'a array = 'a XC2.array
(* MLKit's own built-in exception, of the top level *)
exception Interrupt
(* MLKit's IntInf.int, built in with the constructor _IntInf, which
   rewrite.awk spells XC2_IntInf *)
datatype intinf = XC2_IntInf of {negative : bool, digits : int31 list}
