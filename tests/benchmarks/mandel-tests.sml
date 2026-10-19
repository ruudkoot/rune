structure MandelDoubleTests =
struct
  structure B = BenchMandelDouble
  structure L = BenchLazy
  val _ = T.check ("mandel/new-zero-limit-does-not-demand-coordinate", fn () =>
    let val c = L.delay (fn () => raise Fail "coordinate demanded")
    in B.lazyNew B.generic 0 2.0 c = 0 end)
  val _ = T.check ("mandel/old-zero-limit-demands-coordinate", fn () =>
    let val calls = ref 0 val c = L.delay (fn () => (calls := !calls + 1; (0.0, 0.0)))
    in B.lazyOld B.oldStep 0 4.0 c = 0 andalso !calls = 1 end)
  val _ = T.check ("mandel/new-boundary-strict-greater", fn () =>
    B.lazyNew B.generic 1 2.0 (L.delay (fn () => (2.0, 0.0))) = 1)
  val _ = T.check ("mandel/old-boundary-inclusive", fn () =>
    B.lazyOld B.oldStep 1 4.0 (L.delay (fn () => (2.0, 0.0))) = 0)
  val _ = T.check ("mandel/new-limit-does-not-force-next-orbit", fn () =>
    let val steps = ref 0 fun step c z = (steps := !steps + 1; B.generic c z)
    in B.lazyNew step 1 2.0 (L.delay (fn () => (0.0, 0.0))) = 1 andalso !steps = 0 end)
  val _ = T.check ("mandel/old-limit-forces-next-orbit", fn () =>
    let val steps = ref 0 fun step c z = (steps := !steps + 1; B.oldStep c z)
    in B.lazyOld step 1 4.0 (L.delay (fn () => (0.0, 0.0))) = 1 andalso !steps = 1 end)
  val _ = T.check ("mandel/cyclic-orbit-heads-and-spines-share", fn () =>
    let val steps = ref 0 val coordinates = ref 0
        val c = L.delay (fn () => (coordinates := !coordinates + 1; (0.0, 0.0)))
        fun step c z = (steps := !steps + 1; B.generic c z)
        val xs = B.orbit step c
        val _ = BenchStream.nth xs 3 val stepCount = !steps
        val _ = BenchStream.nth xs 3
    in stepCount = 3 andalso !steps = 3 andalso !coordinates = 1 end)
  val _ = T.check ("mandel/strict-new-finite-prefix-exact-limit", fn () =>
    let val steps = ref 0 fun step c z = (steps := !steps + 1; B.generic c z)
    in B.strictNew step 1 2.0 (0.0, 0.0) = 1 andalso !steps = 0 end)
  val _ = T.check ("mandel/strict-old-finite-prefix-extra-head", fn () =>
    let val steps = ref 0 fun step c z = (steps := !steps + 1; B.oldStep c z)
    in B.strictOld step 1 4.0 (0.0, 0.0) = 1 andalso !steps = 1 end)
  val _ = T.check ("mandel/strict-work-after-escape-is-explicit", fn () =>
    let val lazySteps = ref 0 val strictSteps = ref 0
        fun lazyStep c z = (lazySteps := !lazySteps + 1; B.generic c z)
        fun strictStep c z = (strictSteps := !strictSteps + 1; B.generic c z)
        val a = B.lazyNew lazyStep 3 2.0 (L.delay (fn () => (2.0, 0.0)))
        val b = B.strictNew strictStep 3 2.0 (2.0, 0.0)
    in a = 1 andalso b = 1 andalso !lazySteps = 1 andalso !strictSteps = 2 end)
  val _ = List.app (fn old => List.app (fn strict =>
    T.check ("mandel/full-source-rgb-" ^ (if old then "old" else "new") ^ (if strict then "-strict" else "-lazy"),
      fn () => (MandelDoubleCheck.run old strict 25 25 75 ((if old then "old" else "new") ^ "-25-25-75.rgb"); true)))
    [false, true]) [false, true]
  structure NewLazyDigest = MandelDigestFn (struct
    type pixels = (int * int * int) BenchStream.stream
    val make = B.makeLazy false val app = B.appLazy
  end)
  structure NewStrictDigest = MandelDigestFn (struct
    type pixels = (int * int * int) list
    val make = B.makeStrict false val app = B.appStrict
  end)
  structure OldLazyDigest = MandelDigestFn (struct
    type pixels = (int * int * int) BenchStream.stream
    val make = B.makeLazy true val app = B.appLazy
  end)
  structure OldStrictDigest = MandelDigestFn (struct
    type pixels = (int * int * int) list
    val make = B.makeStrict true val app = B.appStrict
  end)
  val viewport = (~2.0, ~2.0, 2.0, 2.0)
  val _ = T.check ("mandel/full-new-lazy-digest", fn () => (NewLazyDigest.run viewport 25 25 75 "new-25-25-75.digest"; true))
  val _ = T.check ("mandel/full-new-strict-digest", fn () => (NewStrictDigest.run viewport 25 25 75 "new-25-25-75.digest"; true))
  val _ = T.check ("mandel/full-old-lazy-digest", fn () => (OldLazyDigest.run viewport 25 25 75 "old-25-25-75.digest"; true))
  val _ = T.check ("mandel/full-old-strict-digest", fn () => (OldStrictDigest.run viewport 25 25 75 "old-25-25-75.digest"; true))
  fun rejectsDigest path = (NewLazyDigest.run viewport 7 5 75 path; false)
    handle Fail message => String.isPrefix "incorrect result:" message
  val _ = T.check ("mandel/wrong-digest-rejected", fn () => rejectsDigest "wrong.digest")
  val _ = T.check ("mandel/wrong-metadata-rejected", fn () => rejectsDigest "wrong-meta.digest")
  val _ = T.check ("mandel/wrong-count-rejected", fn () => rejectsDigest "wrong-count.digest")
  val _ = T.check ("mandel/extra-digest-rejected", fn () => rejectsDigest "extra.digest")
  val _ = T.check ("mandel/empty-digest-rejected", fn () => rejectsDigest "empty.digest")
  fun rejects path = (MandelDoubleCheck.run false false 7 5 75 path; false) handle Fail _ => true
  val _ = T.check ("mandel/wrong-rgb-rejected", fn () => rejects "wrong.rgb")
  val _ = T.check ("mandel/truncated-rejected", fn () => rejects "truncated.rgb")
  val _ = T.check ("mandel/extra-rejected", fn () => rejects "extra.rgb")
end
