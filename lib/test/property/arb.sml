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

  fun function (a : 'a arb, b : 'b arb) : ('a -> 'b) arb =
    {gen = Gen.functionOf (#co a, #show a, #show b, #gen b), show = fn _ => "fn", co = fn _ => 0w0, eq = NONE}

  fun pureFunction (a : 'a arb, b : 'b arb) : ('a -> 'b) arb =
    {gen = Gen.pureOf (#co a, #show a, #show b, #gen b), show = fn _ => "fn", co = fn _ => 0w0, eq = NONE}
end
