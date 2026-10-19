structure InferNeed = BenchInferFn (BenchNeed)
structure InferStrict = BenchInferFn (BenchStrict)
structure NeedDriver = BenchInferDriverFn (InferNeed)
structure StrictDriver = BenchInferDriverFn (InferStrict)
structure InferTests =
struct
  structure N = InferNeed
  structure S = InferStrict
  fun hash text = Word64.fromLargeInt (valOf (IntInf.fromString text))
  val _ = List.app (fn (profile,input,bytes,expectedHash) =>
    (T.check ("infer/full-lazy-" ^ profile, fn () => NeedDriver.check input (profile ^ ".text") (hash expectedHash) = bytes);
     T.check ("infer/full-strict-" ^ profile, fn () => StrictDriver.check input (profile ^ ".text") (hash expectedHash) = bytes))) InferCaseData.profiles
  val _ = List.app (fn (i,bytes,expectedHash) =>
    let val prefix = "edge-" ^ Int.toString i
    in T.check ("infer/lazy-" ^ prefix, fn () => NeedDriver.check (prefix ^ ".input") (prefix ^ ".text") (hash expectedHash) = bytes);
       T.check ("infer/strict-" ^ prefix, fn () => StrictDriver.check (prefix ^ ".input") (prefix ^ ".text") (hash expectedHash) = bytes)
    end) InferCaseData.edges
  val _ = T.check ("infer/cut-shares-value-and-rest", fn () =>
    let val calls = ref 0
        fun producer input = (calls := !calls+1; N.P.returnP (BenchNeed.delay (fn () => "yes")) input)
        val result = N.P.cutP producer (BenchNeed.delay (fn () => [#"q"]))
        val initial = !calls
        val pair = case N.P.expose result of N.P.Cons (pair,_) => BenchNeed.force pair | _ => raise Fail "missing cut result"
        val (value,rest) = pair
        val callsBefore = !calls
    in initial=0 andalso callsBefore=0 andalso BenchNeed.force value="yes"
       andalso BenchNeed.force rest=[#"q"] andalso !calls=1 end)
  val _ = T.check ("infer/strict-cut-shares-result", fn () =>
    let val calls = ref 0
        fun producer input = (calls := !calls+1; S.P.returnP "yes" input)
        val result = S.P.cutP producer [#"q"]
        val (value,rest) = case S.P.expose result of S.P.Cons (pair,_) => pair | _ => raise Fail "missing cut result"
    in value="yes" andalso rest=[#"q"] andalso !calls=1 end)
  val _ = T.check ("infer/lazy-cut-prunes-right-branch", fn () =>
    let fun unused _ = raise Fail "unused parser branch"
    in N.P.useP "bad" (N.P.cutP (N.P.elseP (N.P.returnP (BenchNeed.delay (fn () => "yes"))) unused)) "" = "yes" end)
  val _ = T.check ("infer/strict-cut-prunes-right-branch", fn () =>
    let fun unused _ = raise Fail "unused parser branch"
    in S.P.useP "bad" (S.P.cutP (S.P.elseP (S.P.returnP "yes") unused)) "" = "yes" end)
  val _ = T.check ("infer/greedy-cut-does-not-backtrack", fn () =>
    N.P.useP #"#" (N.P.lexactlyP (N.P.thenP (N.P.starP N.P.alphaP) (fn _ => N.P.litP #"a"))) "a" = #"#")
  val _ = T.check ("infer/strict-greedy-cut-does-not-backtrack", fn () =>
    S.P.useP #"#" (S.P.lexactlyP (S.P.thenP (S.P.starP S.P.alphaP) (fn _ => S.P.litP #"a"))) "a" = #"#")
  val _ = T.check ("infer/empty-cut-preserves-irrefutable-head", fn () =>
    let val result = N.P.cutP (fn _ => N.P.empty ()) (BenchNeed.delay (fn () => []))
        val (value,_) = case N.P.expose result of N.P.Cons (pair,_) => BenchNeed.force pair | _ => raise Fail "empty cut lost head"
    in (ignore (BenchNeed.force value); false) handle Fail _ => true end)
  val _ = T.check ("infer/constructor-mismatch-avoids-arguments", fn () =>
    let val bad = N.P.defer (fn () => raise Fail "unused arguments")
    in not (Option.isSome (N.unify (BenchNeed.delay (fn () => N.TCon ("A",bad)))
      (BenchNeed.delay (fn () => N.TCon ("B",N.P.empty ()))) (N.P.empty ()))) end)
  val _ = T.check ("infer/strict-constructor-mismatch-avoids-arguments", fn () =>
    let val bad = S.P.defer (fn () => raise Fail "unused arguments")
    in not (Option.isSome (S.unify (S.TCon ("A",bad)) (S.TCon ("B",S.P.empty ())) (S.P.empty ()))) end)
  val _ = T.check ("infer/occurs-check", fn () =>
    let val x = BenchNeed.delay (fn () => N.TVar "x")
    in not (Option.isSome (N.unify x (BenchNeed.delay (fn () => N.TCon ("List",N.P.single x))) (N.P.empty ()))) end)
  val _ = T.check ("infer/strict-occurs-check", fn () =>
    not (Option.isSome (S.unify (S.TVar "x") (S.TCon ("List",S.P.single (S.TVar "x"))) (S.P.empty ()))))
  val _ = T.check ("infer/source-substitution-order-and-duplicates", fn () =>
    let val first = N.extendSub (N.P.empty ()) "x" (BenchNeed.delay (fn () => N.TVar "y"))
        val second = N.extendSub first "y" (BenchNeed.delay (fn () => N.TCon ("List",N.P.single (BenchNeed.delay (fn () => N.TVar "z")))))
        val third = N.extendSub second "x" (BenchNeed.delay (fn () => N.TVar "w"))
        val keys = List.map (fn (name,_) => name) (N.P.toList third)
    in keys=["x","y","x"] andalso String.implode (N.P.toList (N.showMono 0 (N.lookupSub third "x")))="w"
       andalso String.implode (N.P.toList (N.showMono 0 (N.lookupSub third "y")))="List z" end)
  val _ = T.check ("infer/source-shadowed-environment-free-variables", fn () =>
    let val old = N.extend (N.P.empty ()) "x" (N.All (N.P.empty (),BenchNeed.delay (fn () => N.TVar "a")))
        val env = N.extend old "x" (N.All (N.P.empty (),BenchNeed.delay (fn () => N.TVar "b")))
    in N.P.toList (N.freeEnv env)=["b","a"] end)
  val _ = T.check ("infer/source-generalisation-sees-shadowed-entry", fn () =>
    let val old = N.extend (N.P.empty ()) "x" (N.All (N.P.empty (),BenchNeed.delay (fn () => N.TVar "a")))
        val env = N.extend old "x" (N.All (N.P.empty (),BenchNeed.delay (fn () => N.TVar "b")))
    in case N.generaliseI env (BenchNeed.delay (fn () => N.TVar "a")) (N.P.empty ()) 0 of
       SOME ((N.All (names,_),_),_) => List.null (N.P.toList names) | _ => false end)
  val _ = T.check ("infer/source-arity-mismatch-is-partial", fn () =>
    let val first = BenchNeed.delay (fn () => N.TCon ("F",N.P.empty ()))
        val second = BenchNeed.delay (fn () => N.TCon ("F",N.P.single (BenchNeed.delay (fn () => N.TVar "x"))))
    in (ignore (N.unify first second (N.P.empty ())); false)
       handle Fail text => String.isPrefix "infer unifies:" text end)
  fun reject reference expectedHash =
    (ignore (NeedDriver.check "infer.faststdin" reference (hash expectedHash)); false)
    handle Fail text => String.isPrefix "incorrect result:" text
  val _ = T.check ("infer/wrong-output-rejected", fn () => reject "wrong.text" "13194159443869525036")
  val _ = T.check ("infer/truncated-output-rejected", fn () => reject "truncated.text" "13194159443869525036")
  val _ = T.check ("infer/extra-output-rejected", fn () => reject "extra.text" "13194159443869525036")
  val _ = T.check ("infer/wrong-hash-rejected", fn () => reject "smoke.text" "0")
  val _ = T.check ("infer/line-splitting", fn () => N.lines ""=[] andalso N.lines "\n"=[""] andalso N.lines "x\n\n"=["x",""])
end
