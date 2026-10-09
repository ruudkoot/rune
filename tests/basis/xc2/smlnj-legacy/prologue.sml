(* The start of the xc2:smlnj-legacy configuration's library (tests/basis/xc2):
   what SML/NJ's compiler gives its init library (the structure PrimTypes
   of its primitive environment), made of Rune's. It is compiled after
   tests/basis/xc2/xc2.sml and before the shim and SML/NJ's sources.

   SML/NJ's int and word are Rune's, of 63 bits on both, its int64 and
   word64 Rune's Int64.int and Word64.word; int32, word8 and word32 are
   Rune's Int32.int, Word8.word and Word32.word, intinf Rune's IntInf.int. A string is Rune's
   string, and so is a word8vector (SML/NJ's library casts between the two,
   which share a representation there too); arrays and vectors are Rune's.
   Continuations are not made. *)
structure XC2N =
struct
  (* the SysErr of SML/NJ's runtime (Assembly.SysErr), which its C
     functions raise *)
  exception SysErr of string * int option
  (* what the patches and rewrite.awk put in place of SML/NJ's own *)
  fun vector (l : 'a list) : 'a vector = Vector.fromList l
  fun vector0 () : 'a vector = Vector.fromList []
  val substring = String.substring
  val concat = String.concat
  val implode = String.implode
  val str = String.str
  val size = String.size
  val sub = String.sub
  fun concat2 (a : string, b) = a ^ b
  val exnName = General.exnName
  val print = TextIO.print
  (* a string of n characters, the i-th f i *)
  val tabulate = CharVector.tabulate
  (* a string being made: where SML/NJ creates a string and writes it in
     place, the patch writes a buffer and takes the string of it at the end *)
  type buf = char array
  fun buf n : buf = Array.array (n, #"\000")
  val bupd : buf * int * char -> unit = Array.update
  fun bupdw (b : buf, i, w : Word8.word) = Array.update (b, i, Char.chr (Word8.toInt w))
  val bsub : buf * int -> char = Array.sub
  fun bstr (b : buf) : string = CharVector.tabulate (Array.length b, fn i => Array.sub (b, i))
  fun w2c (w : Word8.word) = Char.chr (Word8.toInt w)
  fun c2w (c : char) = Word8.fromInt (Char.ord c)
  (* SML/NJ's suspensions (lazy values) *)
  datatype 'a susp = Susp of 'a thunk ref
  and 'a thunk = Delayed of unit -> 'a | Forced of 'a
  fun delay f = Susp (ref (Delayed f))
  fun force (Susp (r as ref (Delayed f))) = let val x = f () in r := Forced x; x end
    | force (Susp (ref (Forced x))) = x
end

structure PrimTypes =
struct
  datatype bool = datatype bool
  datatype list = datatype list
  datatype ref = datatype ref
  type unit = unit
  type int = int
  type int32 = Int32.int
  type int64 = Int64.int
  type intinf = IntInf.int
  type real = real
  type word = word
  type word8 = Word8.word
  type word32 = Word32.word
  type word64 = Word64.word
  datatype 'a cont = XC2NCont of 'a -> unit
  datatype 'a control_cont = XC2NControlCont of 'a -> unit
  type 'a array = 'a array
  type 'a vector = 'a vector
  (* an object of the runtime's: a directory stream is one *)
  datatype object = XC2NObject | XC2NDir of int
  datatype c_function = XC2NCFunction of string * string
  type c_pointer = Word64.word
  type word8vector = string
  type word8array = Word8.word array
  type real64array = real array
  datatype spin_lock = XC2NSpinLock of bool ref
  type string = string
  type chararray = char array
  type char = char
  type exn = exn
  datatype 'a frag = QUOTE of string | ANTIQUOTE of 'a
  type 'a susp = 'a XC2N.susp
end

(* SML/NJ's init library is compiled where the types of PrimTypes are bound *)
open PrimTypes
