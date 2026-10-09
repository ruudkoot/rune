(* SML/NJ's CoreIntInf and Core, the structures of its init library that
   stand on the representation of its values (target64-core-intinf.sml and
   target64-core.sml), made of Rune's: an intinf is Rune's IntInf.int, and
   rep, SML/NJ's own (a sign and digits of 62 bits, the least significant
   first), is made of one where the library asks for it. *)
structure CoreIntInf :> sig
    datatype rep = BI of { negative : bool, digits : word list }
    type intinf = PrimTypes.intinf
    val abstract : rep -> intinf
    val concrete : intinf -> rep
    val baseBits : word
    val base : word
    val maxDigit : word
    val testInf64 : intinf -> PrimTypes.int64
    val truncInf64 : intinf -> PrimTypes.word64
    val extend64Inf : PrimTypes.int64 -> intinf
    val copy64Inf : PrimTypes.word64 -> intinf
    val makeNegInf : word list -> intinf
    val makePosInf : word list -> intinf
    val makeSmallNegInf : word -> intinf
    val makeSmallPosInf : word -> intinf
    val lowValue : intinf -> int
    val neg_base_as_int : int
    val natinc : word list -> word list
    val ~ : intinf -> intinf
    val + : intinf * intinf -> intinf
    val - : intinf * intinf -> intinf
    val * : intinf * intinf -> intinf
    val div : intinf * intinf -> intinf
    val mod : intinf * intinf -> intinf
    val quot : intinf * intinf -> intinf
    val rem : intinf * intinf -> intinf
    val < : intinf * intinf -> bool
    val <= : intinf * intinf -> bool
    val > : intinf * intinf -> bool
    val >= : intinf * intinf -> bool
    val compare : intinf * intinf -> Order.order
    val abs : intinf -> intinf
    val pow : intinf * int -> intinf
    val divMod : intinf * intinf -> intinf * intinf
    val quotRem : intinf * intinf -> intinf * intinf
    val natdivmodd : word list * word -> word list * word
    val natmadd : word * word list * word -> word list
  end =
struct
  datatype rep = BI of { negative : bool, digits : word list }
  type intinf = IntInf.int
  val baseBits = 0w62
  val base = Word.<< (0w1, baseBits)
  val maxDigit = Word.- (base, 0w1)
  val baseI = IntInf.pow (IntInf.fromInt 2, 62)
  (* a natural number and its digits *)
  fun fromDigits ds = List.foldr (fn (d, acc) => IntInf.+ (IntInf.* (acc, baseI), Word.toLargeInt d)) (IntInf.fromInt 0) ds
  fun toDigits n =
    if n = IntInf.fromInt 0 then []
    else let val (q, r) = IntInf.divMod (n, baseI) in Word.fromLargeInt r :: toDigits q end
  fun abstract (BI {negative, digits}) = let val n = fromDigits digits in if negative then IntInf.~ n else n end
  fun concrete i = BI {negative = IntInf.< (i, IntInf.fromInt 0), digits = toDigits (IntInf.abs i)}
  val testInf64 = Int64.fromLarge
  val truncInf64 = Word64.fromLargeInt
  val extend64Inf = Int64.toLarge
  val copy64Inf = Word64.toLargeInt
  fun makeNegInf ds = IntInf.~ (fromDigits ds)
  val makePosInf = fromDigits
  fun makeSmallNegInf d = IntInf.~ (Word.toLargeInt d)
  val makeSmallPosInf = Word.toLargeInt
  val neg_base_as_int = ~0x4000000000000000
  fun lowValue i = if IntInf.< (IntInf.abs i, baseI) then IntInf.toInt i else neg_base_as_int
  fun natinc ds = toDigits (IntInf.+ (fromDigits ds, IntInf.fromInt 1))
  val ~ = IntInf.~
  val op + = IntInf.+
  val op - = IntInf.-
  val op * = IntInf.*
  val op div = IntInf.div
  val op mod = IntInf.mod
  val quot = IntInf.quot
  val rem = IntInf.rem
  val op < = IntInf.<
  val op <= = IntInf.<=
  val op > = IntInf.>
  val op >= = IntInf.>=
  val compare = IntInf.compare
  val abs = IntInf.abs
  val pow = IntInf.pow
  val divMod = IntInf.divMod
  val quotRem = IntInf.quotRem
  fun natdivmodd (ds, d) =
    let val (q, r) = IntInf.divMod (fromDigits ds, Word.toLargeInt d) in (toDigits q, Word.fromLargeInt r) end
  fun natmadd (w, ds, c) = toDigits (IntInf.+ (IntInf.* (fromDigits ds, Word.toLargeInt w), Word.toLargeInt c))
end

structure Core =
struct
  structure Assembly = Assembly
  exception Bind = Bind
  exception Match = Match
  exception Domain = Domain
  exception Range
  exception Subscript = Subscript
  exception Size = Size
  exception Chr = Chr
  (* the greatest length of a string, a vector or an array, and one more
     than SML/NJ's (2^56 - 1 there) *)
  val max_length = 0x7fffffff
  val profile_register : (string -> int * int array * int ref) ref =
        ref (fn _ => raise Fail "xc2: no profiler")
  val profile_sregister : (Assembly.object * string -> Assembly.object) ref = ref (fn (x, _) => x)
  type 'a susp = 'a XC2N.susp
  val delay = XC2N.delay
  val force = XC2N.force
  type tdp_plugin =
       { name : string, save : unit -> unit -> unit, push : int * int -> unit -> unit,
         nopush : int * int -> unit, enter : int * int -> unit, register : int * int * int * string -> unit }
  local val next = ref 0
  in
    fun tdp_reserve n = let val r = !next in next := n + r; r end
    fun tdp_reset () = next := 0
  end
  val tdp_idk_entry_point = 0
  val tdp_idk_non_tail_call = 1
  val tdp_idk_tail_call = 2
  val tdp_active_plugins : tdp_plugin list ref = ref []
end
