functor ExactCasesFn(C:sig
  structure K:sig
  type cr
  val constant:int->cr
  val integer:IntInf.int->cr
  val divide:cr*cr->cr
  val multiply:cr*cr->cr
  val negative:cr->cr
  val sine:cr->cr
  val cosine:cr->cr
  val atan:cr->cr
  val bits:int->cr->IntInf.int
  val text:int->cr->string
end
  val label:string
end)=
struct
  structure K=C.K
  val label=C.label
  fun fraction(n,d)=K.divide(K.integer n,K.integer d)
  val samples=[("pi",K.constant 0),("third",fraction(1,3)),("negative-third",fraction(~1,3)),("sqrt-half",K.constant 3),("sin-quarter",K.sine(K.constant 2)),("cos-quarter",K.cosine(K.constant 2)),("sin-negative-quarter",K.sine(K.negative(K.constant 2))),("atan-minus-five",K.atan(K.integer (~5))),("atan-minus-one",K.atan(K.integer (~1))),("atan-minus-half",K.atan(fraction(~1,2))),("atan-zero",K.atan(K.integer 0)),("atan-fifth",K.atan(fraction(1,5))),("atan-one",K.atan(K.integer 1)),("atan-five",K.atan(K.integer 5))]
  fun lookup name=case List.find(fn(n,_)=>n=name)samples of SOME(_,value)=>value|NONE=>raise Fail "unknown exact scalar"
  fun read path=let val input=TextIO.openIn path val data=TextIO.inputAll input val _=TextIO.closeIn input in data end
  fun int text=valOf(Int.fromString text)
  fun large text=valOf(IntInf.fromString text)
  fun check line=case String.tokens Char.isSpace line of
      [name,"bits",p,wanted]=>T.check("exact/"^label^"/"^name^"/bits-"^p,fn()=>K.bits(int p)(lookup name)=large wanted)
    |[name,"text",wanted]=>T.check("exact/"^label^"/"^name^"/forty-digits",fn()=>K.text 40(lookup name)=wanted)
    |_=>raise Fail "invalid exact scalar fixture"
  val _=List.app check(String.tokens(fn c=>Char.ord c=10)(read "scalar-cases.data"))
end
structure NeedExact=BenchExactRealsFn(BenchNeed)
structure StrictExact=BenchExactRealsFn(BenchStrict)
structure NeedCases=ExactCasesFn(struct structure K=NeedExact val label="lazy"end)
structure StrictCases=ExactCasesFn(struct structure K=StrictExact val label="strict"end)
structure ExactTests =
struct
  structure N=NeedExact
  structure R=StrictExact
  structure I=IntInf
  structure Q=BenchScsRational
  structure L=BenchLazy
  structure S=BenchStream
  val _=T.check("exact/round-positive-half",fn()=>N.rounded(Q.make(1,2))=1)
  val _=T.check("exact/round-negative-half",fn()=>N.rounded(Q.make(~1,2))=0)
  val _=T.check("exact/round-positive-three-halves",fn()=>N.rounded(Q.make(3,2))=2)
  val _=T.check("exact/round-negative-three-halves",fn()=>N.rounded(Q.make(~3,2))= ~1)
  val _=T.check("exact/zero-coefficient-stops-demand",fn()=>
    let val coefficients=S.cons(L.delay(fn()=>Q.zero),L.delay(fn()=>raise Fail "unused coefficients"))
        val value=N.powerSeries coefficients(fn p=>p+2)(N.CR(fn _=>raise Fail "unused input approximation"))
    in N.bits 137 value=0 end)
  val _=T.check("exact/empty-coefficients-do-not-demand-input",fn()=>
    N.bits 137(N.powerSeries(S.empty())(fn p=>p+2)(N.CR(fn _=>raise Fail "unused input approximation")))=0)
  val _=T.check("exact/multiply-shares-bounds-not-function-results",fn()=>
    let val xs=ref [] val ys=ref []
        val x=N.CR(fn p=>(xs:=p:: !xs;N.pow2 p))
        val y=N.CR(fn p=>(ys:=p:: !ys;I.*(2,N.pow2 p)))
        val product=N.multiply(x,y)
        val a=N.bits 8 product val b=N.bits 8 product
    in a=512 andalso b=512 andalso List.rev(!xs)=[0,14,14]andalso List.rev(!ys)=[0,13,13]end)
  val _=T.check("exact/reciprocal-search-repeats-per-precision-call",fn()=>
    let val calls=ref [] val x=N.CR(fn p=>(calls:=p:: !calls;I.div(I.+(I.*(3,N.pow2 p),4),8)))
        val value=N.reciprocal x val a=N.bits 0 value val b=N.bits 0 value
    in a=3 andalso b=3 andalso List.rev(!calls)=[0,1,2,3,8,0,1,2,3,8]end)
  val _=T.check("exact/left-addition-precision-guards",fn()=>
    let val calls=ref []
        fun leaf n=N.CR(fn p=>(calls:=p:: !calls;I.*(I.fromInt n,N.pow2 p)))
        val value=N.add(N.add(N.add(N.integer 0,leaf 1),leaf 2),leaf 3)
        val result=N.bits 0 value
    in result=6 andalso List.rev(!calls)=[6,4,2]end)
  val _=T.check("exact/integer-sqrt-small",fn()=>
    List.map(fn n=>N.floorSqrt(I.fromInt n))[0,1,2,4,9,16,100]=[0,1,1,2,3,4,10])
  val _=T.check("exact/enum-endpoints",fn()=>N.fromEnum(N.integer 350)=350 andalso N.fromEnum(N.integer 1)=1)
  val _=T.check("exact/zero-lazy-sum",fn()=>N.run 0="0.0000000000000000000000000000000000000000")
  val _=T.check("exact/zero-strict-sum",fn()=>R.run 0="0.0000000000000000000000000000000000000000")
end
