(* Harness of the Basis Library suite (tests/basis/README.md).

   Portable Standard ML '97: this file and the tests run unchanged on Rune and
   on the host systems they are cross-checked with, and rely on nothing beyond
   the Basis members every one of them has.

   A test file is one structure whose body calls the functions below. Every
   check has a label "Structure.member/case" (no spaces) and prints one line,
   "PASS label" or "FAIL label -- why", or "SKIP label -- why" when the
   machine cannot run it (skipUnless below); tests/basis/finish.sml then
   prints "SUMMARY n checks, k failed" (with ", s skipped" when s > 0) and
   exits with a failure status when k > 0.
   The expected values in the tests are the hand-verified part of the suite:
   they are derived from the text of the Basis specification, never copied
   from the output of an implementation. *)
structure T =
struct
  val passes = ref 0
  val failures = ref 0
  val skips = ref 0

  (* the reason the checks being made are skipped, inside skipUnless *)
  val skipping : string option ref = ref NONE

  fun skip (label : string, why : string) : unit =
    (skips := !skips + 1; print ("SKIP " ^ label ^ " -- " ^ why ^ "\n"))

  fun pass (label : string) : unit =
    case !skipping of
      SOME why => skip (label, why)
    | NONE => (passes := !passes + 1; print ("PASS " ^ label ^ "\n"))

  fun fail (label : string, why : string) : unit =
    case !skipping of
      SOME why' => skip (label, why')
    | NONE => (failures := !failures + 1;
               print ("FAIL " ^ label ^ (if why = "" then "" else " -- " ^ why) ^ "\n"))

  (* skipUnless (ok, why) f: the checks that f makes; when not ok, each of
     them is reported as skipped, with why, and none of their thunks runs.
     It is for what the machine may lack (an IPv6 address, a terminal),
     never for what an implementation lacks: that is a failure, which
     deviations.txt explains. *)
  fun skipUnless (ok : bool, why : string) (f : unit -> unit) : unit =
    if ok orelse Option.isSome (!skipping) then f ()
    else (skipping := SOME why;
          (f () handle e => (skipping := NONE; raise e));
          skipping := NONE)

  (* guard label k: k (), which makes the check, unless it is skipped *)
  fun guard (label : string) (k : unit -> unit) : unit =
    case !skipping of
      SOME why => skip (label, why)
    | NONE => k ()

  (* ---- showing values (for failure messages only) ---- *)
  fun unit () = "()"
  val int = Int.toString
  fun word w = "0wx" ^ Word.toString w
  val real = Real.toString
  val bool = Bool.toString
  fun char c = "#\"" ^ Char.toString c ^ "\""
  fun string s = "\"" ^ String.toString s ^ "\""
  fun order LESS = "LESS"
    | order EQUAL = "EQUAL"
    | order GREATER = "GREATER"
  fun option show NONE = "NONE"
    | option show (SOME v) = "SOME " ^ show v
  fun list show l = "[" ^ String.concatWith ", " (List.map show l) ^ "]"
  fun pair (showA, showB) (a, b) = "(" ^ showA a ^ ", " ^ showB b ^ ")"
  fun triple (showA, showB, showC) (a, b, c) = "(" ^ showA a ^ ", " ^ showB b ^ ", " ^ showC c ^ ")"

  (* ---- checks ---- *)

  (* check (label, f): f () is true. *)
  fun check (label, f : unit -> bool) : unit = guard label (fn () =>
    case (SOME (f ()) handle _ => NONE) of
      SOME true => pass label
    | SOME false => fail (label, "false")
    | NONE => fail (label, "raised an exception"))

  (* eq show (label, expected, f): f () equals expected. *)
  fun eq show (label, expected, f) : unit = guard label (fn () =>
    case (SOME (f ()) handle _ => NONE) of
      SOME v =>
        if v = expected then pass label
        else fail (label, "got " ^ show v ^ ", expected " ^ show expected)
    | NONE => fail (label, "raised an exception, expected " ^ show expected))

  (* Reals: the same IEEE value (NaN equals NaN, 0.0 differs from ~0.0). *)
  fun sameReal (a : real, b : real) : bool =
    if Real.isNan a orelse Real.isNan b then Real.isNan a andalso Real.isNan b
    else Real.== (a, b) andalso Real.signBit a = Real.signBit b

  fun eqReal (label, expected : real, f : unit -> real) : unit = guard label (fn () =>
    case (SOME (f ()) handle _ => NONE) of
      SOME v =>
        if sameReal (v, expected) then pass label
        else fail (label, "got " ^ real v ^ ", expected " ^ real expected)
    | NONE => fail (label, "raised an exception, expected " ^ real expected))

  (* approx (label, expected, f): equal up to a relative error of 1E~9. *)
  fun approx (label, expected : real, f : unit -> real) : unit = guard label (fn () =>
    case (SOME (f ()) handle _ => NONE) of
      SOME v =>
        let
          val scale = Real.max (1.0, Real.max (Real.abs v, Real.abs expected))
        in
          if sameReal (v, expected) orelse Real.abs (v - expected) <= 1E~9 * scale then pass label
          else fail (label, "got " ^ real v ^ ", expected about " ^ real expected)
        end
    | NONE => fail (label, "raised an exception, expected about " ^ real expected))

  (* raises (label, isExpected, f): f () raises an exception that isExpected
     accepts. The predicates below cover the exceptions of the Basis. *)
  fun raises (label, isExpected : exn -> bool, f : unit -> 'a) : unit = guard label (fn () =>
    case (SOME (ignore (f ())) handle e => (if isExpected e then pass label
                                            else fail (label, "raised a different exception");
                                            NONE)) of
      SOME () => fail (label, "no exception raised")
    | NONE => ())

  val anyExn = fn (_ : exn) => true
  val isBind = fn Bind => true | _ => false
  val isMatch = fn Match => true | _ => false
  val isChr = fn Chr => true | _ => false
  val isDiv = fn Div => true | _ => false
  val isDomain = fn Domain => true | _ => false
  val isEmpty = fn Empty => true | _ => false
  val isFail = fn Fail _ => true | _ => false
  val isOption = fn Option => true | _ => false
  val isOverflow = fn Overflow => true | _ => false
  val isSize = fn Size => true | _ => false
  val isSpan = fn Span => true | _ => false
  val isSubscript = fn Subscript => true | _ => false

  (* ---- deterministic pseudo-random numbers ----
     A Lehmer generator evaluated with Schrage's method, so that every
     intermediate value stays below 2^30 and the sequence is the same whatever
     the precision of int is (31 bits on SML/NJ 110.79). *)
  val modulus = 1073741789   (* the largest prime below 2^30 *)
  val state = ref 1

  fun seed (n : int) : unit = state := (n mod (modulus - 1)) + 1

  (* rand (): the next number, in [0, modulus - 1). *)
  fun rand () : int =
    let
      val a = 16807
      val q = modulus div a
      val r = modulus mod a
      val s = !state
      val t = a * (s mod q) - r * (s div q)
      val s' = if t > 0 then t else t + modulus
    in
      state := s'; s' - 1
    end

  (* range (lo, hi): a number in [lo, hi], for hi - lo below modulus. *)
  fun range (lo : int, hi : int) : int = lo + rand () mod (hi - lo + 1)

  fun oneOf (l : 'a list) : 'a = List.nth (l, rand () mod List.length l)

  (* repeat (n, f): f 0, ..., f (n - 1). *)
  fun repeat (n : int, f : int -> unit) : unit =
    let fun go i = if i < n then (f i; go (i + 1)) else ()
    in go 0 end

  fun summary () : unit =
    (print ("SUMMARY " ^ Int.toString (!passes + !failures + !skips) ^ " checks, "
            ^ Int.toString (!failures) ^ " failed"
            ^ (if !skips = 0 then "" else ", " ^ Int.toString (!skips) ^ " skipped") ^ "\n");
     OS.Process.exit (if !failures = 0 then OS.Process.success else OS.Process.failure))
end
