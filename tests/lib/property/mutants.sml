(* Mutant calibration (docs/plans/quickcheck.md, M6): copies of members of
   List, Int8 and Substring with one mutation each (an off-by-one bound,
   swapped arguments or results, a dropped exception, a wrong sign), and
   properties written for this test, not the documentation's laws, that
   compare each copy with the Basis Library's member by outcome. With no
   mutation every property must hold; with each mutation some property of
   its family must fail. One line KILLED or SURVIVED for each mutant, and one
   line PASS or FAIL for each family with its kill rate. *)
val mutant = ref ""
fun is m = !mutant = m

(* ---- the copies, each mutation switched on by its name ---- *)

structure MList =
struct
  fun nth (l : int list, i : int) : int =
    let
      fun go (x :: _, 0) = x
        | go (_ :: rest, k) = go (rest, k - 1)
        | go ([], _) = raise Subscript
    in
      if i < 0 then raise Subscript else go (l, if is "List.nth/off-by-one" then i + 1 else i)
    end
  fun take (l : int list, n : int) : int list =
    let
      fun go (_, 0) = []
        | go (x :: rest, k) = x :: go (rest, k - 1)
        | go ([], _) = if is "List.take/dropped-exception" then [] else raise Subscript
    in
      if n < 0 then raise Subscript else go (l, n)
    end
  fun drop (l : int list, n : int) : int list =
    let
      fun go (l, 0) = l
        | go (_ :: rest, k) = go (rest, k - 1)
        | go ([], _) = raise Subscript
    in
      if n < 0 andalso not (is "List.drop/wrong-sign") then raise Subscript else go (l, Int.abs n)
    end
  fun tabulate (n : int, f : int -> int) : int list =
    if n < 0 then raise Size
    else List.map f (List.tabulate (if is "List.tabulate/off-by-one" then Int.max (n - 1, 0) else n, fn i => i))
  fun foldl (f : int * int -> int) (b : int) (l : int list) : int =
    case l of
      [] => b
    | x :: rest => foldl f (if is "List.foldl/swapped-arguments" then f (b, x) else f (x, b)) rest
  fun partition (p : int -> bool) (l : int list) : int list * int list =
    let val (a, b) = List.foldr (fn (x, (a, b)) => if p x then (x :: a, b) else (a, x :: b)) ([], []) l
    in if is "List.partition/swapped-results" then (b, a) else (a, b) end
end

(* Int8 in an int *)
structure MInt8 =
struct
  val lo = ~128
  fun check (v : int) : int = if v < lo orelse v > 127 + (if is "Int8.fromInt/off-by-one" then 1 else 0) then raise Overflow else v
  fun fromInt (v : int) : int = check v
  fun add (i : int, j : int) : int = if is "Int8.+/dropped-exception" then (i + j - lo) mod 256 + lo else check (i + j)
  fun sub (i : int, j : int) : int = check (if is "Int8.-/swapped-arguments" then j - i else i - j)
  fun divide (i : int, j : int) : int = check (if is "Int8.div/wrong-sign" then Int.quot (i, j) else i div j)
  fun abs (i : int) : int = if is "Int8.abs/dropped-exception" andalso i = lo then lo else check (Int.abs i)
  fun sign (i : int) : int = if is "Int8.sign/wrong-sign" then ~ (Int.sign i) else Int.sign i
end

(* a substring as its string, start and length *)
structure MSubstring =
struct
  fun substring (s : string, i : int, n : int) : string * int * int =
    (* i + n could overflow: compare with what is left after i *)
    if i < 0 orelse n < 0 orelse i > String.size s
       orelse n > String.size s - i + (if is "Substring.substring/off-by-one" then 1 else 0)
    then raise Subscript
    else (s, i, n)
  fun sub ((s, i, n) : string * int * int, k : int) : char =
    if k < 0 orelse k >= n then raise Subscript
    else String.sub (s, i + (if is "Substring.sub/off-by-one" then k + 1 else k))
  fun triml (k : int) ((s, i, n) : string * int * int) : string * int * int =
    if k < 0 andalso not (is "Substring.triml/dropped-exception") then raise Subscript
    else let val k = Int.min (Int.max (k, 0), n) in (s, i + k, n - k) end
  fun splitAt ((s, i, n) : string * int * int, k : int) : (string * int * int) * (string * int * int) =
    if k < 0 orelse k > n then raise Subscript
    else if is "Substring.splitAt/swapped-results" then ((s, i + k, n - k), (s, i, k))
    else ((s, i, k), (s, i + k, n - k))
  fun isPrefix (p : string) ((s, i, n) : string * int * int) : bool =
    if is "Substring.isPrefix/swapped-arguments" then String.isPrefix (String.substring (s, i, n)) p
    else String.isPrefix p (String.substring (s, i, n))
  fun string ((s, i, n) : string * int * int) : string = String.substring (s, i, n)
end

(* ---- the properties: each copy against the Basis's member ---- *)

val int = IntArb.arb
val ints = Arb.list int
val bool = Arb.bool
val str = StringArb.arb
val i8 = Int8Arb.arb
val sub = SubstringArb.arb
val count : int Arb.arb = {gen = Gen.intRange (~2, 40), show = Show.int, co = Co.int, eq = SOME (op =)}
fun same a (l, r) = Prop.equal a (l, r)
fun int8 (f : Int8.int * Int8.int -> Int8.int) (i : Int8.int, j : Int8.int) : int = Int8.toInt (f (i, j))
val i8s = Arb.pair (i8, i8)
fun pair2 (i, j) = (Int8.toInt i, Int8.toInt j)

val families =
  [("List",
    ["List.nth/off-by-one", "List.take/dropped-exception", "List.drop/wrong-sign", "List.tabulate/off-by-one",
     "List.foldl/swapped-arguments", "List.partition/swapped-results"],
    [("nth", Prop.forAll (Arb.pair (ints, int)) (fn (l, i) => same int (fn () => MList.nth (l, i), fn () => List.nth (l, i)))),
     ("take", Prop.forAll (Arb.pair (ints, int)) (fn (l, n) => same ints (fn () => MList.take (l, n), fn () => List.take (l, n)))),
     ("drop", Prop.forAll (Arb.pair (ints, int)) (fn (l, n) => same ints (fn () => MList.drop (l, n), fn () => List.drop (l, n)))),
     ("tabulate", Prop.forAll (Arb.pair (count, Arb.pureFunction (int, int)))
                    (fn (n, f) => same ints (fn () => MList.tabulate (n, f), fn () => List.tabulate (n, f)))),
     ("foldl", Prop.forAll (Arb.triple (Arb.pureFunction (Arb.pair (int, int), int), int, ints))
                 (fn (f, b, l) => same int (fn () => MList.foldl f b l, fn () => List.foldl f b l))),
     ("partition", Prop.forAll (Arb.pair (Arb.pureFunction (int, bool), ints))
                     (fn (p, l) => same (Arb.pair (ints, ints)) (fn () => MList.partition p l, fn () => List.partition p l)))]),
   ("Int8",
    ["Int8.fromInt/off-by-one", "Int8.+/dropped-exception", "Int8.-/swapped-arguments", "Int8.div/wrong-sign",
     "Int8.abs/dropped-exception", "Int8.sign/wrong-sign"],
    [("fromInt", Prop.forAll int (fn v => same int (fn () => MInt8.fromInt v, fn () => Int8.toInt (Int8.fromInt v)))),
     ("+", Prop.forAll i8s (fn p => same int (fn () => MInt8.add (pair2 p), fn () => int8 Int8.+ p))),
     ("-", Prop.forAll i8s (fn p => same int (fn () => MInt8.sub (pair2 p), fn () => int8 Int8.- p))),
     ("div", Prop.forAll i8s (fn p => same int (fn () => MInt8.divide (pair2 p), fn () => int8 Int8.div p))),
     ("abs", Prop.forAll i8 (fn i => same int (fn () => MInt8.abs (Int8.toInt i), fn () => Int8.toInt (Int8.abs i)))),
     ("sign", Prop.forAll i8 (fn i => same int (fn () => MInt8.sign (Int8.toInt i), fn () => Int8.sign i)))]),
   ("Substring",
    ["Substring.substring/off-by-one", "Substring.sub/off-by-one", "Substring.triml/dropped-exception",
     "Substring.splitAt/swapped-results", "Substring.isPrefix/swapped-arguments"],
    [("substring", Prop.forAll (Arb.triple (str, int, int)) (fn (s, i, n) =>
       same int (fn () => #3 (MSubstring.substring (s, i, n)), fn () => Substring.size (Substring.substring (s, i, n))))),
     ("sub", Prop.forAll (Arb.pair (sub, int)) (fn (ss, k) =>
       same CharArb.arb (fn () => MSubstring.sub (Substring.base ss, k), fn () => Substring.sub (ss, k)))),
     ("triml", Prop.forAll (Arb.pair (sub, int)) (fn (ss, k) =>
       same str (fn () => MSubstring.string (MSubstring.triml k (Substring.base ss)),
                 fn () => Substring.string (Substring.triml k ss)))),
     ("splitAt", Prop.forAll (Arb.pair (sub, int)) (fn (ss, k) =>
       same (Arb.pair (str, str))
            (fn () => let val (a, b) = MSubstring.splitAt (Substring.base ss, k) in (MSubstring.string a, MSubstring.string b) end,
             fn () => let val (a, b) = Substring.splitAt (ss, k) in (Substring.string a, Substring.string b) end))),
     ("isPrefix", Prop.forAll (Arb.pair (str, sub)) (fn (p, ss) =>
       same bool (fn () => MSubstring.isPrefix p (Substring.base ss), fn () => Substring.isPrefix p ss)))])]

(* ---- the calibration ---- *)

val failed = ref 0

(* the name of the first property that fails, if one does *)
fun killer (props : (string * Prop.prop) list) : string option =
  Option.map #1 (List.find (fn (name, p) => not (Check.passed (Check.check Check.default name p))) props)

fun calibrate (family, mutants, props) =
  let
    val () = mutant := ""
    val sane = case killer props of
                 NONE => true
               | SOME name => (print ("FAIL " ^ family ^ ": " ^ name ^ " fails with no mutation\n"); false)
    val killed =
      List.filter (fn m =>
                     let val () = mutant := m
                     in
                       case killer props of
                         SOME name => (print ("KILLED " ^ m ^ " by " ^ name ^ "\n"); true)
                       | NONE => (print ("SURVIVED " ^ m ^ "\n"); false)
                     end)
                  mutants
    val () = mutant := ""
    val all = List.length killed = List.length mutants
  in
    if sane andalso all then
      print ("PASS " ^ family ^ ": " ^ Int.toString (List.length killed) ^ " of " ^ Int.toString (List.length mutants)
             ^ " mutants killed\n")
    else
      (print ("FAIL " ^ family ^ ": " ^ Int.toString (List.length killed) ^ " of " ^ Int.toString (List.length mutants)
              ^ " mutants killed\n");
       failed := !failed + 1)
  end

val () = List.app calibrate families
val () = if !failed = 0 then () else OS.Process.exit OS.Process.failure
