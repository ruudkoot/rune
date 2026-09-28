(* The arbitraries of the families of structures of the Basis Library
   (docs/plans/quickcheck.md, D4 and M6): one functor for each signature that
   several structures share, reading the bounds from the structure, so that no
   width is assumed. *)

(* The arbitrary of the integers of a structure of `INTEGER`, by the
   generator principles P1 and P2: small, on an edge, or anywhere in the
   range, a third each; an `IntInf` without bounds by `Gen.intInf`.

   Area: Property testing *)
functor IntegerArbFn (I : INTEGER) : ARB_OF where type t = I.int =
struct
  type t = I.int

  (* the range of I is within that of Int.int *)
  val viaInt = case (I.precision, Int.precision) of
                 (SOME p, SOME q) => p <= q
               | (SOME _, NONE) => true
               | (NONE, _) => false

  val gen : I.int Gen.gen =
    case (I.minInt, I.maxInt) of
      (SOME lo, SOME hi) =>
        if viaInt then Gen.map I.fromInt (Gen.intRange (I.toInt lo, I.toInt hi))
        else Gen.map I.fromLarge (Gen.largeRange (I.toLarge lo, I.toLarge hi))
    | _ => Gen.map (fn i => I.fromLarge (IntInf.toLarge i)) Gen.intInf

  val arb : I.int Arb.arb =
    {gen = gen, show = I.toString,
     co = if isSome I.precision then fn i => Word64.fromLargeInt (I.toLarge i) else fn i => Random.hashString (I.toString i),
     eq = SOME (op =)}
end

(* The arbitrary of the words of a structure of `WORD`, by the generator
   principle P3: small, on an edge (0, 1, the largest, powers of two and their
   neighbours), or anywhere, a third each. The words are at most 64 bits.

   Area: Property testing *)
functor WordArbFn (W : WORD) : ARB_OF where type t = W.word =
struct
  type t = W.word

  val arb : W.word Arb.arb =
    {gen = Gen.map (fn w => W.fromLarge (Word64.toLarge w)) (Gen.wordBits W.wordSize),
     show = fn w => "0wx" ^ W.fmt StringCvt.HEX w,
     co = fn w => Word64.fromLarge (W.toLarge w),
     eq = SOME (op =)}
end

(* The arbitrary of the reals of a structure of `REAL`, by the generator
   principle P4: a special one, a small one, or any bit pattern, a third
   each.

   A binary64 structure draws what `Gen.real` draws. Another draws its own
   specials (the zeros, the infinities, a NaN, the least and largest
   subnormal, the least normal, the largest finite, 1, ~1, 0.5, 2^p and the
   real after it, for its precision p), and its bit patterns as an exponent
   uniform over those of its format, subnormal, normal or not finite, and a
   uniform significand. Its equality is identity, as `Arb.real`'s is.

   Area: Property testing *)
functor RealArbFn (R : REAL) : ARB_OF where type t = R.real =
struct
  structure S = PropertySource

  type t = R.real

  fun fromReal (x : real) : R.real = R.fromLarge IEEEReal.TO_NEAREST (Real.toLarge x)
  fun toReal (x : R.real) : real = Real.fromLarge IEEEReal.TO_NEAREST (R.toLarge x)

  val binary64 = R.radix = 2 andalso R.precision = 53

  val zero = R.fromInt 0
  val one = R.fromInt 1
  val two = R.fromInt 2
  fun pow2 (k : int) : R.real = R.fromManExp {man = one, exp = k}
  val top = pow2 R.precision
  val specials : R.real vector =
    Vector.fromList [zero, R.~ zero, R.posInf, R.negInf, R./ (zero, zero), R.minPos,
                     R.nextAfter (R.minNormalPos, zero), R.minNormalPos, R.maxFinite, one, R.~ one,
                     R./ (one, two), top, R.nextAfter (top, R.posInf)]

  (* the exponents of normal reals, as toManExp gives them *)
  val maxExp = #exp (R.toManExp R.maxFinite)
  val minExp = #exp (R.toManExp R.minNormalPos)
  val significands = Word64.<< (0w1, Word.fromInt (R.precision - 1))

  fun uniformBelow (n : Word64.word) (r : Word64.word) : Word64.word = #1 (Random.below n (Random.fromSeed r))

  fun sampler (size : int) (r : Word64.word) : Word64.word =
    let
      val g = Random.fromSeed r
      val (family, g) = Random.below 0w3 g
      val (x, g) = Random.word64 g
      val (y, g) = Random.word64 g
      val (negative, _) = Random.bool g
      fun signed v = if negative then R.~ v else v
      val v =
        case family of
          0w0 => Vector.sub (specials, Word64.toInt (uniformBelow (Word64.fromInt (Vector.length specials)) x))
        | 0w1 => R./ (R.fromInt (#1 (Random.int (~2 * size, 2 * size) (Random.fromSeed x))), two)
        | _ =>
            let
              (* one exponent of the subnormals, those of the normals, and
                 one of infinity and the NaNs *)
              val e = Word64.toInt (uniformBelow (Word64.fromInt (maxExp - minExp + 3)) x)
              val m = uniformBelow significands y
              val frac = R./ (R.fromLargeInt (Word64.toLargeInt m), R.fromLargeInt (Word64.toLargeInt significands))
            in
              signed (if e = 0 then R.* (frac, R.minNormalPos)
                      else if e = maxExp - minExp + 2 then (if m = 0w0 then R.posInf else R./ (zero, zero))
                      else R.fromManExp {man = R./ (R.+ (one, frac), two), exp = minExp + e - 1})
            end
    in
      S.bitsOf (toReal v)
    end

  val gen : R.real Gen.gen =
    if binary64 then Gen.map fromReal Gen.real
    else Gen.primitive (fn (s, a) => fromReal (S.realOf (S.readIn (s, a, S.RealNode, 0w0, sampler (S.size s)))))

  fun show (x : R.real) : string =
    if R.isNan x then "0.0 / 0.0"
    else if R.isFinite x then R.fmt (StringCvt.GEN (SOME 17)) x
    else if R.signBit x then "~1.0 / 0.0"
    else "1.0 / 0.0"

  val arb : R.real Arb.arb =
    {gen = gen, show = show, co = fn x => S.bitsOf (toReal x),
     eq = SOME (fn (x, y) => (R.isNan x andalso R.isNan y) orelse S.bitsOf (toReal x) = S.bitsOf (toReal y))}
end

(* The arbitrary of the characters of a structure of `CHAR`, by the generator
   principle P5, as `Gen.code` draws their codes.

   Area: Property testing *)
functor CharArbFn (C : CHAR) : ARB_OF where type t = C.char =
struct
  type t = C.char

  val arb : C.char Arb.arb =
    {gen = Gen.map C.chr (Gen.code C.maxOrd), show = fn c => "#\"" ^ C.toString c ^ "\"",
     co = fn c => Word64.fromInt (C.ord c), eq = SOME (op =)}
end

(* The arbitrary of the strings of a structure of `STRING`: lists of the
   characters of `char`, by the generator principle P6.

   Area: Property testing *)
functor StringArbFn (structure S : STRING val char : S.char Arb.arb) : ARB_OF where type t = S.string =
struct
  type t = S.string

  val arb : S.string Arb.arb =
    {gen = Gen.map S.implode (Gen.list (#gen char)), show = fn s => "\"" ^ S.toString s ^ "\"",
     co = fn s => Co.list (#co char) (S.explode s), eq = SOME (op =)}
end

(* The rows and columns of a two-dimensional array: each drawn as a length
   is, at the square root of the size, so that there are about as many
   elements as the size allows; an array with no rows has no columns. *)
structure PropertyDimensions =
struct
  fun isqrt (n : int) : int = let fun go k = if (k + 1) * (k + 1) > n then k else go (k + 1) in go 0 end

  val dims : (int * int) Gen.gen =
    Gen.map (fn (r, c) => (r, if r = 0 then 0 else c))
      (Gen.sized (fn n => Gen.resize (isqrt n) (Gen.pair (Gen.map List.length (Gen.list Gen.unit),
                                                            Gen.map List.length (Gen.list Gen.unit)))))

  (* start and length of a slice of n elements, both simplest at 0 *)
  fun slice (n : int) : (int * int) Gen.gen =
    Gen.bind (Gen.intRange (0, n)) (fn i => Gen.map (fn m => (i, m)) (Gen.intRange (0, n - i)))
end

(* The arbitrary of the substrings of a structure of `SUBSTRING`: a string of
   `string`, and a start and a length within it. `name` is the structure's
   name, which the printer writes.

   Two substrings are equal when their strings are and their starts and
   lengths are the same (docs/plans/quickcheck.md, D6).

   Area: Property testing *)
functor SubstringArbFn (structure S : SUBSTRING val string : S.string Arb.arb val name : string)
  : ARB_OF where type t = S.substring =
struct
  type t = S.substring

  val arb : S.substring Arb.arb =
    {gen = Gen.bind (#gen string) (fn s => Gen.map (fn (i, m) => S.substring (s, i, m))
                                                   (PropertyDimensions.slice (S.size (S.full s)))),
     show = fn ss => let val (s, i, n) = S.base ss
                     in name ^ ".substring (" ^ #show string s ^ ", " ^ Int.toString i ^ ", " ^ Int.toString n ^ ")" end,
     co = fn ss => let val (s, i, n) = S.base ss in Co.triple (#co string, Co.int, Co.int) (s, i, n) end,
     eq = SOME (fn (x, y) => let val (s, i, n) = S.base x val (s', i', n') = S.base y
                             in i = i' andalso n = n' andalso Arb.equal string (s, s') end)}
end

(* The arbitrary of the vectors of a structure of `MONO_VECTOR`: lists of
   `elem`, by the generator principle P6. `name` is the structure's name,
   which the printer writes.

   Area: Property testing *)
functor MonoVectorArbFn (structure V : MONO_VECTOR val elem : V.elem Arb.arb val name : string)
  : ARB_OF where type t = V.vector =
struct
  type t = V.vector

  fun elems v = V.foldr (op ::) [] v

  val arb : V.vector Arb.arb =
    {gen = Gen.map V.fromList (Gen.list (#gen elem)), show = fn v => name ^ ".fromList " ^ Show.list (#show elem) (elems v),
     co = fn v => Co.list (#co elem) (elems v),
     eq = SOME (fn (v, w) => ListPair.allEq (Arb.equal elem) (elems v, elems w))}
end

(* The arbitrary of the arrays of a structure of `MONO_ARRAY`, as
   `MonoVectorArbFn` draws vectors: a fresh array at every draw, compared by
   its elements.

   Area: Property testing *)
functor MonoArrayArbFn (structure A : MONO_ARRAY val elem : A.elem Arb.arb val name : string)
  : ARB_OF where type t = A.array =
struct
  type t = A.array

  fun elems v = A.foldr (op ::) [] v

  val arb : A.array Arb.arb =
    {gen = Gen.map A.fromList (Gen.list (#gen elem)), show = fn v => name ^ ".fromList " ^ Show.list (#show elem) (elems v),
     co = fn v => Co.list (#co elem) (elems v),
     eq = SOME (fn (v, w) => ListPair.allEq (Arb.equal elem) (elems v, elems w))}
end

(* The arbitrary of the slices of a structure of `MONO_VECTOR_SLICE`: a
   vector of `vector`, and a start and a length within it, compared as
   `Arb.vectorSlice` compares slices. `name` is the structure's name.

   Area: Property testing *)
functor MonoVectorSliceArbFn (structure S : MONO_VECTOR_SLICE val vector : S.vector Arb.arb val name : string)
  : ARB_OF where type t = S.slice =
struct
  type t = S.slice

  val arb : S.slice Arb.arb =
    {gen = Gen.bind (#gen vector) (fn v => Gen.map (fn (i, m) => S.slice (v, i, SOME m))
                                                   (PropertyDimensions.slice (S.length (S.full v)))),
     show = fn sl => let val (v, i, n) = S.base sl
                     in name ^ ".slice (" ^ #show vector v ^ ", " ^ Int.toString i ^ ", SOME " ^ Int.toString n ^ ")" end,
     co = fn sl => let val (v, i, n) = S.base sl in Co.triple (#co vector, Co.int, Co.int) (v, i, n) end,
     eq = SOME (fn (x, y) => let val (v, i, n) = S.base x val (v', i', n') = S.base y
                             in i = i' andalso n = n' andalso Arb.equal vector (v, v') end)}
end

(* The arbitrary of the slices of a structure of `MONO_ARRAY_SLICE`, as
   `MonoVectorSliceArbFn` draws them, over a fresh array of `array` at every
   draw. `name` is the structure's name.

   Area: Property testing *)
functor MonoArraySliceArbFn (structure S : MONO_ARRAY_SLICE val array : S.array Arb.arb val name : string)
  : ARB_OF where type t = S.slice =
struct
  type t = S.slice

  val arb : S.slice Arb.arb =
    {gen = Gen.bind (#gen array) (fn v => Gen.map (fn (i, m) => S.slice (v, i, SOME m))
                                                  (PropertyDimensions.slice (S.length (S.full v)))),
     show = fn sl => let val (v, i, n) = S.base sl
                     in name ^ ".slice (" ^ #show array v ^ ", " ^ Int.toString i ^ ", SOME " ^ Int.toString n ^ ")" end,
     co = fn sl => let val (v, i, n) = S.base sl in Co.triple (#co array, Co.int, Co.int) (v, i, n) end,
     eq = SOME (fn (x, y) => let val (v, i, n) = S.base x val (v', i', n') = S.base y
                             in i = i' andalso n = n' andalso Arb.equal array (v, v') end)}
end

(* The arbitrary of the two-dimensional arrays of a structure of
   `MONO_ARRAY2`, as `Arb.array2` draws them. `name` is the structure's name.

   Area: Property testing *)
functor MonoArray2ArbFn (structure A : MONO_ARRAY2 val elem : A.elem Arb.arb val name : string)
  : ARB_OF where type t = A.array =
struct
  type t = A.array

  fun rows arr = List.tabulate (A.nRows arr, fn i => List.tabulate (A.nCols arr, fn j => A.sub (arr, i, j)))

  val arb : A.array Arb.arb =
    {gen = Gen.bind PropertyDimensions.dims (fn (r, c) =>
             Gen.map (fn l => A.tabulate Array2.RowMajor (r, c, fn (i, j) => List.nth (l, i * c + j)))
                     (Gen.listOf (Gen.return (r * c)) (#gen elem))),
     show = fn arr => name ^ ".fromList " ^ Show.list (Show.list (#show elem)) (rows arr),
     co = fn arr => Co.list (Co.list (#co elem)) (rows arr),
     eq = SOME (fn (x, y) => A.dimensions x = A.dimensions y
                             andalso ListPair.allEq (ListPair.allEq (Arb.equal elem)) (rows x, rows y))}
end
