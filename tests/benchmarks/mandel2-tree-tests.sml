structure MandelTwoNeed = BenchMandelTwoFn (structure D = BenchNeed structure P = BenchMandelTwoPoint)
structure MandelTwoStrict = BenchMandelTwoFn (structure D = BenchStrict structure P = BenchMandelTwoPoint)
structure MandelTwoNeedCheck = MandelTreeCheckFn (MandelTwoNeed)
structure MandelTwoStrictCheck = MandelTreeCheckFn (MandelTwoStrict)
structure MandelTwoTreeTests =
struct
  val expected = [(1,3),(2,1),(3,1),(8,1),(16,37),(64,115),(200,7993)]
  val _ = List.app (fn (width, count) =>
    (T.check ("mandel2/complete-lazy-tree-" ^ Int.toString width, fn () =>
       MandelTwoNeedCheck.run width (Int.toString width ^ ".tree") = count);
     T.check ("mandel2/complete-strict-tree-" ^ Int.toString width, fn () =>
       MandelTwoStrictCheck.run width (Int.toString width ^ ".tree") = count))) expected
  fun rejects path = (ignore (MandelTwoNeedCheck.run 64 path); false)
    handle Fail message => String.isPrefix "incorrect result:" message
  val _ = T.check ("mandel2/wrong-colour-rejected", fn () => rejects "wrong.tree")
  val _ = T.check ("mandel2/truncated-tree-rejected", fn () => rejects "truncated.tree")
  val _ = T.check ("mandel2/extra-tree-rejected", fn () => rejects "extra.tree")
  val _ = T.check ("mandel2/wrong-branch-rejected", fn () => rejects "wrong-tag.tree")
end
