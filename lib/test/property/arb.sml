(* The arbitraries of the Basis Library's simple types (docs/plans/quickcheck.md,
   D4 and M4). *)

(* Implements: ARB *)
structure Arb :> ARB =
struct
  type 'a arb = {gen : 'a Gen.gen, show : 'a -> string, co : 'a -> Word64.word,
                 eq : ('a * 'a -> bool) option}

  fun equal ({show, eq, ...} : 'a arb) (x : 'a, y : 'a) : bool =
    case eq of SOME e => e (x, y) | NONE => show x = show y

  val int : int arb = {gen = Gen.int, show = Show.int, co = Co.int, eq = SOME (op =)}
  val word : word arb = {gen = Gen.word, show = Show.word, co = Co.word, eq = SOME (op =)}
  val word64 : Word64.word arb = {gen = Gen.word64, show = Show.word64, co = Co.word64, eq = SOME (op =)}
  val char : char arb = {gen = Gen.char, show = Show.char, co = Co.char, eq = SOME (op =)}
  val string : string arb = {gen = Gen.string, show = Show.string, co = Co.string, eq = SOME (op =)}
  val real : real arb = {gen = Gen.real, show = Show.real, co = Co.real,
                         eq = SOME (fn (x, y) => Co.real x = Co.real y orelse (Real.isNan x andalso Real.isNan y))}
  val bool : bool arb = {gen = Gen.bool, show = Show.bool, co = Co.bool, eq = SOME (op =)}
  val unit : unit arb = {gen = Gen.unit, show = Show.unit, co = Co.unit, eq = SOME (op =)}
  val order : order arb = {gen = Gen.order, show = Show.order, co = Co.order, eq = SOME (op =)}

  fun option (a : 'a arb) : 'a option arb =
    {gen = Gen.option (#gen a), show = Show.option (#show a), co = Co.option (#co a),
     eq = SOME (fn (NONE, NONE) => true | (SOME x, SOME y) => equal a (x, y) | _ => false)}

  fun list (a : 'a arb) : 'a list arb =
    {gen = Gen.list (#gen a), show = Show.list (#show a), co = Co.list (#co a),
     eq = SOME (fn (l, m) => ListPair.allEq (equal a) (l, m))}

  fun vector (a : 'a arb) : 'a vector arb =
    {gen = Gen.vector (#gen a), show = Show.vector (#show a),
     co = fn v => Co.list (#co a) (Vector.foldr (op ::) [] v),
     eq = SOME (fn (v, w) => ListPair.allEq (equal a) (Vector.foldr (op ::) [] v, Vector.foldr (op ::) [] w))}

  fun array (a : 'a arb) : 'a array arb =
    {gen = Gen.array (#gen a), show = Show.array (#show a),
     co = fn v => Co.list (#co a) (Array.foldr (op ::) [] v),
     eq = SOME (fn (v, w) => ListPair.allEq (equal a) (Array.foldr (op ::) [] v, Array.foldr (op ::) [] w))}

  fun pair (a : 'a arb, b : 'b arb) : ('a * 'b) arb =
    {gen = Gen.pair (#gen a, #gen b), show = Show.pair (#show a, #show b), co = Co.pair (#co a, #co b),
     eq = SOME (fn ((x, y), (x', y')) => equal a (x, x') andalso equal b (y, y'))}

  fun triple (a : 'a arb, b : 'b arb, c : 'c arb) : ('a * 'b * 'c) arb =
    {gen = Gen.triple (#gen a, #gen b, #gen c), show = Show.triple (#show a, #show b, #show c),
     co = Co.triple (#co a, #co b, #co c),
     eq = SOME (fn ((x, y, z), (x', y', z')) => equal a (x, x') andalso equal b (y, y') andalso equal c (z, z'))}

  val intInf : IntInf.int arb =
    {gen = Gen.intInf, show = IntInf.toString, co = fn i => Random.hashString (IntInf.toString i), eq = SOME (op =)}

  fun intRange (lo : int, hi : int) : int arb =
    {gen = Gen.intRange (lo, hi), show = Show.int, co = Co.int, eq = SOME (op =)}

  fun wordRange (lo : word, hi : word) : word arb =
    {gen = Gen.map (fn i => Word.fromLargeInt i) (Gen.largeRange (Word.toLargeInt lo, Word.toLargeInt hi)),
     show = Show.word, co = Co.word, eq = SOME (op =)}

  fun reference (a : 'a arb) : 'a ref arb =
    {gen = Gen.map ref (#gen a), show = fn r => "ref " ^ Show.parens (#show a (!r)), co = fn r => #co a (!r),
     eq = SOME (op =)}

  fun enum (xs : (''a * string) list) : ''a arb =
    let
      fun index x = let fun go (_, []) = 0 | go (i, (y, _) :: rest) = if x = y then i else go (i + 1, rest) in go (0, xs) end
    in
      {gen = Gen.elements (Vector.fromList (List.map #1 xs)),
       show = fn x => case List.find (fn (y, _) => x = y) xs of SOME (_, n) => n | NONE => "?",
       co = fn x => Word64.fromInt (index x), eq = SOME (op =)}
    end

  (* a slice of what the base draws: a start and a length within it, both
     simplest at 0 *)
  fun sliceOf (base : 'b Gen.gen, length : 'b -> int, make : 'b * int * int -> 's) : 's Gen.gen =
    Gen.bind base (fn b =>
      let val n = length b
      in Gen.bind (Gen.intRange (0, n)) (fn i => Gen.map (fn m => make (b, i, m)) (Gen.intRange (0, n - i))) end)

  fun vectorSlice (a : 'a arb) : 'a VectorSlice.slice arb =
    let
      fun parts sl = let val (v, i, n) = VectorSlice.base sl in (Vector.foldr (op ::) [] v, i, n) end
    in
      {gen = sliceOf (Gen.vector (#gen a), Vector.length, fn (v, i, m) => VectorSlice.slice (v, i, SOME m)),
       show = fn sl => let val (v, i, n) = VectorSlice.base sl
                       in "VectorSlice.slice (" ^ Show.vector (#show a) v ^ ", " ^ Int.toString i ^ ", SOME " ^ Int.toString n ^ ")" end,
       co = fn sl => let val (l, i, n) = parts sl in Co.triple (Co.list (#co a), Co.int, Co.int) (l, i, n) end,
       eq = SOME (fn (x, y) => let val (l, i, n) = parts x val (l', i', n') = parts y
                               in i = i' andalso n = n' andalso ListPair.allEq (equal a) (l, l') end)}
    end

  fun arraySlice (a : 'a arb) : 'a ArraySlice.slice arb =
    let
      fun parts sl = let val (v, i, n) = ArraySlice.base sl in (Array.foldr (op ::) [] v, i, n) end
    in
      {gen = sliceOf (Gen.array (#gen a), Array.length, fn (v, i, m) => ArraySlice.slice (v, i, SOME m)),
       show = fn sl => let val (v, i, n) = ArraySlice.base sl
                       in "ArraySlice.slice (" ^ Show.array (#show a) v ^ ", " ^ Int.toString i ^ ", SOME " ^ Int.toString n ^ ")" end,
       co = fn sl => let val (l, i, n) = parts sl in Co.triple (Co.list (#co a), Co.int, Co.int) (l, i, n) end,
       eq = SOME (fn (x, y) => let val (l, i, n) = parts x val (l', i', n') = parts y
                               in i = i' andalso n = n' andalso ListPair.allEq (equal a) (l, l') end)}
    end

  fun isqrt (n : int) : int = let fun go k = if (k + 1) * (k + 1) > n then k else go (k + 1) in go 0 end

  (* rows and columns each by the rule of lengths at the square root of the
     size, so that there are about as many elements as the size allows; an
     array of no rows has no columns *)
  fun array2 (a : 'a arb) : 'a Array2.array arb =
    let
      fun rows arr = List.tabulate (Array2.nRows arr, fn i => List.tabulate (Array2.nCols arr, fn j => Array2.sub (arr, i, j)))
      val dims = Gen.sized (fn n => Gen.resize (isqrt n) (Gen.pair (Gen.map List.length (Gen.list Gen.unit),
                                                                     Gen.map List.length (Gen.list Gen.unit))))
    in
      {gen = Gen.bind dims (fn (r, c) =>
               let val c = if r = 0 then 0 else c
               in Gen.map (fn l => Array2.tabulate Array2.RowMajor (r, c, fn (i, j) => List.nth (l, i * c + j)))
                          (Gen.listOf (Gen.return (r * c)) (#gen a))
               end),
       show = fn arr => "Array2.fromList " ^ Show.list (Show.list (#show a)) (rows arr),
       co = fn arr => Co.list (Co.list (#co a)) (rows arr),
       eq = SOME (fn (x, y) => Array2.dimensions x = Array2.dimensions y
                               andalso ListPair.allEq (ListPair.allEq (equal a)) (rows x, rows y))}
    end

  (* the exceptions of the Basis, the library's Generated, and Fail with any
     message *)
  val exns : exn vector =
    Vector.fromList [Overflow, Div, Subscript, Size, Chr, Domain, Empty, Option, Span, Bind, Match, Fail "", Gen.Generated]
  val exn : exn arb =
    {gen = Gen.oneOf [Gen.elements exns, Gen.map Fail Gen.string],
     show = fn Fail m => "Fail " ^ Show.string m | Gen.Generated => "Gen.Generated" | e => exnName e,
     co = fn e => Random.hashString (exnName e ^ "\000" ^ (case e of Fail m => m | _ => "")),
     eq = SOME (fn (e, f) => exnName e = exnName f
                             andalso (case (e, f) of (Fail m, Fail n) => m = n | _ => true))}

  fun function (a : 'a arb, b : 'b arb) : ('a -> 'b) arb =
    {gen = Gen.functionOf (#co a, #show a, #show b, #gen b), show = fn _ => "fn", co = fn _ => 0w0, eq = NONE}

  fun pureFunction (a : 'a arb, b : 'b arb) : ('a -> 'b) arb =
    {gen = Gen.pureOf (#co a, #show a, #show b, #gen b), show = fn _ => "fn", co = fn _ => 0w0, eq = NONE}
end
