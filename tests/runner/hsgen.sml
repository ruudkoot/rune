(* rhc's program generator (D55, the third of its generators; the haskell98
   roadmap's *Generators and metamorphic relations*; docs/testing.md, rhc's
   generated programs): well-typed, terminating Haskell 98 programs drawn
   from a seed, each with the output that the generator's own evaluator gives
   it, from the Report's meaning of what it writes.

   A program is top-level functions of Int arguments, each calling only those
   before it, and a main that prints Int, Bool and [Int] values: arithmetic
   (+, -, * by a literal, div and mod by a literal not 0, negate), compare,
   &&, || and not, if, case on an integer literal, let, a lambda applied, the
   list functions map, filter, foldr, sum, length, take and reverse, and
   [a .. b] of small literals. Laziness is in it too: const e undefined and
   fst (e, undefined) must not force their bottom. No recursion but foldr's
   over a finite list, so every program ends; a draw whose values pass 2^28
   is drawn again, so that Int's range in every implementation holds them.
   Everything is written with full parentheses and type signatures, so that
   no fixity or default decides a value.

   Jobs: hs/generated/@parse (check) puts 32 programs from seed 1 through
   rhc's parser, which runs today; hs/generated/@run (check) compiles and runs
   16 from seed 1 and compares each with its expected output, and
   hs/generated/@nightly (nightly) 400 from seed 1000, held until every row
   the programs need is out of Planned; hs/generated/@orders (nightly) the
   same 400 compiled with `--match=sestoft`, Sestoft's decision trees held to
   the meaning of the Report's top-to-bottom rules (tr.case.obligation, R86). A failure names its seed:
   `bin/rune-test hs-generate SEED` prints that program and its output, and
   `bin/rune-test hs-generated FIRST COUNT` runs any range by hand, and
   `bin/rune-test hs-generated-orders FIRST COUNT` with Sestoft's trees. *)
structure HsGen =
struct
  open Sh

  datatype exp =
      Lit of IntInf.int | Var of string | BLit of bool
    | Add of exp * exp | Sub of exp * exp | Mul of exp * IntInf.int | Div of exp * IntInf.int | Mod of exp * IntInf.int
    | Neg of exp | If of exp * exp * exp | Lt of exp * exp | Eq of exp * exp | And of exp * exp | Or of exp * exp
    | Not of exp | Let of string * exp * exp | Lam of string * exp * exp | Call of string * exp list
    | Case of exp * IntInf.int * exp * string * exp | Const of exp | Fst of exp
    | List of exp list | Range of IntInf.int * IntInf.int | Map of string * exp * exp | Filter of string * exp * exp
    | Sum of exp | Length of exp | Take of IntInf.int * exp | Reverse of exp | Foldr of string * string * exp * exp * exp

  datatype value = I of IntInf.int | B of bool | L of IntInf.int list
  exception TooBig

  type fundef = {name : string, params : string list, body : exp}

  (* ---- the evaluator: the Report's meaning of what is generated *)
  val bound = IntInf.pow (2, 28)
  fun int v = if IntInf.abs v > bound then raise TooBig else I v
  fun eval (funs : fundef list) env e =
    let
      fun ev env e =
        case e of
          Lit n => I n
        | BLit b => B b
        | Var x => #2 (valOf (List.find (fn (y, _) => y = x) env))
        | Add (a, b) => int (i env a + i env b)
        | Sub (a, b) => int (i env a - i env b)
        | Mul (a, k) => int (i env a * k)
        | Div (a, k) => int (IntInf.div (i env a, k))
        | Mod (a, k) => int (IntInf.mod (i env a, k))
        | Neg a => int (~ (i env a))
        | If (c, a, b) => if bl env c then ev env a else ev env b
        | Lt (a, b) => B (i env a < i env b)
        | Eq (a, b) => B (i env a = i env b)
        | And (a, b) => B (bl env a andalso bl env b)
        | Or (a, b) => B (bl env a orelse bl env b)
        | Not a => B (not (bl env a))
        | Let (x, a, b) => ev ((x, ev env a) :: env) b
        | Lam (x, b, a) => ev ((x, ev env a) :: env) b
        | Call (f, args) =>
            let val {params, body, ...} = valOf (List.find (fn (d : fundef) => #name d = f) funs)
            in eval funs (ListPair.zip (params, List.map (ev env) args)) body end
        | Case (s, k, a, x, b) => let val v = i env s in if v = k then ev env a else ev ((x, I v) :: env) b end
        | Const a => ev env a
        | Fst a => ev env a
        | List es => L (List.map (fn e => i env e) es)
        | Range (a, b) => L (if a > b then [] else List.tabulate (IntInf.toInt (b - a) + 1, fn j => a + IntInf.fromInt j))
        | Map (x, b, l) => L (List.map (fn v => i ((x, I v) :: env) b) (lst env l))
        | Filter (x, b, l) => L (List.filter (fn v => bl ((x, I v) :: env) b) (lst env l))
        | Sum l => I (List.foldl (fn (v, a) => case int (a + v) of I n => n | _ => 0) 0 (lst env l))
        | Length l => I (IntInf.fromInt (length (lst env l)))
        | Take (k, l) => L (List.take (lst env l, Int.min (IntInf.toInt k, length (lst env l))))
        | Reverse l => L (List.rev (lst env l))
        | Foldr (x, acc, b, z, l) => List.foldr (fn (v, a) => ev ((x, I v) :: (acc, a) :: env) b) (ev env z) (lst env l)
      and i env e = case ev env e of I n => n | _ => raise Fail "HsGen: not an Int"
      and bl env e = case ev env e of B b => b | _ => raise Fail "HsGen: not a Bool"
      and lst env e = case ev env e of L l => (List.app (ignore o int) l; l) | _ => raise Fail "HsGen: not a list"
    in ev env e end

  (* ---- printing it as Haskell *)
  fun lit n = if n < 0 then "(-" ^ IntInf.toString (~ n) ^ ")" else IntInf.toString n
  fun show e =
    let
      fun p s = "(" ^ s ^ ")"
      fun lam (xs, b) = "(\\" ^ String.concatWith " " xs ^ " -> " ^ show b ^ ")"
    in
      case e of
        Lit n => lit n
      | BLit b => if b then "True" else "False"
      | Var x => x
      | Add (a, b) => p (show a ^ " + " ^ show b)
      | Sub (a, b) => p (show a ^ " - " ^ show b)
      | Mul (a, k) => p (show a ^ " * " ^ lit k)
      | Div (a, k) => p (show a ^ " `div` " ^ lit k)
      | Mod (a, k) => p ("mod " ^ show a ^ " " ^ lit k)
      | Neg a => p ("negate " ^ show a)
      | If (c, a, b) => p ("if " ^ show c ^ " then " ^ show a ^ " else " ^ show b)
      | Lt (a, b) => p (show a ^ " < " ^ show b)
      | Eq (a, b) => p (show a ^ " == " ^ show b)
      | And (a, b) => p (show a ^ " && " ^ show b)
      | Or (a, b) => p (show a ^ " || " ^ show b)
      | Not a => p ("not " ^ show a)
      | Let (x, a, b) => p ("let { " ^ x ^ " = " ^ show a ^ " } in " ^ show b)
      | Lam (x, b, a) => p (lam ([x], b) ^ " " ^ show a)
      | Call (f, args) => p (String.concatWith " " (f :: List.map show args))
      | Case (s, k, a, x, b) => p ("case " ^ show s ^ " of { " ^ IntInf.toString k ^ " -> " ^ show a ^ "; " ^ x ^ " -> " ^ show b ^ " }")
      | Const a => p ("const " ^ show a ^ " (undefined :: Int)")
      | Fst a => p ("fst (" ^ show a ^ ", undefined :: Int)")
      | List es => "[" ^ String.concatWith ", " (List.map show es) ^ "]"
      | Range (a, b) => "[" ^ lit a ^ " .. " ^ lit b ^ "]"
      | Map (x, b, l) => p ("map " ^ lam ([x], b) ^ " " ^ show l)
      | Filter (x, b, l) => p ("filter " ^ lam ([x], b) ^ " " ^ show l)
      | Sum l => p ("sum " ^ show l)
      | Length l => p ("length " ^ show l)
      | Take (k, l) => p ("take " ^ lit k ^ " " ^ show l)
      | Reverse l => p ("reverse " ^ show l)
      | Foldr (x, acc, b, z, l) => p ("foldr " ^ lam ([x, acc], b) ^ " " ^ show z ^ " " ^ show l)
    end
  fun showValue (I n) = if n < 0 then "-" ^ IntInf.toString (~ n) else IntInf.toString n
    | showValue (B b) = if b then "True" else "False"
    | showValue (L l) = "[" ^ String.concatWith "," (List.map (showValue o I) l) ^ "]"

  (* ---- drawing it *)
  fun generate seed =
    let
      (* SplitMix64, as lib/random's, which the runner does not link *)
      val state = ref (Word64.fromInt seed)
      fun next () =
        let
          val () = state := !state + 0wx9e3779b97f4a7c15
          val z = !state
          val z = Word64.xorb (z, Word64.>> (z, 0w30)) * 0wxbf58476d1ce4e5b9
          val z = Word64.xorb (z, Word64.>> (z, 0w27)) * 0wx94d049bb133111eb
        in Word64.xorb (z, Word64.>> (z, 0w31)) end
      fun pick (lo, hi) = lo + Word64.toInt (Word64.mod (next (), Word64.fromInt (hi - lo + 1)))
      fun lit (lo, hi) = IntInf.fromInt (pick (lo, hi))
      val fresh = ref 0
      fun var () = (fresh := !fresh + 1; "v" ^ Int.toString (!fresh))
      fun nonzero () = let val k = pick (~5, 5) in IntInf.fromInt (if k = 0 then 3 else k) end
      fun genI (funs : fundef list, env, d) =
        if d <= 0 orelse pick (0, 9) < 2 then
          (case List.filter (fn _ => true) env of [] => Lit (lit (~9, 20)) | vs => if pick (0, 1) = 0 then Lit (lit (~9, 20)) else Var (List.nth (vs, pick (0, length vs - 1))))
        else
          let val d' = d - 1
          in
            case pick (0, 17) of
              0 => Add (genI (funs, env, d'), genI (funs, env, d'))
            | 1 => Sub (genI (funs, env, d'), genI (funs, env, d'))
            | 2 => Mul (genI (funs, env, d'), lit (~3, 9))
            | 3 => Div (genI (funs, env, d'), nonzero ())
            | 4 => Mod (genI (funs, env, d'), nonzero ())
            | 5 => Neg (genI (funs, env, d'))
            | 6 => If (genB (funs, env, d'), genI (funs, env, d'), genI (funs, env, d'))
            | 7 => let val x = var () in Let (x, genI (funs, env, d'), genI (funs, x :: env, d')) end
            | 8 => let val x = var () in Lam (x, genI (funs, x :: env, d'), genI (funs, env, d')) end
            | 9 => (case funs of
                      [] => Add (genI (funs, env, d'), Lit 1)
                    | _ => let val f = List.nth (funs, pick (0, length funs - 1))
                           in Call (#name f, List.map (fn _ => genI (funs, env, d')) (#params f)) end)
            | 10 => let val x = var () in Case (genI (funs, env, d'), lit (0, 5), genI (funs, env, d'), x, genI (funs, x :: env, d')) end
            | 11 => Const (genI (funs, env, d'))
            | 12 => Fst (genI (funs, env, d'))
            | 13 => Sum (genL (funs, env, d'))
            | 14 => Length (genL (funs, env, d'))
            | 15 => let val x = var () val acc = var ()
                    in Foldr (x, acc, genI (funs, x :: acc :: env, d' - 1), genI (funs, env, d'), genL (funs, env, d')) end
            | 16 => Add (genI (funs, env, d'), Lit (lit (0, 9)))
            | _ => Sub (genI (funs, env, d'), genI (funs, env, d'))
          end
      and genB (funs, env, d) =
        if d <= 0 then (if pick (0, 3) = 0 then BLit (pick (0, 1) = 0) else Lt (Lit (lit (~5, 5)), Lit (lit (~5, 5))))
        else
          let val d' = d - 1
          in
            case pick (0, 5) of
              0 => Lt (genI (funs, env, d'), genI (funs, env, d'))
            | 1 => Eq (genI (funs, env, d'), genI (funs, env, d'))
            | 2 => And (genB (funs, env, d'), genB (funs, env, d'))
            | 3 => Or (genB (funs, env, d'), genB (funs, env, d'))
            | 4 => Not (genB (funs, env, d'))
            | _ => Lt (genI (funs, env, d'), Lit (lit (~5, 10)))
          end
      and genL (funs, env, d) =
        if d <= 0 then (if pick (0, 1) = 0 then Range (lit (~3, 4), lit (0, 12))
                        else List (List.tabulate (pick (0, 4), fn _ => Lit (lit (~9, 20)))))
        else
          let val d' = d - 1
          in
            case pick (0, 6) of
              0 => List (List.tabulate (pick (0, 4), fn _ => genI (funs, env, d')))
            | 1 => let val x = var () in Map (x, genI (funs, x :: env, d'), genL (funs, env, d')) end
            | 2 => let val x = var () in Filter (x, genB (funs, x :: env, d'), genL (funs, env, d')) end
            | 3 => Take (lit (0, 6), genL (funs, env, d'))
            | 4 => Reverse (genL (funs, env, d'))
            | 5 => Range (lit (~3, 4), lit (0, 12))
            | _ => genL (funs, env, 0)
          end
      fun draw () =
        let
          val () = fresh := 0
          val funs =
            List.foldl (fn (k, fs) =>
                          let val params = List.tabulate (pick (1, 3), fn j => "a" ^ Int.toString k ^ "x" ^ Int.toString j)
                          in fs @ [{name = "f" ^ Int.toString k, params = params, body = genI (fs, params, 3)}] end)
                       [] (List.tabulate (pick (0, 3), fn k => k + 1))
          val outs = List.tabulate (pick (2, 5), fn _ =>
                       case pick (0, 3) of
                         0 => ("Bool", genB (funs, [], 3))
                       | 1 => ("[Int]", genL (funs, [], 3))
                       | _ => ("Int", genI (funs, [], 4)))
          val expected = List.map (fn (_, e) => showValue (eval funs [] e) ^ "\n") outs
        in SOME (funs, outs, String.concat expected) end
        handle TooBig => NONE
      fun again n = if n = 0 then raise Fail "HsGen: no program in 50 draws" else case draw () of SOME r => r | NONE => again (n - 1)
      val (funs, outs, expected) = again 50
      fun fundef ({name, params, body} : fundef) =
        name ^ " :: " ^ String.concatWith " -> " (List.map (fn _ => "Int") params @ ["Int"]) ^ "\n"
        ^ name ^ " " ^ String.concatWith " " params ^ " = " ^ show body ^ "\n\n"
      val text =
        "-- generated by HsGen from seed " ^ Int.toString seed ^ " (tests/runner/hsgen.sml)\nmodule Main (main) where\n\n"
        ^ String.concat (List.map fundef funs)
        ^ "main :: IO ()\nmain = do\n"
        ^ String.concat (List.map (fn (t, e) => "  print (" ^ show e ^ " :: " ^ t ^ ")\n") outs)
    in (text, expected) end

  (* ---- the jobs *)
  (* the rows the programs need: held until every one is out of Planned *)
  val rows = ["tr.if", "exp.case.seq", "exp.let.lexical", "tr.lambda", "std.arith.all", "pre.list.map", "pre.list.filter",
              "pre.list.foldr", "pre.list.sum", "pre.list.length", "pre.list.take", "pre.list.reverse", "std.nonstrict",
              "pre.const", "pre.fst", "tr.seq.fromto", "io.print", "std.list.show", "std.bool.ops", "tr.op.neg",
              "exp.sig.value"]
  fun work tag = let val d = run ^ "/hs-generated/" ^ tag in mkdirs d; d end
  fun parseRange (first, count) () =
    let val d = work "parse"
    in
      List.app (fn seed =>
                  let val (text, _) = generate seed
                      val f = d ^ "/g" ^ Int.toString seed ^ ".hs"
                      val () = write (f, text)
                      val code = exec {cmd = [fromRoot "bin/rhc", "--parse-only", f], dir = NONE, stdin = "", stdout = d ^ "/out",
                                       stderr = d ^ "/out", timeout = 120}
                  in if code = 0 then () else say ("FAIL hs-generated seed " ^ Int.toString seed ^ ": rhc does not parse it: "
                                                   ^ firstNonEmpty (d ^ "/out") ^ " (bin/rune-test hs-generate " ^ Int.toString seed ^ ")\n")
                  end)
               (List.tabulate (count, fn k => first + k))
    end
  (* each program compiled with the flags (none: the Report's order of
     matching; --match=sestoft: decision trees, D34) and run, its output held
     to the evaluator's, which is the Report's meaning *)
  fun runRangeWith flags (first, count) () =
    let val d = work ((if null flags then "run-" else "orders-") ^ Int.toString first)
    in
      List.app (fn seed =>
                  let
                    val (text, expected) = generate seed
                    val s = Int.toString seed
                    val f = d ^ "/g" ^ s ^ ".hs"
                    val () = write (f, text)
                    val code = exec {cmd = [fromRoot "bin/rhc"] @ flags @ [f, "-o", d ^ "/g.rbc"], dir = SOME d, stdin = "", stdout = d ^ "/cerr",
                                     stderr = d ^ "/cerr", timeout = 600}
                    val again = " (bin/rune-test hs-generate " ^ s ^ ")"
                  in
                    if code <> 0 then say ("FAIL hs-generated seed " ^ s ^ ": rhc refuses it: " ^ firstNonEmpty (d ^ "/cerr") ^ again ^ "\n")
                    else
                      let val c = exec {cmd = [fromRoot "bin/runevm", d ^ "/g.rbc"], dir = SOME d, stdin = "", stdout = d ^ "/out",
                                        stderr = d ^ "/err", timeout = 600}
                      in
                        if c <> 0 then say ("FAIL hs-generated seed " ^ s ^ ": exit " ^ Int.toString c ^ ": " ^ firstNonEmpty (d ^ "/err") ^ again ^ "\n")
                        else if read (d ^ "/out") <> expected then say ("FAIL hs-generated seed " ^ s ^ ": the output differs" ^ again ^ "\n")
                        else ()
                      end
                  end)
               (List.tabulate (count, fn k => first + k))
    end
  val runRange = runRangeWith []
  fun printOne seed () = let val (text, expected) = generate seed in say (text ^ "-- expected:\n" ^ expected) end

  fun command args =
    case args of
      ["hs-generate", s] => Option.map (fn n => printOne n) (Int.fromString s)
    | ["hs-generated", a, b] => (case (Int.fromString a, Int.fromString b) of
                                   (SOME a, SOME b) => SOME (runRange (a, b))
                                 | _ => NONE)
    | ["hs-generated-orders", a, b] => (case (Int.fromString a, Int.fromString b) of
                                          (SOME a, SOME b) => SOME (runRangeWith ["--match=sestoft"] (a, b))
                                        | _ => NONE)
    | ["hs-generated-parse", a, b] => (case (Int.fromString a, Int.fromString b) of
                                         (SOME a, SOME b) => SOME (parseRange (a, b))
                                       | _ => NONE)
    | _ => NONE

  val covers = ["covers:tests/runner/hsgen.sml", "covers:lib/language/haskell/*", "covers:src/rhc/*"]
  fun tree () =
    let
      fun job (name, args, timeout) = Test.requires ["rhc"] (Oracles.jobIn ("", name, args, [], 1, 800, timeout))
      fun held t = case HsConformance.pendingUntil rows of SOME w => Test.pending w t | NONE => t
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.tag "hs" (Test.describe "hs/generated"
           [Test.tag "check" (job ("@parse", ["hs-generated-parse", "1", "32"], 900)),
            Test.tag "check" (held (job ("@run", ["hs-generated", "1", "16"], 1800))),
            Test.tag "nightly" (held (job ("@nightly", ["hs-generated", "1000", "400"], 21600))),
            (* the literal rules against decision trees (tr.case.obligation,
               R86): the same programs compiled with Sestoft's trees *)
            Test.tag "nightly" (held (job ("@orders", ["hs-generated-orders", "1000", "400"], 21600)))]))
        covers
    end
end
