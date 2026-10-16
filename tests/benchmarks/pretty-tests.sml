structure PrettyNeed = BenchPrettyFn (BenchNeed)
structure PrettyStrict = BenchPrettyFn (BenchStrict)
structure PrettyNeedCheck = PrettyCheckFn (PrettyNeed)
structure PrettyStrictCheck = PrettyCheckFn (PrettyStrict)
structure PrettyTests =
struct
  structure N = PrettyNeed
  structure S = BenchStream
  structure L = BenchLazy
  fun string text =
    let val chars = ref [] val _ = N.app (fn c => chars := c :: !chars) text
    in String.implode (List.rev (!chars)) end
  fun show width doc = string (N.show width doc)
  val _ = List.app (fn (width, words) =>
    (T.check ("pretty/source-layout-lazy-" ^ Int.toString width ^ "-" ^ Int.toString words, fn () =>
       PrettyNeedCheck.run width words (Int.toString width ^ "-" ^ Int.toString words ^ ".output") >= 0);
     T.check ("pretty/source-layout-strict-" ^ Int.toString width ^ "-" ^ Int.toString words, fn () =>
       PrettyStrictCheck.run width words (Int.toString width ^ "-" ^ Int.toString words ^ ".output") >= 0)))
    [(0,0),(10,0),(18,0),(80,0),(22,1),(23,1),(20,10),(80,50),(317,50),(318,50)]
  fun edge (name, doc, width) = T.check ("pretty/edge-" ^ name, fn () =>
    let val input = TextIO.openIn ("edge-" ^ name ^ ".output") val expected = TextIO.inputAll input
        val _ = TextIO.closeIn input
    in show width doc = expected end)
  val _ = List.app edge [("nil",N.nilDoc,80),("empty-string",N.ofString "",80),
    ("beside",N.beside(N.ofString "a")(N.ofString "b"),80),
    ("cat",N.cat(S.fromList[N.ofString "a",N.ofString "b"]),80),
    ("above-nil",N.above(N.ofString "a")N.nilDoc,80),
    ("above-empty-string",N.above(N.ofString "a")(N.ofString ""),80),
    ("nest-horizontal",N.nest 8(N.above(N.ofString "a")(N.ofString "b")),80),
    ("nest-vertical",N.above N.nilDoc(N.nest 8(N.above(N.ofString "a")(N.ofString "b"))),80),
    ("embedded-newline",N.above N.nilDoc(N.nest 8(N.ofString "a\nb")),80),
    ("sep-fit",N.sep(S.fromList[N.ofString "aaa",N.ofString "bbb"]),7),
    ("sep-wrap",N.sep(S.fromList[N.ofString "aaa",N.ofString "bbb"]),6)]
  val _ = T.check ("pretty/negative-width-short-circuits-documents", fn () =>
    let fun bad _ _ = raise Fail "document demanded"
    in not (N.fits (N.beside bad bad (~1) false)) end)
  val _ = T.check ("pretty/unused-hang-alternative-not-demanded", fn () =>
    let fun second width vertical = if width=72 then raise Fail "unused alternative demanded" else N.nilDoc width vertical
    in show 80 (N.hang(N.ofString "This is the label")8 second) = "This is the label " end)
  val _ = T.check ("pretty/empty-first-hang-uses-original-context", fn () =>
    let val calls = ref []
        fun second width vertical = (calls := (width,vertical):: !calls; N.ofString "x" width vertical)
        val result = string (N.flatten(BenchNeed.delay(fn()=>0))true(N.seq(N.hang N.nilDoc 8 second 80 true))[])
    in result = "x" andalso !calls = [(80,true)] end)
  val _ = T.check ("pretty/metadata-and-text-share-child-results", fn () =>
    let val first = ref 0 val second = ref 0
        fun a w v = (first := !first+1; N.ofString "xy" w v)
        fun b w v = (second := !second+1; N.char #"@" w v)
        val r = N.beside a b 80 false
        val count = N.last r val fit = N.fits r val empty = N.empty r
        val text = string(N.flatten(BenchNeed.delay(fn()=>0))true(N.seq r)[])
    in count=3 andalso fit andalso not empty andalso text="xy@" andalso !first=1 andalso !second=1 end)
  val _ = T.check ("pretty/nil-does-not-demand-indentation", fn () =>
    string(N.flatten(BenchNeed.delay(fn()=>raise Fail "indent demanded"))true N.cNil[])="")
  val _ = T.check ("pretty/indent-nil-does-not-demand-amount", fn () =>
    string(N.flatten(BenchNeed.delay(fn()=>0))true(N.cIndent(BenchNeed.delay(fn()=>raise Fail "indent demanded"))N.cNil)[])="")
  val _ = T.check ("pretty/sep-does-not-demand-unused-vertical-layout", fn () =>
    let fun word s width vertical = if vertical then raise Fail "unused vertical layout" else N.ofString s width vertical
    in show 80(N.sep(S.fromList[word "a",word "b"]))="a b" end)
  fun rejects path = (ignore(PrettyNeedCheck.run 80 50 path);false)
    handle Fail message => String.isPrefix "incorrect result:" message
  val _ = T.check ("pretty/wrong-byte-rejected",fn()=>rejects "wrong.output")
  val _ = T.check ("pretty/space-for-tab-rejected",fn()=>rejects "wrong-whitespace.output")
  val _ = T.check ("pretty/truncated-rejected",fn()=>rejects "truncated.output")
  val _ = T.check ("pretty/extra-rejected",fn()=>rejects "extra.output")
end
