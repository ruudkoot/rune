(* SML/NJ's InlineT, the typed interface to the primitive operators of its
   compiler (target64-inline.sml), and MathInlineT (math-built-in.sml),
   made of Rune's. What cannot be made of Rune's -- a cast, a continuation,
   the object inspection of Unsafe.Object, a string written in place --
   raises XC2.Unimplemented where it is called: the patch leaves the
   library none of those it runs. *)
structure InlineT =
struct
  type 'a control_cont = 'a PrimTypes.control_cont
  fun none what _ = XC2.unimplemented ("InlineT." ^ what)

  val callcc : ('a PrimTypes.cont -> 'a) -> 'a = fn _ => none "callcc" ()
  val throw : 'a PrimTypes.cont -> 'a -> 'b = fn _ => none "throw"
  val capture : ('a control_cont -> 'a) -> 'a = fn _ => none "capture" ()
  val escape : 'a control_cont -> 'a -> 'b = fn _ => none "escape"
  val isolate : ('a -> unit) -> 'a PrimTypes.cont = fn _ => none "isolate" ()
  val ! : 'a ref -> 'a = !
  val op := : 'a ref * 'a -> unit = op :=
  val makeref : 'a -> 'a ref = ref
  val op = : ''a * ''a -> bool = op =
  val op <> : ''a * ''a -> bool = op <>
  val boxed : 'a -> bool = fn x => none "boxed" x
  val unboxed : 'a -> bool = fn x => none "unboxed" x
  val cast : 'a -> 'b = fn x => none "cast" x
  val identity : 'a -> 'a = fn x => x
  val objlength : 'a -> int = fn x => none "objlength" x
  val mkspecial : int * 'a -> 'b = fn x => none "mkspecial" x
  val getspecial : 'a -> int = fn x => none "getspecial" x
  val setspecial : ('a * int) -> unit = fn x => none "setspecial" x
  val gethdlr : unit -> 'a PrimTypes.cont = fn x => none "gethdlr" x
  val sethdlr : 'a PrimTypes.cont -> unit = fn x => none "sethdlr" x
  val getvar : unit -> 'a = fn x => none "getvar" x
  val setvar : 'a -> unit = fn x => none "setvar" x
  val compose : ('b -> 'c) * ('a -> 'b) -> ('a -> 'c) = op o
  val op before : ('a * 'b) -> 'a = fn (a, _) => a
  val ignore : 'a -> unit = fn _ => ()
  val gettag : 'a -> int = fn x => none "gettag" x
  val inlnot : bool -> bool = not
  val recordSub : ('a * int) -> 'b = fn x => none "recordSub" x
  val raw64Sub : ('a * int) -> real = fn x => none "raw64Sub" x
  val ptreql : 'a * 'a -> bool = _prim "ptr_eq" : 'a * 'a -> bool
  fun isBigEndian () = false
  fun wordSize () = 64

  structure Real64 =
  struct
    val op + : real * real -> real = Real.+
    val op - : real * real -> real = Real.-
    val op / : real * real -> real = Real./
    val op * : real * real -> real = Real.*
    val op == : real * real -> bool = Real.==
    val op != : real * real -> bool = Real.!=
    val op >= : real * real -> bool = Real.>=
    val op > : real * real -> bool = Real.>
    val op <= : real * real -> bool = Real.<=
    val op < : real * real -> bool = Real.<
    val ~ : real -> real = Real.~
    val abs : real -> real = Real.abs
    val min : real * real -> real = Real.min
    val max : real * real -> real = Real.max
    fun from_int64 (i : PrimTypes.int64) : real = Real.fromLargeInt (Int64.toLarge i)
    val from_int : int -> real = Real.fromInt
    val floor : real -> int = Real.floor
    val signBit : real -> bool = Real.signBit
    val toBits = _prim "real_to_bits" : real -> PrimTypes.word64
    val fromBits = _prim "real_from_bits" : PrimTypes.word64 -> real
  end

  structure Int =
  struct
    fun toInt (i : int) = i
    fun fromInt (i : int) = i
    val toLarge : int -> PrimTypes.intinf = Int.toLarge
    val fromLarge : PrimTypes.intinf -> int = Int.fromLarge
    val op * : int * int -> int = Int.*
    val op quot : int * int -> int = Int.quot
    val op rem : int * int -> int = Int.rem
    val op div : int * int -> int = Int.div
    val op mod : int * int -> int = Int.mod
    val op + : int * int -> int = Int.+
    val op - : int * int -> int = Int.-
    val ~ : int -> int = Int.~
    fun bits f (a, b) = Word.toIntX (f (Word.fromInt a, Word.fromInt b))
    val andb : int * int -> int = bits Word.andb
    val orb : int * int -> int = bits Word.orb
    val xorb : int * int -> int = bits Word.xorb
    fun rshift (i : int, n : word) = Word.toIntX (Word.~>> (Word.fromInt i, n))
    fun lshift (i : int, n : word) = Word.toIntX (Word.<< (Word.fromInt i, n))
    fun notb (i : int) = Word.toIntX (Word.notb (Word.fromInt i))
    val op < : int * int -> bool = Int.<
    val op <= : int * int -> bool = Int.<=
    val op > : int * int -> bool = Int.>
    val op >= : int * int -> bool = Int.>=
    val op = : int * int -> bool = op =
    val op <> : int * int -> bool = op <>
    fun ltu (a : int, b : int) = Word.< (Word.fromInt a, Word.fromInt b)
    fun geu (a : int, b : int) = Word.>= (Word.fromInt a, Word.fromInt b)
    val min : int * int -> int = Int.min
    val max : int * int -> int = Int.max
    val abs : int -> int = Int.abs
    (* without the check of Overflow: they wrap *)
    fun fast_add (a : int, b : int) = Word.toIntX (Word.+ (Word.fromInt a, Word.fromInt b))
    fun fast_sub (a : int, b : int) = Word.toIntX (Word.- (Word.fromInt a, Word.fromInt b))
  end

  structure Int32 =
  struct
    val toInt : PrimTypes.int32 -> int = Int32.toInt
    val fromInt : int -> PrimTypes.int32 = Int32.fromInt
    val toLarge : PrimTypes.int32 -> PrimTypes.intinf = Int32.toLarge
    val fromLarge : PrimTypes.intinf -> PrimTypes.int32 = Int32.fromLarge
    val op + = Int32.+ val op - = Int32.- val op * = Int32.*
    val op quot = Int32.quot val op rem = Int32.rem val op div = Int32.div val op mod = Int32.mod
    val ~ = Int32.~
    val op < = Int32.< val op <= = Int32.<= val op > = Int32.> val op >= = Int32.>=
    val op = : PrimTypes.int32 * PrimTypes.int32 -> bool = op =
    val op <> : PrimTypes.int32 * PrimTypes.int32 -> bool = op <>
    val min = Int32.min val max = Int32.max val abs = Int32.abs
  end

  structure Int64 =
  struct
    val toInt : PrimTypes.int64 -> int = Int64.toInt
    val fromInt : int -> PrimTypes.int64 = Int64.fromInt
    val toLarge : PrimTypes.int64 -> PrimTypes.intinf = Int64.toLarge
    val fromLarge : PrimTypes.intinf -> PrimTypes.int64 = Int64.fromLarge
    val op + = Int64.+ val op - = Int64.- val op * = Int64.*
    val op quot = Int64.quot val op rem = Int64.rem val op div = Int64.div val op mod = Int64.mod
    val ~ = Int64.~
    val op < = Int64.< val op <= = Int64.<= val op > = Int64.> val op >= = Int64.>=
    val op = : PrimTypes.int64 * PrimTypes.int64 -> bool = op =
    val op <> : PrimTypes.int64 * PrimTypes.int64 -> bool = op <>
    val min = Int64.min val max = Int64.max val abs = Int64.abs
  end

  structure IntInf =
  struct
    val toInt : PrimTypes.intinf -> int = IntInf.toInt
    val fromInt : int -> PrimTypes.intinf = IntInf.fromInt
    fun toLarge (i : PrimTypes.intinf) = i
    fun fromLarge (i : PrimTypes.intinf) = i
  end

  (* Rune's shifts take any amount, as the checked ones of SML/NJ do *)
  structure Word =
  struct
    fun toLarge (w : word) : PrimTypes.word64 = Word64.fromLarge (Word.toLarge w)
    fun toLargeX (w : word) : PrimTypes.word64 = Word64.fromLarge (Word.toLargeX w)
    fun fromLarge (w : PrimTypes.word64) : word = Word.fromLarge (Word64.toLarge w)
    val toInt : word -> int = Word.toInt
    val toIntX : word -> int = Word.toIntX
    val fromInt : int -> word = Word.fromInt
    val toLargeInt : word -> PrimTypes.intinf = Word.toLargeInt
    val toLargeIntX : word -> PrimTypes.intinf = Word.toLargeIntX
    val fromLargeInt : PrimTypes.intinf -> word = Word.fromLargeInt
    fun toInt64 (w : word) : PrimTypes.int64 = Int64.fromInt (Word.toIntX w)
    val toWord64 = toLarge
    val fromWord64 = fromLarge
    val orb = Word.orb val xorb = Word.xorb val andb = Word.andb
    val op * = Word.* val op + = Word.+ val op - = Word.- val ~ = Word.~
    val op div = Word.div val op mod = Word.mod
    val op > = Word.> val op >= = Word.>= val op < = Word.< val op <= = Word.<=
    val rshift = Word.~>> val rshiftl = Word.>> val lshift = Word.<<
    val chkLshift = Word.<< val chkRshift = Word.~>> val chkRshiftl = Word.>>
    val notb = Word.notb
    val min = Word.min val max = Word.max
  end

  structure Word8 =
  struct
    fun toLarge (w : PrimTypes.word8) : PrimTypes.word64 = Word64.fromLarge (Word8.toLarge w)
    fun toLargeX (w : PrimTypes.word8) : PrimTypes.word64 = Word64.fromLarge (Word8.toLargeX w)
    fun fromLarge (w : PrimTypes.word64) : PrimTypes.word8 = Word8.fromLarge (Word64.toLarge w)
    val toInt = Word8.toInt val toIntX = Word8.toIntX val fromInt = Word8.fromInt
    val toLargeInt = Word8.toLargeInt val toLargeIntX = Word8.toLargeIntX val fromLargeInt = Word8.fromLargeInt
    val orb = Word8.orb val xorb = Word8.xorb val andb = Word8.andb
    val op * = Word8.* val op + = Word8.+ val op - = Word8.- val ~ = Word8.~
    val op div = Word8.div val op mod = Word8.mod
    val op > = Word8.> val op >= = Word8.>= val op < = Word8.< val op <= = Word8.<=
    val rshift = Word8.~>> val rshiftl = Word8.>> val lshift = Word8.<<
    val notb = Word8.notb
    val chkRshift = Word8.~>> val chkRshiftl = Word8.>> val chkLshift = Word8.<<
    val min = Word8.min val max = Word8.max
  end

  structure Word32 =
  struct
    fun toLarge (w : PrimTypes.word32) : PrimTypes.word64 = Word64.fromLarge (Word32.toLarge w)
    fun toLargeX (w : PrimTypes.word32) : PrimTypes.word64 = Word64.fromLarge (Word32.toLargeX w)
    fun fromLarge (w : PrimTypes.word64) : PrimTypes.word32 = Word32.fromLarge (Word64.toLarge w)
    val toInt = Word32.toInt val toIntX = Word32.toIntX val fromInt = Word32.fromInt
    val toLargeInt = Word32.toLargeInt val toLargeIntX = Word32.toLargeIntX val fromLargeInt = Word32.fromLargeInt
    val orb = Word32.orb val xorb = Word32.xorb val andb = Word32.andb
    val op * = Word32.* val op + = Word32.+ val op - = Word32.- val ~ = Word32.~
    val op div = Word32.div val op mod = Word32.mod
    val op > = Word32.> val op >= = Word32.>= val op < = Word32.< val op <= = Word32.<=
    val rshift = Word32.~>> val rshiftl = Word32.>> val lshift = Word32.<<
    val notb = Word32.notb
    val chkRshift = Word32.~>> val chkRshiftl = Word32.>> val chkLshift = Word32.<<
    val min = Word32.min val max = Word32.max
  end

  structure Word64 =
  struct
    fun toLarge (w : PrimTypes.word64) = w
    fun toLargeX (w : PrimTypes.word64) = w
    fun fromLarge (w : PrimTypes.word64) = w
    val toInt = Word64.toInt val toIntX = Word64.toIntX val fromInt = Word64.fromInt
    val toLargeInt = Word64.toLargeInt val toLargeIntX = Word64.toLargeIntX val fromLargeInt = Word64.fromLargeInt
    val op + = Word64.+ val op - = Word64.- val op * = Word64.* val op div = Word64.div val op mod = Word64.mod
    val ~ = Word64.~
    val orb = Word64.orb val xorb = Word64.xorb val andb = Word64.andb
    val chkLshift = Word64.<< val chkRshift = Word64.~>> val chkRshiftl = Word64.>>
    val rshift = Word64.~>> val rshiftl = Word64.>> val lshift = Word64.<<
    val notb = Word64.notb
    val op > = Word64.> val op >= = Word64.>= val op < = Word64.< val op <= = Word64.<=
    val min = Word64.min val max = Word64.max
  end

  structure Char =
  struct
    val maxOrd = 255
    exception Chr = Chr
    val chr : int -> char = Char.chr
    val ord : char -> int = Char.ord
    val op < : char * char -> bool = Char.<
    val op <= : char * char -> bool = Char.<=
    val op > : char * char -> bool = Char.>
    val op >= : char * char -> bool = Char.>=
  end

  structure PolyArray =
  struct
    fun newArray0 () : 'a array = Array.fromList []
    val array : int * 'a -> 'a array = Array.array
    val length : 'a array -> int = Array.length
    val sub : 'a array * int -> 'a = Array.sub
    val chkSub : 'a array * int -> 'a = Array.sub
    val update : 'a array * int * 'a -> unit = Array.update
    val chkUpdate : 'a array * int * 'a -> unit = Array.update
    val getData : 'a array -> 'b = fn x => none "PolyArray.getData" x
  end

  structure PolyVector =
  struct
    val length : 'a vector -> int = Vector.length
    val sub : 'a vector * int -> 'a = Vector.sub
    val chkSub : 'a vector * int -> 'a = Vector.sub
    val getData : 'a vector -> 'b = fn x => none "PolyVector.getData" x
  end

  structure Real64Array =
  struct
    type array = PrimTypes.real64array
    fun newArray0 () : array = Array.fromList []
    val length : array -> int = Array.length
    val sub : array * int -> real = Array.sub
    val chkSub : array * int -> real = Array.sub
    val update : array * int * real -> unit = Array.update
    val chkUpdate : array * int * real -> unit = Array.update
    val getData : array -> 'b = fn x => none "Real64Array.getData" x
  end

  structure Real64Vector =
  struct
    val length : real vector -> int = Vector.length
    val sub : real vector * int -> real = Vector.sub
    val chkSub : real vector * int -> real = Vector.sub
    val getData : real vector -> 'b = fn x => none "Real64Vector.getData" x
  end

  structure Word8Array =
  struct
    type array = PrimTypes.word8array
    fun newArray0 () : array = Array.fromList []
    val length : array -> int = Array.length
    val sub : array * int -> PrimTypes.word8 = Array.sub
    val chkSub : array * int -> PrimTypes.word8 = Array.sub
    val update : array * int * PrimTypes.word8 -> unit = Array.update
    val chkUpdate : array * int * PrimTypes.word8 -> unit = Array.update
    val getData : array -> 'a = fn x => none "Word8Array.getData" x
  end

  (* a word8vector is a string: its bytes are the codes of the characters *)
  structure Word8Vector =
  struct
    type vector = PrimTypes.word8vector
    val create : int -> vector = fn n => none "Word8Vector.create: a vector written in place" n
    val length : vector -> int = String.size
    fun sub (v : vector, i) : PrimTypes.word8 = Word8.fromInt (Char.ord (String.sub (v, i)))
    val chkSub = sub
    val update : vector * int * PrimTypes.word8 -> unit = fn x => none "Word8Vector.update" x
    val getData : vector -> 'a = fn x => none "Word8Vector.getData" x
  end

  structure CharArray =
  struct
    type array = PrimTypes.chararray
    fun newArray0 () : array = Array.fromList []
    fun create n : array = Array.array (n, #"\000")
    val length : array -> int = Array.length
    val chkSub : array * int -> char = Array.sub
    val chkUpdate : array * int * char -> unit = Array.update
    val sub : array * int -> char = Array.sub
    val update : array * int * char -> unit = Array.update
    val getData : array -> 'a = fn x => none "CharArray.getData" x
  end

  structure CharVector =
  struct
    val length : string -> int = String.size
    val chkSub : string * int -> char = String.sub
    val sub : string * int -> char = String.sub
    val update : string * int * char -> unit = fn x => none "CharVector.update: a string written in place" x
    val getData : string -> 'a = fn x => none "CharVector.getData" x
  end

  structure Pointer =
  struct
    type t = PrimTypes.c_pointer
    fun toWord64 (p : t) = p
    fun fromWord64 (w : PrimTypes.word64) : t = w
  end
end

structure MathInlineT =
struct
  val sqrt : real -> real = Math.sqrt
end
