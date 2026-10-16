structure NeedAtom=BenchAtomFn(BenchNeed)
structure StrictAtom=BenchAtomFn(BenchStrict)
structure NeedDriver=BenchAtomDriverFn(NeedAtom)
structure StrictDriver=BenchAtomDriverFn(StrictAtom)
structure AtomTests =
struct
  structure N=NeedAtom
  structure R=StrictAtom
  structure L=BenchLazy
  structure S=BenchStream
  fun read name=let val f=TextIO.openIn name val data=TextIO.inputAll f val _=TextIO.closeIn f in data end
  fun word s=case Word32.fromString s of SOME n=>n|NONE=>raise Fail "invalid bits"
  fun expected n=Vector.fromList(List.map word(String.tokens Char.isSpace(read(Int.toString n^".positions"))))
  fun vectorN xs=(case BenchNeed.force xs of N.Nil=>[]|N.Cons(x,xs)=>N.bits(BenchNeed.force x)::vectorN xs)
  fun vectorR xs=(case BenchStrict.force xs of R.Nil=>[]|R.Cons(x,xs)=>R.bits(BenchStrict.force x)::vectorR xs)
  fun stateN value=let val N.State(p,v)=L.force value in(vectorN p,vectorN v)end
  fun stateR value=let val R.State(p,v)=L.force value in(vectorR p,vectorR v)end
  fun firstN 0 states=[]|firstN n states=(case L.force states of S.Nil=>raise Empty|S.Cons(value,rest)=>stateN value::firstN(n-1)rest)
  fun firstR 0 states=[]|firstR n states=(case L.force states of S.Nil=>raise Empty|S.Cons(value,rest)=>stateR value::firstR(n-1)rest)
  val stateExpected=List.map(fn line=>case String.tokens Char.isSpace line of [p,v]=>([word p],[word v])|_=>raise Fail "state tuple")(String.tokens(fn c=>Char.ord c=10)(read "states.data"))
  fun observeN n=
    let val hits=ref 0
        fun law param stream=S.map(fn vector=>(hits:= !hits+1;vector))(N.forceLaw param stream)
        val initial=L.delay(fn()=>N.State(N.fromList[1.0],N.fromList[0.0]))
        fun walk 0 xs=()|walk n xs=(case L.force xs of S.Nil=>raise Empty|S.Cons(value,rest)=>
          let val N.State(p,_)=L.force value val _=case BenchNeed.force p of N.Cons(x,_)=>ignore(BenchNeed.force x)|_=>raise Empty
          in walk(n-1)rest end)
        val _=walk n(N.experiment law N.dt(N.fromList[1.0])initial)
    in !hits end
  fun observeR n=
    let val hits=ref 0
        fun law param stream=S.map(fn vector=>(hits:= !hits+1;vector))(R.forceLaw param stream)
        val initial=L.delay(fn()=>R.State(R.fromList[1.0],R.fromList[0.0]))
        fun walk 0 xs=()|walk n xs=(case L.force xs of S.Nil=>raise Empty|S.Cons(value,rest)=>
          let val R.State(p,_)=L.force value val _=case BenchStrict.force p of R.Cons(x,_)=>ignore(BenchStrict.force x)|_=>raise Empty
          in walk(n-1)rest end)
        val _=walk n(R.experiment law R.dt(R.fromList[1.0])initial)
    in !hits end

  val _=T.check("atom/lazy-position-prefix-0",fn()=>N.run 0(expected 0)="0:811C9DC5")
  val _=T.check("atom/strict-position-prefix-0",fn()=>R.run 0(expected 0)="0:811C9DC5")
  val _=T.check("atom/lazy-position-prefix-1",fn()=>N.run 1(expected 1)="1:D58C5D1F")
  val _=T.check("atom/strict-position-prefix-1",fn()=>R.run 1(expected 1)="1:D58C5D1F")
  val _=T.check("atom/lazy-position-prefix-2",fn()=>N.run 2(expected 2)="2:907697CD")
  val _=T.check("atom/strict-position-prefix-2",fn()=>R.run 2(expected 2)="2:907697CD")
  val _=T.check("atom/lazy-position-prefix-3",fn()=>N.run 3(expected 3)="3:8FDE7C4C")
  val _=T.check("atom/strict-position-prefix-3",fn()=>R.run 3(expected 3)="3:8FDE7C4C")
  val _=T.check("atom/lazy-position-prefix-6",fn()=>N.run 6(expected 6)="6:104B8664")
  val _=T.check("atom/strict-position-prefix-6",fn()=>R.run 6(expected 6)="6:104B8664")
  val _=T.check("atom/lazy-position-prefix-16",fn()=>N.run 16(expected 16)="16:A0326D7A")
  val _=T.check("atom/strict-position-prefix-16",fn()=>R.run 16(expected 16)="16:A0326D7A")
  val _=T.check("atom/lazy-position-prefix-100",fn()=>N.run 100(expected 100)="100:43577C23")
  val _=T.check("atom/strict-position-prefix-100",fn()=>R.run 100(expected 100)="100:43577C23")
  val _=T.check("atom/unshared-lazy-force-count-0",fn()=>observeN 0=0)
  val _=T.check("atom/unshared-strict-force-count-0",fn()=>observeR 0=0)
  val _=T.check("atom/unshared-lazy-force-count-1",fn()=>observeN 1=0)
  val _=T.check("atom/unshared-strict-force-count-1",fn()=>observeR 1=0)
  val _=T.check("atom/unshared-lazy-force-count-2",fn()=>observeN 2=0)
  val _=T.check("atom/unshared-strict-force-count-2",fn()=>observeR 2=1)
  val _=T.check("atom/unshared-lazy-force-count-3",fn()=>observeN 3=1)
  val _=T.check("atom/unshared-strict-force-count-3",fn()=>observeR 3=3)
  val _=T.check("atom/unshared-lazy-force-count-4",fn()=>observeN 4=3)
  val _=T.check("atom/unshared-strict-force-count-4",fn()=>observeR 4=6)
  val _=T.check("atom/unshared-lazy-force-count-5",fn()=>observeN 5=6)
  val _=T.check("atom/unshared-strict-force-count-5",fn()=>observeR 5=10)
  val _=T.check("atom/unshared-lazy-force-count-6",fn()=>observeN 6=10)
  val _=T.check("atom/unshared-strict-force-count-6",fn()=>observeR 6=15)
  val _=T.check("atom/lazy-full-state-bits",fn()=>firstN 16(N.start())=stateExpected)
  val _=T.check("atom/strict-full-state-bits",fn()=>firstR 16(R.start())=stateExpected)
  val _=T.check("atom/lazy-positions-do-not-demand-unused-force",fn()=>
    let fun bad _ stream=S.map(fn _=>raise Fail "force demanded")stream
        val stream=N.experiment bad N.dt(N.fromList[1.0])(L.delay(fn()=>N.State(N.fromList[1.0],N.fromList[0.0])))
        fun positions 0 _=()|positions n stream=(case L.force stream of S.Nil=>raise Empty|S.Cons(value,rest)=>
          let val N.State(p,_)=L.force value val _=vectorN p in positions(n-1)rest end)
    in positions 2 stream;true end)
  val _=T.check("atom/next-position-demands-force",fn()=>
    let fun bad _ stream=S.map(fn _=>raise Fail "force demanded")stream
        val stream=N.experiment bad N.dt(N.fromList[1.0])(L.delay(fn()=>N.State(N.fromList[1.0],N.fromList[0.0])))
        fun positions 0 _=()|positions n stream=(case L.force stream of S.Nil=>raise Empty|S.Cons(value,rest)=>
          let val N.State(p,_)=L.force value val _=vectorN p in positions(n-1)rest end)
    in ((positions 3 stream;false)handle Fail s=>s="force demanded")end)
  val _=T.check("atom/source-vector-multiply-right-tail-square",fn()=>
    vectorN(N.multiply(N.fromList[1.0,3.0])(N.fromList[2.0,4.0]))=[0wx40000000,0wx41800000])
  val _=T.check("atom/source-force-two-dimensions",fn()=>
    let val initial=L.delay(fn()=>N.State(N.fromList[1.0,2.0],N.fromList[0.0,0.0]))
        val law=N.forceLaw(N.fromList[1.0,3.0])(S.cons(initial,S.empty()))
        val force=case L.force law of S.Cons(value,_)=>value|_=>raise Empty
        val propagated=L.delay(fn()=>N.propagate N.dt force initial)
    in vectorN(L.force force)=[0wxBF800000,0wx40800000]andalso
       stateN propagated=([0wx3F800000,0wx40000000],[0wxBCA3D70A,0wx3DA3D70A])end)
  val _=T.check("atom/multiply-ignores-left-tail",fn()=>
    let val left=BenchNeed.delay(fn()=>N.Cons(BenchNeed.delay(fn()=>1.0),BenchNeed.delay(fn()=>raise Fail "unused left tail")))
    in vectorN(N.multiply left(N.fromList[2.0,3.0]))=[0wx40000000,0wx41100000]end)
  val _=T.check("atom/multiply-right-empty-does-not-demand-left",fn()=>case BenchNeed.force(N.multiply(BenchNeed.delay(fn()=>raise Fail "unused vector"))(N.empty()))of N.Nil=>true|_=>false)
  val _=T.check("atom/add-reuses-longer-tail-head",fn()=>
    let val right=N.fromList[2.0,3.0]val added=N.add(N.fromList[1.0])right
        fun second xs=case BenchNeed.force xs of N.Cons(_,rest)=>(case BenchNeed.force rest of N.Cons(value,_)=>value|_=>raise Empty)|_=>raise Empty
    in second right=second added end)
  val _=T.check("atom/binary32-positive-zero",fn()=>N.bits 0.0=0w0)
  val _=T.check("atom/binary32-negative-zero",fn()=>N.bits(~0.0)=0wx80000000)
  val _=T.check("atom/binary32-tie-to-even-low",fn()=>N.bits(BenchMandelSingle.round(1.0+Math.pow(2.0,~24.0)))=0wx3F800000)
  val _=T.check("atom/binary32-tie-to-even-high",fn()=>N.bits(BenchMandelSingle.round(1.0+3.0*Math.pow(2.0,~24.0)))=0wx3F800002)
  val _=T.check("atom/helper-rejects-subnormal-domain",fn()=>((BenchMandelSingle.round 1.0E~40;false)handle Domain=>true))
  val _=T.check("atom/rejects-non-binary32-input",fn()=>((N.bits(1.0+1.0E~10);false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("atom/rejects-nonfinite",fn()=>((N.bits Real.posInf;false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("atom/lazy-reject-wrong-position",fn()=>((N.run 1(Vector.fromList(List.map word(String.tokens Char.isSpace(read "wrong.positions"))));false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("atom/lazy-reject-short-reference",fn()=>((N.run 2(expected 1);false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("atom/lazy-reject-extra-reference",fn()=>((N.run 1(expected 2);false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("atom/strict-reject-wrong-position",fn()=>((R.run 1(Vector.fromList(List.map word(String.tokens Char.isSpace(read "wrong.positions"))));false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("atom/strict-reject-short-reference",fn()=>((R.run 2(expected 1);false)handle Fail s=>String.isPrefix "incorrect result:" s))
  val _=T.check("atom/strict-reject-extra-reference",fn()=>((R.run 1(expected 2);false)handle Fail s=>String.isPrefix "incorrect result:" s))
end
