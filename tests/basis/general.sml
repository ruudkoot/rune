(* requires: General *)
(* The General structure (signature GENERAL) and the top-level identifiers it
   defines. Expected values follow the text of
   https://smlfamily.github.io/Basis/general.html.

   Bind and Match are raised with `raise` here: a binding or a match that can
   fail is one the compiler must warn about, and the tests compile without
   warnings. That pattern matching raises them is a matter of the Definition,
   not of the library. *)
structure TestGeneral =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqU = T.eq T.unit
  val eqL = T.eq (T.list T.int)
  val eqOrd = T.eq T.order

  (* newLog (): a function that records its argument, and one that returns
     what has been recorded so far, in order. *)
  fun newLog () : (int -> unit) * (unit -> int list) =
    let val log = ref []
    in (fn x => log := x :: !log, fn () => List.rev (!log)) end

  (* ---- unit, exn ---- *)
  val () = eqB ("General.unit/eqtype", true, fn () => (() : General.unit) = ())
  val () = eqU ("General.unit/same-as-toplevel", (), fn () => (fn (u : unit) => (u : General.unit)) ())
  val () = eqL ("General.exn/extensible", [1, 2, 3, 4],
                fn () =>
                  let
                    exception Local of int
                    fun code (e : General.exn) : int =
                      case e of Div => 1 | Fail _ => 2 | Local n => n | _ => 4
                  in
                    List.map code [Div, Fail "x", Local 3, Size]
                  end)
  val () = eqI ("General.exn/same-as-toplevel", 1,
                fn () => (raise (Div : General.exn)) handle (e : exn) => (case e of Div => 1 | _ => 0))

  (* ---- the exceptions: General.X and the top-level X are one exception,
          and the ten are distinct ---- *)
  val standard : (string * exn * (exn -> bool) * (exn -> bool)) list =
    [("Bind", General.Bind, T.isBind, fn General.Bind => true | _ => false),
     ("Match", General.Match, T.isMatch, fn General.Match => true | _ => false),
     ("Chr", General.Chr, T.isChr, fn General.Chr => true | _ => false),
     ("Div", General.Div, T.isDiv, fn General.Div => true | _ => false),
     ("Domain", General.Domain, T.isDomain, fn General.Domain => true | _ => false),
     ("Fail", General.Fail "reason", T.isFail, fn General.Fail _ => true | _ => false),
     ("Overflow", General.Overflow, T.isOverflow, fn General.Overflow => true | _ => false),
     ("Size", General.Size, T.isSize, fn General.Size => true | _ => false),
     ("Span", General.Span, T.isSpan, fn General.Span => true | _ => false),
     ("Subscript", General.Subscript, T.isSubscript, fn General.Subscript => true | _ => false)]

  val () = List.app (fn (name, e, isTop, isGeneral) =>
    (T.raises ("General." ^ name ^ "/toplevel-handles-General", isTop, fn () => raise e);
     T.check ("General." ^ name ^ "/General-handles-General", fn () => isGeneral e);
     (* of the ten predicates, only its own accepts the exception *)
     T.eq (T.list T.string) ("General." ^ name ^ "/distinct", [name],
       fn () => List.mapPartial (fn (other, _, isOther, _) => if isOther e then SOME other else NONE)
                                standard)))
    standard

  (* General.X handles the top-level X *)
  val () = T.raises ("General.Bind/General-handles-toplevel", fn General.Bind => true | _ => false,
                     fn () => raise Bind)
  val () = T.raises ("General.Match/General-handles-toplevel", fn General.Match => true | _ => false,
                     fn () => raise Match)
  val () = T.raises ("General.Domain/General-handles-toplevel", fn General.Domain => true | _ => false,
                     fn () => raise Domain)
  val () = T.raises ("General.Span/General-handles-toplevel", fn General.Span => true | _ => false,
                     fn () => raise Span)

  (* Chr: "an attempt to create a character with a code outside the range
     supported by the underlying character type (see CHAR.chr)" *)
  val () = T.raises ("General.Chr/chr-negative", fn General.Chr => true | _ => false, fn () => chr ~1)
  val () = T.raises ("General.Chr/chr-above-maxOrd", T.isChr, fn () => Char.chr (Char.maxOrd + 1))
  val () = T.raises ("General.Chr/succ-maxChar", T.isChr, fn () => Char.succ Char.maxChar)

  (* Div: "an attempt to divide by zero" *)
  val () = T.raises ("General.Div/div", fn General.Div => true | _ => false, fn () => 1 div 0)
  val () = T.raises ("General.Div/mod", T.isDiv, fn () => 1 mod 0)
  val () = T.raises ("General.Div/quot", T.isDiv, fn () => Int.quot (1, 0))
  val () = T.raises ("General.Div/rem", T.isDiv, fn () => Int.rem (1, 0))
  val () = T.raises ("General.Div/zero-by-zero", T.isDiv, fn () => 0 div 0)

  (* Domain: "the argument of a mathematical function is outside the domain of
     the function". REAL: floor, ceil, trunc and round "raise Domain on NaN
     arguments", and sign "raises Domain on NaN". *)
  val () = T.raises ("General.Domain/Real.floor-nan", fn General.Domain => true | _ => false,
                     fn () => Real.floor (0.0 / 0.0))
  val () = T.raises ("General.Domain/Real.ceil-nan", T.isDomain, fn () => Real.ceil (0.0 / 0.0))
  val () = T.raises ("General.Domain/Real.trunc-nan", T.isDomain, fn () => Real.trunc (0.0 / 0.0))
  val () = T.raises ("General.Domain/Real.round-nan", T.isDomain, fn () => Real.round (0.0 / 0.0))
  val () = T.raises ("General.Domain/Real.sign-nan", T.isDomain, fn () => Real.sign (0.0 / 0.0))
  (*<< IntInf.log2 *)
  (* INT_INF: log2 i "raises Domain if i <= 0" *)
  val () = T.raises ("General.Domain/IntInf.log2-zero", T.isDomain, fn () => IntInf.log2 (IntInf.fromInt 0))
  val () = T.raises ("General.Domain/IntInf.log2-negative", T.isDomain,
                     fn () => IntInf.log2 (IntInf.fromInt ~8))
  (*>> IntInf.log2 *)

  (* Fail of string: "provided for use by users" *)
  val () = eqS ("General.Fail/carries-string", "abc", fn () => (raise Fail "abc") handle Fail s => s)
  val () = eqS ("General.Fail/empty-string", "", fn () => (raise General.Fail "") handle General.Fail s => s)
  val () = eqS ("General.Fail/General-handles-toplevel", "top",
                fn () => (raise Fail "top") handle General.Fail s => s)
  (* an exception value built with the one name and matched with the other
     (SML/NJ 110.79 decides such a match at compile time, and wrongly) *)
  val () = eqS ("General.Fail/as-value", "v",
                fn () => case General.Fail "v" of Fail s => s | _ => "other")
  val () = eqB ("General.Div/as-value", true, fn () => case General.Div of Div => true | _ => false)

  (* Overflow: "the result of an arithmetic function is not representable".
     Where int has no bounds nothing overflows, and the check raises Overflow
     itself. *)
  val () = T.raises ("General.Overflow/maxInt-plus-one", fn General.Overflow => true | _ => false,
                     fn () => case Int.maxInt of SOME m => m + 1 | NONE => raise Overflow)
  val () = T.raises ("General.Overflow/minInt-minus-one", T.isOverflow,
                     fn () => case Int.minInt of SOME m => m - 1 | NONE => raise Overflow)
  val () = T.raises ("General.Overflow/maxInt-times-two", T.isOverflow,
                     fn () => case Int.maxInt of SOME m => m * 2 | NONE => raise Overflow)
  val () = T.raises ("General.Overflow/maxInt-minus-minInt", T.isOverflow,
                     fn () => case (Int.minInt, Int.maxInt) of
                                (SOME lo, SOME hi) => hi - lo
                              | _ => raise Overflow)
  val () = eqB ("General.Overflow/maxInt-itself-is-fine", true,
                fn () => case Int.maxInt of SOME m => m - 1 + 1 = m | NONE => true)

  (* Size: "an attempt to create an aggregate data structure (such as an array,
     string, or vector) whose size is too large or negative" *)
  val () = T.raises ("General.Size/List.tabulate-negative", fn General.Size => true | _ => false,
                     fn () => List.tabulate (~1, fn i => i))
  val () = T.raises ("General.Size/Array.array-negative", T.isSize, fn () => Array.array (~1, 0))
  val () = T.raises ("General.Size/Array.tabulate-negative", T.isSize, fn () => Array.tabulate (~1, fn i => i))
  val () = T.raises ("General.Size/Vector.tabulate-negative", T.isSize,
                     fn () => Vector.tabulate (~1, fn i => i))
  (*<< Array.maxLen *)
  (* "If n < 0 or maxLen < n, then the Size exception is raised"; where
     maxLen + 1 is not an int the check raises Size itself. *)
  val () = T.raises ("General.Size/Array.array-above-maxLen", T.isSize,
                     fn () =>
                       let
                         val representable = case Int.maxInt of SOME m => Array.maxLen < m | NONE => true
                       in
                         if representable then Array.array (Array.maxLen + 1, 0) else raise Size
                       end)
  (*>> Array.maxLen *)

  (*<< Substring.span *)
  (* Span: "an attempt to apply SUBSTRING.span to two incompatible substrings".
     span (ss, ss') with base ss = (s, i, n) and base ss' = (s', i', n')
     "raises Span" when "s <> s' or i'+n' < i". *)
  val () = T.raises ("General.Span/Substring.span-different-strings", fn General.Span => true | _ => false,
                     fn () => Substring.span (Substring.full "abc", Substring.full "xyz"))
  val () = T.raises ("General.Span/Substring.span-start-right-of-end", T.isSpan,
                     fn () =>
                       let val s = "abcdef"   (* i = 3, i' + n' = 2 *)
                       in Substring.span (Substring.substring (s, 3, 2), Substring.substring (s, 0, 2)) end)
  (*>> Substring.span *)

  (* Subscript: "an index is out of range ... (such as a list, string, array,
     or vector)" *)
  val () = T.raises ("General.Subscript/List.nth", fn General.Subscript => true | _ => false,
                     fn () => List.nth ([1, 2], 2))
  val () = T.raises ("General.Subscript/String.sub", T.isSubscript, fn () => String.sub ("abc", 3))
  val () = T.raises ("General.Subscript/String.sub-negative", T.isSubscript, fn () => String.sub ("abc", ~1))
  val () = T.raises ("General.Subscript/Array.sub", T.isSubscript, fn () => Array.sub (Array.fromList [1], 1))
  val () = T.raises ("General.Subscript/Vector.sub", T.isSubscript, fn () => Vector.sub (Vector.fromList [1], ~1))

  (*<< exnName *)
  (* exnName ex "returns a name for the exception ex" *)
  val () = List.app (fn (name, e, _, _) =>
    eqS ("General.exnName/" ^ name, name, fn () => General.exnName e)) standard
  val () = eqS ("General.exnName/toplevel", "Div", fn () => exnName Div)
  val () = eqS ("General.exnName/Fail-ignores-argument", "Fail", fn () => exnName (Fail "Size"))
  (* the exceptions as the library raises them *)
  val () = eqS ("General.exnName/raised-Div", "Div", fn () => (ignore (1 div 0); "none") handle e => exnName e)
  val () = eqS ("General.exnName/raised-Chr", "Chr", fn () => (ignore (chr ~1); "none") handle e => exnName e)
  val () = eqS ("General.exnName/raised-Subscript", "Subscript",
                fn () => (ignore (List.nth ([1], 1)); "none") handle e => exnName e)
  val () = eqS ("General.exnName/raised-Size", "Size",
                fn () => (ignore (List.tabulate (~1, fn i => i)); "none") handle e => exnName e)
  val () = eqS ("General.exnName/raised-Overflow", "Overflow",
                fn () => (case Int.maxInt of SOME m => ignore (m + 1) | NONE => raise Overflow; "none")
                         handle e => exnName e)
  val () = eqS ("General.exnName/raised-Domain", "Domain",
                fn () => (ignore (Real.floor (0.0 / 0.0)); "none") handle e => exnName e)
  (* exceptions of the program *)
  val () = eqS ("General.exnName/user", "Local", fn () => let exception Local in exnName Local end)
  val () = eqS ("General.exnName/user-with-argument", "Carry",
                fn () => let exception Carry of int * string in exnName (Carry (1, "x")) end)
  (* "let exception E1; exception E2 = E1 in exnName E2 end might evaluate to
     "E1" or "E2"" *)
  val () = T.check ("General.exnName/alias-either-name",
                    fn () => let exception E1; exception E2 = E1
                                 val name = exnName E2
                             in name = "E1" orelse name = "E2" end)
  val () = T.check ("General.exnName/alias-of-standard",
                    fn () => let exception Zero = Div
                                 val name = exnName Zero
                             in name = "Div" orelse name = "Zero" end)
  (*>> exnName *)

  (* a locally declared exception for the exnMessage sections *)
  exception Local of int

  (*<< exnMessage *)
  (* exnMessage ex "returns a message ... The precise format of the message may
     vary between implementations and locales": it returns, and does not raise. *)
  val () = List.app (fn (name, e, _, _) =>
    T.check ("General.exnMessage/returns-" ^ name, fn () => String.size (General.exnMessage e) >= 0))
    standard
  val () = T.check ("General.exnMessage/toplevel", fn () => String.size (exnMessage Div) >= 0)
  val () = T.check ("General.exnMessage/user", fn () => String.size (exnMessage (Local 1)) >= 0)
  val () = T.check ("General.exnMessage/raised-Div",
                    fn () => (ignore (1 div 0); false) handle e => String.size (exnMessage e) >= 0)
  (*>> exnMessage *)

  (*<< exnMessage-exnName *)
  (* "... but will at least contain the string exnName ex" *)
  val () = List.app (fn (name, e, _, _) =>
    T.check ("General.exnMessage/contains-exnName-" ^ name,
             fn () => String.isSubstring (exnName e) (exnMessage e)))
    standard
  val () = T.check ("General.exnMessage/contains-exnName-user",
                    fn () => String.isSubstring (exnName (Local 1)) (exnMessage (Local 1)))
  val () = T.check ("General.exnMessage/contains-exnName-raised-Div",
                    fn () => (ignore (1 div 0); false)
                             handle e => String.isSubstring (exnName e) (exnMessage e))
  val () = T.check ("General.exnMessage/contains-exnName-raised-Subscript",
                    fn () => (ignore (List.nth ([1], 1)); false)
                             handle e => String.isSubstring (exnName e) (exnMessage e))
  (*>> exnMessage-exnName *)

  (* ---- order ---- *)
  val () = eqOrd ("General.LESS/same-as-toplevel", LESS, fn () => General.LESS)
  val () = eqOrd ("General.EQUAL/same-as-toplevel", EQUAL, fn () => General.EQUAL)
  val () = eqOrd ("General.GREATER/same-as-toplevel", GREATER, fn () => General.GREATER)
  val () = eqL ("General.order/case", [~1, 0, 1],
                fn () => List.map (fn General.LESS => ~1 | General.EQUAL => 0 | General.GREATER => 1)
                                  [LESS, EQUAL, GREATER])
  val () = eqB ("General.order/distinct", true,
                fn () => LESS <> EQUAL andalso EQUAL <> GREATER andalso LESS <> GREATER)
  val () = eqB ("General.order/equality", true,
                fn () => LESS = General.LESS andalso EQUAL = General.EQUAL andalso GREATER = General.GREATER)
  (* "used when comparing elements of a type that has a linear ordering" *)
  val () = eqOrd ("General.LESS/Int.compare", General.LESS, fn () => Int.compare (1, 2))
  val () = eqOrd ("General.EQUAL/Int.compare", General.EQUAL, fn () => Int.compare (2, 2))
  val () = eqOrd ("General.GREATER/Int.compare", General.GREATER, fn () => Int.compare (3, 2))

  (* ---- !, := ---- *)
  val () = eqI ("General.!/initial", 1, fn () => General.! (ref 1))
  val () = eqI ("General.!/toplevel", 1, fn () => ! (ref 1))
  val () = eqS ("General.!/string", "a", fn () => ! (ref "a"))
  val () = eqL ("General.!/list", [1, 2], fn () => ! (ref [1, 2]))
  val () = eqI ("General.!/ref-of-ref", 7, fn () => ! (! (ref (ref 7))))
  val () = eqI ("General.!/does-not-change", 3, fn () => let val r = ref 3 in ignore (!r); !r end)
  val () = eqI ("General.:=/basic", 2, fn () => let val r = ref 1 in General.:= (r, 2); !r end)
  val () = eqI ("General.:=/toplevel-infix", 2, fn () => let val r = ref 1 in r := 2; !r end)
  val () = eqU ("General.:=/returns-unit", (), fn () => let val r = ref 1 in r := 2 end)
  val () = eqI ("General.:=/last-assignment-wins", 4, fn () => let val r = ref 1 in r := 2; r := 3; r := 4; !r end)
  val () = eqI ("General.:=/same-ref-two-names", 5, fn () => let val r = ref 1 val s = r in s := 5; !r end)
  val () = eqI ("General.:=/distinct-refs", 1, fn () => let val r = ref 1 val s = ref 1 in s := 5; !r end)
  val () = eqI ("General.:=/self-reference", 8, fn () => let val r = ref 4 in r := !r + !r; !r end)
  val () = eqI ("General.:=/function", 42,
                fn () => let val r = ref (fn x => x + 1) in r := (fn x => x * 2); (!r) 21 end)
  val () = eqI ("General.:=/ref-of-ref", 9,
                fn () => let val inner = ref 1 val r = ref (ref 0) in r := inner; inner := 9; ! (!r) end)
  val () = eqL ("General.:=/closure-shares-ref", [1, 2, 3],
                fn () =>
                  let
                    val r = ref 0
                    fun next () = (r := !r + 1; !r)
                    val a = next ()
                    val b = next ()
                    val c = next ()
                  in [a, b, c] end)
  (* infix 3 := : weaker than the arithmetic operators *)
  val () = eqI ("General.:=/infix-below-plus", 3, fn () => let val r = ref 0 in r := 1 + 2; !r end)

  (* ---- o: "(f o g) a is equivalent to f(g a)" ---- *)
  val () = eqI ("General.o/basic", 21, fn () => General.o (fn x => x + 1, fn x => x * 2) 10)
  val () = eqI ("General.o/toplevel-infix", 22, fn () => ((fn x => x * 2) o (fn x => x + 1)) 10)
  val () = eqS ("General.o/three-types", "42!", fn () => ((fn s => s ^ "!") o Int.toString) 42)
  val () = eqI ("General.o/three-types-int-string-int", 5, fn () => (String.size o Int.toString) 12345)
  val () = eqI ("General.o/chain", 25, fn () => ((fn x => x * x) o (fn x => x + 2) o (fn x => x * 3)) 1)
  val () = eqL ("General.o/g-then-f", [1, 2],
                fn () =>
                  let val (log, seen) = newLog ()
                  in ignore (((fn x => (log 2; x)) o (fn x => (log 1; x))) 0); seen () end)
  val () = eqL ("General.o/composing-applies-nothing", [],
                fn () =>
                  let
                    val (log, seen) = newLog ()
                    val h = (fn x => (log 2; x + 1)) o (fn x => (log 1; x + 1))
                  in ignore h; seen () end)
  val () = eqL ("General.o/each-application-applies-both", [1, 2, 1, 2],
                fn () =>
                  let
                    val (log, seen) = newLog ()
                    val h = (fn x => (log 2; x + 1)) o (fn x => (log 1; x + 1))
                  in ignore (h 0); ignore (h 0); seen () end)
  val () = T.raises ("General.o/exception-of-g", T.isFail,
                     fn () => ((fn x => x + 1) o (fn _ => raise Fail "g")) 0)
  val () = eqL ("General.o/f-not-applied-when-g-raises", [1],
                fn () =>
                  let
                    val (log, seen) = newLog ()
                    val h = (fn x => (log 2; x + 1)) o (fn x => (log 1; if x = 0 then raise Div else x))
                  in (ignore (h 0)) handle Div => (); seen () end)
  val () = T.raises ("General.o/exception-of-f", T.isSubscript,
                     fn () => ((fn _ => raise Subscript) o (fn x => x + 1)) 0)

  (* ---- before: "evaluating a, then b, before returning the value of a" ---- *)
  val () = eqI ("General.before/returns-first", 1, fn () => General.before (1, ()))
  val () = eqI ("General.before/toplevel-infix", 1, fn () => 1 before ())
  val () = eqS ("General.before/string", "a", fn () => "a" before ())
  val () = eqL ("General.before/a-then-b", [1, 2],
                fn () =>
                  let val (log, seen) = newLog ()
                  in ignore ((log 1; 10) before log 2); seen () end)
  val () = eqI ("General.before/value-of-a-before-b-runs", 1,
                fn () => let val r = ref 1 in !r before r := 2 end)
  val () = eqI ("General.before/b-has-run", 2,
                fn () => let val r = ref 1 in ignore (!r before r := 2); !r end)
  val () = T.raises ("General.before/exception-of-b", T.isFail, fn () => 1 before (raise Fail "b"))
  val () = eqL ("General.before/b-not-evaluated-when-a-raises", [],
                fn () =>
                  let val (log, seen) = newLog ()
                  in (ignore (((raise Div) : int) before log 2)) handle Div => (); seen () end)
  (* infix 0 before: weaker than := (infix 3), so the assignment comes first *)
  val () = eqL ("General.before/infix-below-assign", [5],
                fn () =>
                  let
                    val (log, seen) = newLog ()
                    val r = ref 0
                  in r := 5 before log (!r); seen () end)
  val () = eqL ("General.before/chain", [1, 3],
                fn () =>
                  let
                    val r = ref 0
                    val v = 1 before r := 2 before r := 3
                  in [v, !r] end)

  (* ---- ignore: "returns ()" ---- *)
  val () = eqU ("General.ignore/int", (), fn () => General.ignore 1)
  val () = eqU ("General.ignore/toplevel", (), fn () => ignore "abc")
  val () = eqU ("General.ignore/function", (), fn () => ignore (fn x => x + 1))
  val () = eqL ("General.ignore/argument-is-evaluated", [1],
                fn () => let val (log, seen) = newLog () in ignore (log 1; 5); seen () end)
  val () = T.raises ("General.ignore/exception-of-argument", T.isDiv, fn () => ignore (1 div 0))
  (* "when a higher-order function, such as List.app, requires a function
     returning unit, but the function to be used returns values of some other
     type" *)
  val () = eqL ("General.ignore/with-List.app", [1, 2, 3],
                fn () =>
                  let val (log, seen) = newLog ()
                  in List.app (ignore o (fn x => (log x; x * 2))) [1, 2, 3]; seen () end)

  (* ---- laws, on pseudo-random inputs ---- *)
  val () = T.seed 1
  val () = T.repeat (50, fn i =>
    let
      val n = Int.toString i
      val a = T.range (~9, 9)
      val b = T.range (~99, 99)
      val c = T.range (~9, 9)
      val d = T.range (~99, 99)
      val x = T.range (~99, 99)
      fun f y = a * y + b
      fun g y = c * y + d
      fun h y = y * y - a
      fun id y = y
      (* three refs, a series of assignments, and the same on a list *)
      val steps = List.tabulate (T.range (0, 10), fn _ => (T.range (0, 2), T.range (~50, 50)))
      val model = List.foldl (fn ((k, v), l) => List.take (l, k) @ [v] @ List.drop (l, k + 1)) [0, 0, 0] steps
      val text = String.implode (List.tabulate (T.range (0, 8), fn _ => Char.chr (T.range (32, 126))))
    in
      eqI ("General.o/definition-" ^ n, f (g x), fn () => (f o g) x);
      eqI ("General.o/associative-left-" ^ n, f (g (h x)), fn () => ((f o g) o h) x);
      eqI ("General.o/associative-right-" ^ n, f (g (h x)), fn () => (f o (g o h)) x);
      eqI ("General.o/identity-right-" ^ n, f x, fn () => (f o id) x);
      eqI ("General.o/identity-left-" ^ n, f x, fn () => (id o f) x);
      eqI ("General.:=/then-deref-" ^ n, x, fn () => let val r = ref a in r := x; !r end);
      eqL ("General.:=/series-" ^ n, model,
           fn () =>
             let val refs = [ref 0, ref 0, ref 0]
             in List.app (fn (k, v) => List.nth (refs, k) := v) steps; List.map ! refs end);
      eqI ("General.before/law-" ^ n, x,
           fn () => let val r = ref x in !r before r := b end);
      eqU ("General.ignore/law-" ^ n, (), fn () => ignore (f x));
      eqS ("General.Fail/law-" ^ n, text, fn () => (raise Fail text) handle Fail s => s)
    end)
end
