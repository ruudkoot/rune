(* requires: Option *)
(* The Option structure (signature OPTION). Expected values follow the text of
   https://smlfamily.github.io/Basis/option.html. *)
structure TestOption =
struct
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqU = T.eq T.unit
  val eqS = T.eq T.string
  val eqL = T.eq (T.list T.int)
  val eqO = T.eq (T.option T.int)
  val eqOO = T.eq (T.option (T.option T.int))
  val eqOS = T.eq (T.option T.string)

  (* trace f: f, and the arguments it has been applied to so far, in order. *)
  fun trace (f : int -> 'a) : (int -> 'a) * (unit -> int list) =
    let val log = ref []
    in (fn x => (log := x :: !log; f x), fn () => List.rev (!log)) end

  (* ---- the datatype is the top-level one ---- *)
  val () = eqO ("Option.NONE/same-as-toplevel", NONE, fn () => Option.NONE)
  val () = eqO ("Option.SOME/same-as-toplevel", SOME 1, fn () => Option.SOME 1)
  val () = eqI ("Option.SOME/pattern", 3, fn () => case SOME 3 of Option.SOME v => v | Option.NONE => 0)
  val () = eqI ("Option.NONE/pattern", 0, fn () => case (NONE : int option) of Option.SOME v => v | Option.NONE => 0)
  val () = eqB ("Option.option/NONE-is-not-SOME", false, fn () => (NONE : int option) = SOME 0)
  val () = eqB ("Option.option/equality-of-SOME", true, fn () => SOME "a" = Option.SOME "a")
  val () = eqB ("Option.option/inequality-of-SOME", false, fn () => SOME 1 = SOME 2)
  val () = eqOO ("Option.option/nested", SOME NONE, fn () => Option.SOME (Option.NONE : int Option.option))

  (* ---- getOpt (opt, a): "returns v if opt is SOME(v); otherwise it returns a" ---- *)
  val () = eqI ("Option.getOpt/some", 1, fn () => Option.getOpt (SOME 1, 2))
  val () = eqI ("Option.getOpt/none", 2, fn () => Option.getOpt (NONE, 2))
  val () = eqS ("Option.getOpt/string", "d", fn () => Option.getOpt (NONE, "d"))
  val () = eqI ("Option.getOpt/some-equal-to-default", 2, fn () => Option.getOpt (SOME 2, 2))
  val () = eqI ("Option.getOpt/toplevel-some", 1, fn () => getOpt (SOME 1, 2))
  val () = eqI ("Option.getOpt/toplevel-none", 2, fn () => getOpt (NONE, 2))

  (* ---- isSome ---- *)
  val () = eqB ("Option.isSome/some", true, fn () => Option.isSome (SOME 0))
  val () = eqB ("Option.isSome/none", false, fn () => Option.isSome (NONE : int option))
  val () = eqB ("Option.isSome/some-none", true, fn () => Option.isSome (SOME (NONE : int option)))
  val () = eqB ("Option.isSome/toplevel-some", true, fn () => isSome (SOME ()))
  val () = eqB ("Option.isSome/toplevel-none", false, fn () => isSome (NONE : unit option))

  (* ---- valOf: "otherwise it raises the Option exception" ---- *)
  val () = eqI ("Option.valOf/some", 5, fn () => Option.valOf (SOME 5))
  val () = T.raises ("Option.valOf/Option", T.isOption, fn () => Option.valOf (NONE : int option))
  val () = eqO ("Option.valOf/some-none", NONE, fn () => Option.valOf (SOME (NONE : int option)))
  val () = eqI ("Option.valOf/toplevel-some", 5, fn () => valOf (SOME 5))
  val () = T.raises ("Option.valOf/toplevel-Option", T.isOption, fn () => valOf (NONE : int option))

  (* ---- the exception is the top-level one ---- *)
  val () = T.raises ("Option.Option/handles-toplevel", fn Option.Option => true | _ => false,
                     fn () => valOf (NONE : int option))
  val () = T.raises ("Option.Option/toplevel-handles", T.isOption, fn () => raise Option.Option)
  val () = T.raises ("Option.Option/raised-by-valOf", fn Option.Option => true | _ => false,
                     fn () => Option.valOf (NONE : string option))
  val () = eqB ("Option.Option/differs-from-Empty", false, fn () => T.isEmpty Option.Option)

  (* ---- filter f a: "returns SOME(a) if f(a) is true and NONE otherwise" ---- *)
  val () = eqO ("Option.filter/true", SOME 5, fn () => Option.filter (fn x => x > 0) 5)
  val () = eqO ("Option.filter/false", NONE, fn () => Option.filter (fn x => x > 0) ~5)
  val () = eqOS ("Option.filter/string", SOME "abc", fn () => Option.filter (fn s => size s = 3) "abc")
  val () = eqL ("Option.filter/applies-f-once-to-a", [5],
                fn () => let val (f, seen) = trace (fn _ => true) in ignore (Option.filter f 5); seen () end)
  val () = eqL ("Option.filter/applies-f-once-to-a-false", [5],
                fn () => let val (f, seen) = trace (fn _ => false) in ignore (Option.filter f 5); seen () end)
  val () = T.raises ("Option.filter/exception-of-f", T.isFail,
                     fn () => Option.filter (fn (_ : int) => raise Fail "f") 1)

  (* ---- join: "maps NONE to NONE and SOME(v) to v" ---- *)
  val () = eqO ("Option.join/none", NONE, fn () => Option.join (NONE : int option option))
  val () = eqO ("Option.join/some-none", NONE, fn () => Option.join (SOME (NONE : int option)))
  val () = eqO ("Option.join/some-some", SOME 1, fn () => Option.join (SOME (SOME 1)))
  val () = eqOO ("Option.join/one-level-only", SOME (SOME 1), fn () => Option.join (SOME (SOME (SOME 1))))
  val () = eqOO ("Option.join/one-level-only-none", SOME NONE,
                 fn () => Option.join (SOME (SOME (NONE : int option))))

  (* ---- app f opt: "applies the function f to the value v if opt is SOME(v),
          and otherwise does nothing" ---- *)
  val () = eqL ("Option.app/some", [3],
                fn () => let val (f, seen) = trace (fn _ => ()) in Option.app f (SOME 3); seen () end)
  val () = eqL ("Option.app/none", [],
                fn () => let val (f, seen) = trace (fn _ => ()) in Option.app f NONE; seen () end)
  val () = eqU ("Option.app/returns-unit-some", (), fn () => Option.app (fn (_ : int) => ()) (SOME 3))
  val () = eqU ("Option.app/returns-unit-none", (), fn () => Option.app (fn (_ : int) => ()) NONE)
  val () = T.raises ("Option.app/exception-of-f", T.isFail,
                     fn () => Option.app (fn (_ : int) => raise Fail "f") (SOME 1))
  val () = eqU ("Option.app/none-does-not-apply-f", (),
                fn () => Option.app (fn (_ : int) => raise Fail "f") NONE)

  (* ---- map f opt: "maps NONE to NONE and SOME(v) to SOME(f v)" ---- *)
  val () = eqO ("Option.map/some", SOME 6, fn () => Option.map (fn x => 2 * x) (SOME 3))
  val () = eqO ("Option.map/none", NONE, fn () => Option.map (fn x => 2 * x) NONE)
  val () = eqOS ("Option.map/other-type", SOME "42", fn () => Option.map Int.toString (SOME 42))
  val () = eqOO ("Option.map/result-is-wrapped", SOME NONE,
                 fn () => Option.map (fn (_ : int) => (NONE : int option)) (SOME 1))
  val () = eqL ("Option.map/applies-f-once", [3],
                fn () => let val (f, seen) = trace (fn x => x) in ignore (Option.map f (SOME 3)); seen () end)
  val () = eqL ("Option.map/none-does-not-apply-f", [],
                fn () => let val (f, seen) = trace (fn x => x) in ignore (Option.map f NONE); seen () end)
  val () = T.raises ("Option.map/exception-of-f", T.isFail,
                     fn () => Option.map (fn (_ : int) => (raise Fail "f") : int) (SOME 1))

  (* ---- mapPartial f opt: "maps NONE to NONE and SOME(v) to f(v)" ---- *)
  fun half x = if x mod 2 = 0 then SOME (x div 2) else NONE
  val () = eqO ("Option.mapPartial/some-to-some", SOME 3, fn () => Option.mapPartial half (SOME 6))
  val () = eqO ("Option.mapPartial/some-to-none", NONE, fn () => Option.mapPartial half (SOME 7))
  val () = eqO ("Option.mapPartial/none", NONE, fn () => Option.mapPartial half NONE)
  val () = eqOS ("Option.mapPartial/other-type", SOME "6",
                 fn () => Option.mapPartial (fn x => SOME (Int.toString x)) (SOME 6))
  val () = eqL ("Option.mapPartial/applies-f-once", [6],
                fn () => let val (f, seen) = trace half in ignore (Option.mapPartial f (SOME 6)); seen () end)
  val () = eqL ("Option.mapPartial/none-does-not-apply-f", [],
                fn () => let val (f, seen) = trace half in ignore (Option.mapPartial f NONE); seen () end)
  val () = T.raises ("Option.mapPartial/exception-of-f", T.isFail,
                     fn () => Option.mapPartial (fn (_ : int) => (raise Fail "f") : int option) (SOME 1))

  (* ---- compose (f, g) a: "returns NONE if g(a) is NONE; otherwise, if g(a)
          is SOME(v), it returns SOME(f v)" ---- *)
  val () = eqO ("Option.compose/some", SOME 4, fn () => Option.compose (fn x => x + 1, half) 6)
  val () = eqO ("Option.compose/none", NONE, fn () => Option.compose (fn x => x + 1, half) 7)
  val () = T.eq (T.option T.bool) ("Option.compose/three-types", SOME true,
             fn () => Option.compose (fn n => n > 2, fn s => if s = "" then NONE else SOME (size s)) "abc")
  val () = T.eq (T.option T.bool) ("Option.compose/three-types-none", NONE,
             fn () => Option.compose (fn n => n > 2, fn s => if s = "" then NONE else SOME (size s)) "")
  (* g is traced with its argument, f with its argument + 100 *)
  val () = eqL ("Option.compose/g-then-f", [6, 103],
                fn () =>
                  let
                    val log = ref []
                    fun g x = (log := x :: !log; half x)
                    fun f v = (log := v + 100 :: !log; v)
                  in ignore (Option.compose (f, g) 6); List.rev (!log) end)
  val () = eqL ("Option.compose/f-not-applied-when-g-is-NONE", [7],
                fn () =>
                  let
                    val log = ref []
                    fun g x = (log := x :: !log; half x)
                    fun f v = (log := v + 100 :: !log; v)
                  in ignore (Option.compose (f, g) 7); List.rev (!log) end)
  val () = T.raises ("Option.compose/exception-of-g", T.isFail,
                     fn () => Option.compose (fn (x : int) => x, fn (_ : int) => (raise Fail "g") : int option) 1)
  val () = T.raises ("Option.compose/exception-of-f", T.isFail,
                     fn () => Option.compose (fn (_ : int) => (raise Fail "f") : int, half) 2)

  (* ---- composePartial (f, g) a: "returns NONE if g(a) is NONE; otherwise, if
          g(a) is SOME(v), it returns f(v)" ---- *)
  val () = eqO ("Option.composePartial/some-some", SOME 3, fn () => Option.composePartial (half, half) 12)
  val () = eqO ("Option.composePartial/some-none", NONE, fn () => Option.composePartial (half, half) 6)
  val () = eqO ("Option.composePartial/none", NONE, fn () => Option.composePartial (half, half) 7)
  val () = T.eq (T.option T.bool) ("Option.composePartial/three-types", SOME false,
             fn () => Option.composePartial (fn n => if n = 0 then NONE else SOME (n > 2),
                                             fn s => SOME (size s)) "ab")
  val () = T.eq (T.option T.bool) ("Option.composePartial/three-types-f-none", NONE,
             fn () => Option.composePartial (fn n => if n = 0 then NONE else SOME (n > 2),
                                             fn s => SOME (size s)) "")
  val () = eqL ("Option.composePartial/g-then-f", [12, 106],
                fn () =>
                  let
                    val log = ref []
                    fun g x = (log := x :: !log; half x)
                    fun f v = (log := v + 100 :: !log; half v)
                  in ignore (Option.composePartial (f, g) 12); List.rev (!log) end)
  val () = eqL ("Option.composePartial/f-not-applied-when-g-is-NONE", [7],
                fn () =>
                  let
                    val log = ref []
                    fun g x = (log := x :: !log; half x)
                    fun f v = (log := v + 100 :: !log; half v)
                  in ignore (Option.composePartial (f, g) 7); List.rev (!log) end)
  val () = T.raises ("Option.composePartial/exception-of-g", T.isFail,
                     fn () => Option.composePartial (half, fn (_ : int) => (raise Fail "g") : int option) 1)
  val () = T.raises ("Option.composePartial/exception-of-f", T.isFail,
                     fn () => Option.composePartial (fn (_ : int) => (raise Fail "f") : int option, half) 2)

  (* ---- laws, on pseudo-random inputs ---- *)
  val () = T.seed 1
  val () = T.repeat (50, fn i =>
    let
      val n = Int.toString i
      fun randomOption () = if T.range (0, 3) = 0 then NONE else SOME (T.range (~50, 50))
      val opt = randomOption ()
      val x = T.range (~50, 50)
      val d = T.range (~50, 50)
      val a = T.range (2, 5)
      val b = T.range (~9, 9)
      fun f y = a * y + b
      fun g y = y * y - b
      (* partial functions: undefined on the multiples of a, of 3 *)
      fun p y = if y mod a = 0 then NONE else SOME (y + b)
      fun q y = if y mod 3 = 0 then NONE else SOME (y * a)
      fun positive y = y > b
      val nested = if T.range (0, 3) = 0 then NONE else SOME (randomOption ())
    in
      eqI ("Option.getOpt/law-" ^ n, case opt of SOME v => v | NONE => d, fn () => Option.getOpt (opt, d));
      eqB ("Option.isSome/law-" ^ n, opt <> NONE, fn () => Option.isSome opt);
      eqO ("Option.valOf/SOME-inverse-" ^ n, opt,
           fn () => if Option.isSome opt then SOME (Option.valOf opt) else NONE);
      eqO ("Option.filter/law-" ^ n, if positive x then SOME x else NONE, fn () => Option.filter positive x);
      eqO ("Option.join/SOME-" ^ n, opt, fn () => Option.join (SOME opt));
      eqO ("Option.join/map-SOME-" ^ n, opt, fn () => Option.join (Option.map SOME opt));
      eqO ("Option.join/nested-" ^ n, case nested of SOME inner => inner | NONE => NONE,
           fn () => Option.join nested);
      eqO ("Option.map/identity-" ^ n, opt, fn () => Option.map (fn y => y) opt);
      T.check ("Option.map/composition-" ^ n,
               fn () => Option.map (f o g) opt = Option.map f (Option.map g opt));
      eqO ("Option.map/by-cases-" ^ n, case opt of SOME v => SOME (f v) | NONE => NONE,
           fn () => Option.map f opt);
      eqL ("Option.app/by-cases-" ^ n, case opt of SOME v => [v] | NONE => [],
           fn () => let val (h, seen) = trace (fn _ => ()) in Option.app h opt; seen () end);
      (* "The expression mapPartial f is equivalent to join o (map f)" *)
      T.check ("Option.mapPartial/join-o-map-" ^ n,
               fn () => Option.mapPartial p opt = (Option.join o Option.map p) opt);
      eqO ("Option.mapPartial/by-cases-" ^ n, case opt of SOME v => p v | NONE => NONE,
           fn () => Option.mapPartial p opt);
      eqO ("Option.mapPartial/SOME-is-identity-" ^ n, opt, fn () => Option.mapPartial SOME opt);
      (* "The expression compose (f, g) is equivalent to (map f) o g" *)
      T.check ("Option.compose/map-o-" ^ n, fn () => Option.compose (f, p) x = (Option.map f o p) x);
      eqO ("Option.compose/by-cases-" ^ n, case p x of SOME v => SOME (f v) | NONE => NONE,
           fn () => Option.compose (f, p) x);
      (* "The expression composePartial (f, g) is equivalent to (mapPartial f) o g" *)
      T.check ("Option.composePartial/mapPartial-o-" ^ n,
               fn () => Option.composePartial (q, p) x = (Option.mapPartial q o p) x);
      eqO ("Option.composePartial/by-cases-" ^ n, case p x of SOME v => q v | NONE => NONE,
           fn () => Option.composePartial (q, p) x);
      eqO ("Option.composePartial/SOME-left-" ^ n, p x, fn () => Option.composePartial (SOME, p) x);
      eqO ("Option.composePartial/SOME-right-" ^ n, p x, fn () => Option.composePartial (p, SOME) x)
    end)
end
