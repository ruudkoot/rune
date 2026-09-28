(* The shrinker and generated functions of lib/test/property
   (docs/plans/quickcheck.md, M5): the five problems of the shrinking
   challenge (github.com/jlink/shrinking-challenge) and planted bugs, each
   over seeds 1 to 10, must shrink to their known minima (up to sign: under
   zigzag ~1 is simpler than 1); and the kinds of generated functions of D5.
   One line PASS or FAIL for each, a PASS with the runs of the property that
   the seeds' shrinks took. *)
val failed = ref 0
fun fail name = (print ("FAIL " ^ name ^ "\n"); failed := !failed + 1)
fun check (name, holds) = if holds () handle _ => false then print ("PASS " ^ name ^ "\n") else fail name

val seeds = List.tabulate (10, fn i => i + 1)

(* the shrunk counterexample of p with the seed s, as shown, and the runs
   the shrink took *)
fun shrunk (p : Prop.prop) (s : int) : string list * int =
  case Check.check {seed = SOME (Word64.fromInt s), tests = 10000, maxSize = 100, maxDiscards = 1000,
                    maxShrinks = 5000, exhaustiveBelow = 65536, smallScope = 0} "shrink" p of
    Check.Failed {counterexample, shrinks, ...} => (counterexample, shrinks)
  | _ => (["(no failure)"], 0)

(* p shrinks to the minimum for every seed *)
fun minimum (name, p, want) =
  let
    val got = List.map (shrunk p) seeds
    val wrong = List.filter (fn (c, _) => c <> [want]) got
    val runs = List.map #2 got
  in
    if List.null wrong then
      print ("PASS " ^ name ^ ": " ^ want ^ " for seeds 1 to 10, in " ^ Int.toString (List.foldl Int.min 5000 runs)
             ^ " to " ^ Int.toString (List.foldl Int.max 0 runs) ^ " runs\n")
    else fail (name ^ ": " ^ String.concatWith " " (List.map (fn (c, _) => String.concatWith ", " c) wrong))
  end

val ints = Arb.list Arb.int
fun distinct l = List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else x :: acc) [] l

(* ---- the shrinking challenge ---- *)

val () = minimum ("challenge/reverse", Prop.forAll ints (fn l => Prop.holds (rev l = l)), "[0, ~1]")

val () = minimum ("challenge/distinct", Prop.forAll ints (fn l => Prop.holds (List.length (distinct l) < 3)), "[0, ~1, 1]")

(* 1 to 100 elements of 0 to 1000, drawn by listOf with no marks *)
val lengthList : int list Arb.arb =
  {gen = Gen.listOf (Gen.intRange (1, 100)) (Gen.intRange (0, 1000)), show = Show.list Show.int,
   co = Co.list Co.int, eq = SOME (op =)}
val () = minimum ("challenge/length-list", Prop.forAll lengthList (fn l => Prop.holds (List.foldl Int.max 0 l < 900)), "[900]")

val lists = Arb.list ints
val () = minimum ("challenge/large-union-list",
                  Prop.forAll lists (fn ls => Prop.holds (List.length (distinct (List.concat ls)) <= 4)),
                  "[[0, ~1, 1, ~2, 2]]")
val () = minimum ("challenge/nested-lists",
                  Prop.forAll lists (fn ls => Prop.holds (List.foldl (fn (l, n) => n + List.length l) 0 ls <= 10)),
                  "[[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]")

(* ---- planted bugs ---- *)

(* an `all` that never looks at the last element: p a constant false, and [0] *)
fun badAll p [] = true | badAll p [_] = true | badAll p (x :: xs) = p x andalso badAll p xs
val () = minimum ("planted/all-skips-the-last",
                  Prop.forAll (Arb.pair (Arb.pureFunction (Arb.int, Arb.bool), ints))
                              (fn (p, l) => Prop.holds (badAll p l = List.all p l)),
                  "(fn, [0])")

(* an insertion sort that drops equal elements: [0, 0] *)
fun insert (x, []) = [x]
  | insert (x, y :: ys) = if x < y then x :: y :: ys else if x = y then y :: ys else y :: insert (x, ys)
val () = minimum ("planted/sort-drops-equals",
                  Prop.forAll ints (fn l => Prop.holds (List.length (List.foldl insert [] l) = List.length l)),
                  "[0, 0]")

(* a map that calls f from the right: only an effect-observing f sees it,
   at two elements that differ *)
fun badMap f [] = [] | badMap f (x :: xs) = let val ys = badMap f xs in f x :: ys end
val () = minimum ("planted/map-calls-from-the-right",
                  Prop.law (Arb.pair (Arb.function (Arb.int, Arb.int), ints), ints)
                           (fn (f, l) => List.map f l, fn (f, l) => badMap f l),
                  "(fn, [0, ~1])")

(* ---- generated functions: the kinds of D5 ---- *)

(* a raising function is drawn, and its exception is the failure's class *)
val () = check ("functions/raising-is-drawn", fn () =>
  case Check.check Check.default "raising"
         (Prop.forAll (Arb.pair (Arb.function (Arb.int, Arb.int), Arb.int)) (fn (f, x) => Prop.holds (f x = f x))) of
    Check.Failed {class, counterexample, ...} => class = "exception Generated" andalso counterexample = ["(fn, 0)"]
  | _ => false)
(* the exception is an outcome: both sides raise it *)
val () = check ("functions/a-raise-is-an-outcome", fn () =>
  Check.passed (Check.check Check.default "raise"
    (Prop.forAll (Arb.pair (Arb.function (Arb.int, Arb.int), Arb.int))
                 (fn (f, x) => Prop.equal Arb.int (fn () => f x, fn () => f x)))))
(* calling f twice on one side and once on the other is seen by an
   effect-observing f *)
val () = check ("functions/effects-are-compared", fn () =>
  case Check.check Check.default "effects"
         (Prop.law (Arb.pair (Arb.function (Arb.int, Arb.int), Arb.int), Arb.int)
                   (fn (f, x) => f x, fn (f, x) => (ignore (f x); f x))) of
    Check.Failed {class, ...} => class = "effects differ"
  | _ => false)
(* the same law with a pure function holds *)
val () = check ("functions/pure-has-no-effects", fn () =>
  Check.passed (Check.check Check.default "pure"
    (Prop.law (Arb.pair (Arb.pureFunction (Arb.int, Arb.int), Arb.int), Arb.int)
              (fn (f, x) => f x, fn (f, x) => (ignore (f x); f x)))))
(* the report shows a function's calls, shrunk *)
val () = check ("functions/calls-are-reported", fn () =>
  case Check.check Check.default "calls"
         (Prop.forAll (Arb.pair (Arb.pureFunction (Arb.int, Arb.bool), ints))
                      (fn (p, l) => Prop.holds (badAll p l = List.all p l))) of
    Check.Failed {calls, ...} => calls = [["0 => false"]]
  | _ => false)

val () = if !failed = 0 then () else OS.Process.exit OS.Process.failure
