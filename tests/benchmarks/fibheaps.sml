structure BenchFibHeapTests =
struct
  structure N = BenchFibHeapsFn(BenchNeed)
  structure S = BenchFibHeapsFn(BenchStrict)
  structure L = BenchLazy
  fun leaf key = N.value(N.Node(N.value key,N.Q.empty()))
  fun tag key = N.value(N.value 0,leaf key)
  fun integers xs = N.Q.fromList xs
  val _ = T.check("fibheaps/generated-prefix",fn () => N.Q.toList(N.randoms 3)=[1967,932,85])
  val _ = T.check("fibheaps/two-delete-methods",fn () =>
    N.Q.toList(N.sorted N.deleteMutable 100)=N.Q.toList(N.sorted N.deleteFunctional 100))
  val _ = T.check("fibheaps/strict-lazy",fn () =>
    N.Q.toList(N.sorted N.deleteMutable 100)=S.Q.toList(S.sorted S.deleteMutable 100) andalso
    S.Q.toList(S.sorted S.deleteMutable 100)=S.Q.toList(S.sorted S.deleteFunctional 100))
  val _ = T.check("fibheaps/empty-singleton",fn () =>
    N.Q.toList(N.sorted N.deleteMutable 0)=[] andalso N.Q.toList(N.sorted N.deleteFunctional 1)=[1967])
  val _ = T.check("fibheaps/bag-traversal-orders",fn () =>
    let val a=tag 1
        val b=tag 2
        val bag=N.value(N.ConsBag(a,N.value(N.ConsBag(b,N.emptyBag()))))
        val seen=ref([]:int list)
        val _=N.apply(fn (_,tree) => seen := !seen @ [N.root tree])bag
    in !seen=[1,2] andalso List.map(fn (_,tree) => N.root tree)(N.Q.toList(N.flatten bag(N.Q.empty())))=[2,1]end)
  val _ = T.check("fibheaps/link-tie-keeps-left",fn () =>
    let val left=N.value(N.Node(N.value 5,N.Q.fromList[leaf 1]))
        val right=N.value(N.Node(N.value 5,N.Q.fromList[leaf 2]))
        val N.Node(_,children)=L.force(N.link left right)
    in List.map N.root(N.Q.toList children)=[5,1]end)
  val badForest : N.bag L.delay = L.delay(fn () => raise Fail "unneeded forest")
  val badHeap=N.value(N.FH(N.value 2,tag 0,badForest))
  val _ = T.check("fibheaps/functional-header-defers-consolidation",fn () =>
    case L.force(N.deleteFunctional badHeap)of N.FH _ => true | _ => false)
  val _ = T.check("fibheaps/mutable-header-demands-array-build",fn () =>
    ((L.force(N.deleteMutable badHeap);false)handle Fail _ => true))
  val _ = T.check("fibheaps/functional-min-demands-shared-build",fn () =>
    ((case L.force(N.deleteFunctional badHeap)of N.FH(_,minimum,_) => N.taggedRoot minimum | _ => 0;false)handle Fail _ => true))
end
