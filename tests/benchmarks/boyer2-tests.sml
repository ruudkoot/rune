structure BoyerTwoNeed = BenchBoyerTwoFn (BenchNeed)
structure BoyerTwoStrict = BenchBoyerTwoFn (BenchStrict)
structure BoyerTwoNeedCheck = BoyerTwoNormalCheckFn (BoyerTwoNeed)
structure BoyerTwoStrictCheck = BoyerTwoNormalCheckFn (BoyerTwoStrict)
structure BoyerTwoTests =
struct
  structure N = BoyerTwoNeed
  structure S = BoyerTwoStrict
  fun isNil term = case BenchNeed.force term of N.Nil => true | _ => false
  val _ = T.check ("boyer2/original-rule-count", fn () => List.length BenchBoyerTwoRules.texts = 106)
  val _ = T.check ("boyer2/parentheses-without-spaces", fn () => N.equal (N.parse "(f(a)b)") (N.parse "( f ( a ) b )"))
  val _ = T.check ("boyer2/missing-close-source-acceptance", fn () => N.equal (N.parse "(f a") (N.parse "(f a)"))
  val _ = T.check ("boyer2/trailing-space-empty-token", fn () => N.tokens "a " = ["a", ""] andalso isNil (N.parse "(f a) "))
  val _ = T.check ("boyer2/tab-is-symbol-character", fn () => N.tokens "a\tb" = ["a\tb"])
  val _ = T.check ("boyer2/extra-close-rejected-as-nil", fn () => isNil (N.parse "(f a))"))
  val _ = T.check ("boyer2/noncons-selectors-return-nil", fn () => isNil (N.car (N.atom "x")) andalso isNil (N.cdr (N.emptyTerm ())))
  val _ = T.check ("boyer2/latest-rule-first", fn () =>
    let val tree = N.add ("f", N.parse "(one)", BenchNeed.delay (fn () => N.Empty))
        val tree = N.add ("f", N.parse "(two)", tree)
    in case BenchNeed.force (N.lookup "f" tree) of
      N.RCons (first, rest) => N.equal first (N.parse "(two)") andalso N.ruleCount rest = 1
    | _ => false end)
  val _ = T.check ("boyer2/first-list-prefix-unification", fn () =>
    let val (matched, bindings) = N.unify (N.parse "(f a)") (N.parse "(f x y)") (N.emptyTerm ())
    in matched andalso N.equal (N.applySubst bindings (N.atom "x")) (N.atom "a") end)
  val _ = T.check ("boyer2/extra-first-arguments-fail", fn () =>
    not (#1 (N.unify (N.parse "(f a b)") (N.parse "(f x)") (N.emptyTerm ()))))
  val _ = T.check ("boyer2/repeated-variable-consistent", fn () =>
    #1 (N.unify (N.parse "(f a a)") (N.parse "(f x x)") (N.emptyTerm ())) andalso
    not (#1 (N.unify (N.parse "(f a b)") (N.parse "(f x x)") (N.emptyTerm ()))))
  val _ = T.check ("boyer2/head-mismatch-does-not-demand-tail", fn () =>
    let val bad = BenchNeed.delay (fn () => raise Fail "tail demanded")
        val first = N.cons (N.atom "g") bad val second = N.cons (N.atom "f") bad
    in not (#1 (N.unify first second (N.emptyTerm ()))) end)
  val _ = T.check ("boyer2/source-malformed-rule-kept", fn () =>
    let val text = "(equal (difference (add1 (plus y z)z)(add1 y) )"
    in List.exists (fn rule => rule = text) BenchBoyerTwoRules.texts andalso isNil (N.caddr (N.parse text)) end)
  val _ = T.check ("boyer2/substitution-preserves-function-head", fn () =>
    N.equal (N.applySubst (N.parse "((f replacement)(x value))") (N.parse "(f x)")) (N.parse "(f (value))"))
  val _ = T.check ("boyer2/tautology-true-and-false", fn () =>
    N.tautologyp (N.parse "(t)") (N.emptyTerm ()) (N.emptyTerm ()) andalso
    not (N.tautologyp (N.parse "(f)") (N.emptyTerm ()) (N.emptyTerm ())))
  val _ = T.check ("boyer2/if-assumption-branches", fn () =>
    N.tautologyp (N.parse "(if x x (t))") (N.emptyTerm ()) (N.emptyTerm ()) andalso
    not (N.tautologyp (N.parse "(if x (f) (f))") (N.emptyTerm ()) (N.emptyTerm ())))
  val _ = T.check ("boyer2/complete-lazy-normal-form", fn () => (BoyerTwoNeedCheck.run 1 "1.normal"; true))
  val _ = T.check ("boyer2/complete-strict-normal-form", fn () => (BoyerTwoStrictCheck.run 1 "1.normal"; true))
  val _ = List.app (fn i => T.check ("boyer2/source-theorem-" ^ Int.toString i,
    fn () => N.test i andalso S.test i)) [1,2,60,600]
  fun rejects path = (BoyerTwoNeedCheck.run 1 path; false) handle Fail message => String.isPrefix "incorrect result:" message
  val _ = T.check ("boyer2/wrong-normal-form-rejected", fn () => rejects "wrong.normal")
  val _ = T.check ("boyer2/truncated-normal-form-rejected", fn () => rejects "truncated.normal")
  val _ = T.check ("boyer2/extra-normal-form-rejected", fn () => rejects "extra.normal")
end
