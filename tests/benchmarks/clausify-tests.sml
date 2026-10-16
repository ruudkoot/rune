structure ClausifyTests =
struct
  structure L = BenchClausifyFn(BenchNeed)
  structure E = BenchClausifyFn(BenchStrict)
  fun file path = let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input; text end
  fun lazyText text = L.text(L.clauses(String.explode text))
  fun strictText text = E.text(E.clauses(String.explode text))
  val cases = [
    ("000","a"),
    ("001","~a"),
    ("002","a|~a"),
    ("003","a&a"),
    ("004","a|b"),
    ("005","a&b"),
    ("006","a>b"),
    ("007","a=b"),
    ("008","a=b=c"),
    ("009","a>b>c"),
    ("010","~(a|b)"),
    ("011","~(a&b)"),
    ("012","~~a"),
    ("013","(a&b)|(c&d)"),
    ("014","(a=b)=(b=c)"),
    ("015","(a = a = a) = (a = a = a) = (a = a = a)"),
    ("016","(a=b)=c"),
    ("017","(a=b)>c"),
    ("018","(a=b)|c"),
    ("019","(a=b)&c"),
    ("020","(a>b)=c"),
    ("021","(a>b)>c"),
    ("022","(a>b)|c"),
    ("023","(a>b)&c"),
    ("024","(a|b)=c"),
    ("025","(a|b)>c"),
    ("026","(a|b)|c"),
    ("027","(a|b)&c"),
    ("028","(a&b)=c"),
    ("029","(a&b)>c"),
    ("030","(a&b)|c"),
    ("031","(a&b)&c"),
    ("032","(a=a)=b"),
    ("033","(a=a)>b"),
    ("034","(a=a)|b"),
    ("035","(a=a)&b"),
    ("036","(a>a)=b"),
    ("037","(a>a)>b"),
    ("038","(a>a)|b"),
    ("039","(a>a)&b"),
    ("040","(a|a)=b"),
    ("041","(a|a)>b"),
    ("042","(a|a)|b"),
    ("043","(a|a)&b"),
    ("044","(a&a)=b"),
    ("045","(a&a)>b"),
    ("046","(a&a)|b"),
    ("047","(a&a)&b")
  ]
  val _ = List.app(fn (id,formula) => T.check("clausify/corpus-"^id,fn () =>
    let val expected=file("case-"^id^".expected")
    in lazyText formula=expected andalso strictText formula=expected end)) cases
  val _ = T.check("clausify/full-sample-and-empty",fn () =>
    L.text(L.result 1)="a <= \n" andalso E.text(E.result 1)="a <= \n"
    andalso L.text(L.result 0)="" andalso E.text(E.result 0)="")
  val _ = T.check("clausify/reject-perturbed-result",fn () =>
    ((L.checked "b <= \n" 1; false) handle Fail _ => true))
  val _ = T.check("clausify/reject-short-result",fn () =>
    ((L.checked "a <= \nextra" 1; false) handle Fail _ => true))
  val _ = T.check("clausify/reject-long-result",fn () =>
    ((E.checked "a <=" 1; false) handle Fail _ => true))
  val _ = T.check("clausify/right-distribution-defers-left",fn () =>
    let val bad=BenchNeed.delay(fn () => raise Fail "unused formula")
        val right=L.conjoin(L.symbol #"a")(L.symbol #"b")
    in case BenchNeed.force(L.disin(L.disjoin bad right)) of
        L.Con _ => true | _ => false end)
  val _ = T.check("clausify/split-prefix-defers-right",fn () =>
    let val bad=BenchNeed.delay(fn () => raise Fail "unused conjunction")
        val pieces=L.split(L.conjoin(L.symbol #"a")bad)
    in case L.Q.head pieces of L.Sym c => c= #"a" | _ => false end)
  val _ = T.check("clausify/tautology-short-circuits",fn () =>
    let val bad=BenchNeed.delay(fn () => raise Fail "unused positive tail")
        val positives=L.Q.cons(L.value #"a")bad
    in L.tautology(L.value(positives,L.Q.fromList[#"a"])) end)
  val _ = T.check("clausify/lexicographic-second-field-undemanded",fn () =>
    let val bad=BenchNeed.delay(fn () => raise Fail "unused negative field")
    in L.compareClause((L.Q.fromList[#"a"],bad),(L.Q.fromList[#"b"],bad))=LESS end)
  val _ = T.check("clausify/ordered-insertion-defers-tail",fn () =>
    let val bad=BenchNeed.delay(fn () => raise Fail "unused ordered tail")
        val xs=L.Q.cons(L.value #"b")bad
    in L.Q.head(L.insert Char.compare (L.value #"a")xs)= #"a" end)
  val _ = T.check("clausify/shared-elimination",fn () =>
    let val calls=ref 0
        val p=BenchNeed.delay(fn () => (calls:= !calls+1; L.Sym #"a"))
        val result=L.elim p
        val _=BenchNeed.force result
        val _=BenchNeed.force result
    in !calls=1 end)
  val _ = T.check("clausify/strict-materialization",fn () =>
    let val lazyCalls=ref 0 val strictCalls=ref 0
        val lright=BenchNeed.delay(fn () => (lazyCalls:= !lazyCalls+1; L.Sym #"b"))
        val eright=BenchStrict.delay(fn () => (strictCalls:= !strictCalls+1; E.Sym #"b"))
        val lp=L.split(L.conjoin(L.symbol #"a")lright)
        val ep=E.split(E.conjoin(E.symbol #"a")eright)
        val _=L.Q.head lp val _=E.Q.head ep
    in !lazyCalls=0 andalso !strictCalls=1 end)
end
