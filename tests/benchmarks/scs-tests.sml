structure ScsTests =
struct
  structure Q=BenchScsRational
  structure P=BenchScsParse
  structure K=BenchScsSimulate
  structure C=BenchScsCheck
  structure R=BenchScsRandom
  structure L=BenchLazy
  structure S=BenchStream
  val _=List.app(fn(name,args,rows,points)=>
    (T.check("scs/lazy-"^name,fn()=>C.run false args=Int.toString rows^":"^Int.toString points^":checked");
     T.check("scs/strict-"^name,fn()=>C.run true args=Int.toString rows^":"^Int.toString points^":checked")))ScsCases.values
  fun lines path=
    let val input=TextIO.openIn path
        fun loop()=case TextIO.inputLine input of NONE=>[]|SOME text=>String.tokens Char.isSpace text::loop()
        val values=loop()val _=TextIO.closeIn input
    in values end
  val _=List.app(fn(i,values)=>T.check("scs/rational-bits-"^Int.toString i,fn()=>case values of[n,d,bits]=>
      BenchScsDoubleBits.bitPattern(Q.real(C.integer n,C.integer d))=C.integer bits|_=>false))
    (ListPair.zip(List.tabulate(18,fn i=>i),lines "rational-bits.data"))
  val _=List.app(fn text=>T.check("scs/integral-nearest-"^text,fn()=>
    let val expected=C.integer text val value=Real.fromLargeInt expected
    in Real.toLargeInt IEEEReal.TO_NEAREST value=expected end))
    ["4503599627370495","4503599627370496","4503599627370497","6004799503160661","9007199254740991",
     "-4503599627370495","-4503599627370496","-4503599627370497","-6004799503160661","-9007199254740991"]
  val vectors=lines "random-vectors.data"
  val _=List.app(fn(i,values)=>T.check("scs/random-integer-vector-"^Int.toString i,fn()=>
      case values of lo::hi::seed::expected=>S.take(List.length expected)(R.random(C.integer lo,C.integer hi)(C.integer seed))=List.map C.integer expected|_=>false))
    (ListPair.zip(List.tabulate(List.length vectors,fn i=>i),vectors))
  val _=List.app(fn(text,expected)=>T.check("scs/exact-parser-"^text,fn()=>
    case expected of NONE=>((ignore(P.readExact text);false)handle Fail _=>true)
      |SOME value=>Q.equal(P.readExact text,value)))
    [("10n",SOME(Q.make(1,100000000))),("400p",SOME(Q.make(1,2500000000))),
     ("- 3. 25m",SOME(Q.make(~13,4000))),("1.",NONE),(".5",NONE),("1E",SOME(Q.make(1000000000000000000,1))),
     ("1e3",NONE),("01",SOME Q.one),("1 .2",NONE),("  1.25u  ",SOME(Q.make(1,800000)))]
  val _=List.app(fn(text,expected)=>T.check("scs/integer-parser-"^text,fn()=>case expected of
      NONE=>((ignore(P.readInteger text);false)handle Fail _=>true)|SOME value=>P.readInteger text=value))
    [("345",SOME(IntInf.fromInt 345)),("-345",SOME(IntInf.fromInt ~345)),("- 345",SOME(IntInf.fromInt ~345)),
     ("+345",NONE),("01",SOME(IntInf.fromInt 1)),("345 ",SOME(IntInf.fromInt 345))]
  val _=T.check("scs/random-spine-defers-state",fn()=>
    let val calls=ref 0
        val state=L.delay(fn()=>(calls:= !calls+1;R.seed 345))
        val tail=K.drop 32(R.raw state)
        val _=L.force tail
        val unused= !calls=0
        val _=S.head tail
        val _=S.head tail
    in unused andalso !calls=1 end)
  val _=T.check("scs/invalid-random-interval-is-deferred",fn()=>
    let val source=R.random(2,1)0
        val empty=S.take 0 source=[]
    in empty andalso ((ignore(L.force source);false)handle Fail _=>true)end)
  val _=T.check("scs/constant-wave-defers-time",fn()=>
    Real.==(K.source(S.singleton(L.delay(fn()=>raise Fail "unused point time"),L.delay(fn()=>3.0)))
      (L.delay(fn()=>raise Fail "unused sample time")),3.0))
  val _=T.check("scs/wave-before-first-defers-future",fn()=>
    let val wave=S.cons(L.delay(fn()=>(L.delay(fn()=>1.0),L.delay(fn()=>4.0))),
          S.cons(L.delay(fn()=>raise Fail "unused future point"),S.empty()))
    in Real.==(K.source wave(L.delay(fn()=>0.0)),4.0)end)
  val _=T.check("scs/wave-rejects-nonincreasing-times",fn()=>
    ((ignore(K.source(S.fromList[(L.delay(fn()=>0.0),L.delay(fn()=>1.0)),(L.delay(fn()=>0.0),L.delay(fn()=>2.0))])
       (L.delay(fn()=>1.0)));false)handle Fail _=>true))
  val _=T.check("scs/empty-trace-demand-avoids-setup",fn()=>
    let val broken=[(1,2,0,BenchScsTypes.Capacitor(L.delay(fn()=>raise Fail "unused capacitance"),L.delay(fn()=>Q.zero)))]
    in List.null(S.take 0(K.simulateWith false broken 0 Q.one Q.one 1.0 0.0))andalso
       List.null(S.take 0(K.simulateWith true broken 0 Q.one Q.one 1.0 0.0))end)
  val _=List.app(fn(name,expected)=>
    let val bound=C.absolute name+C.relative*Real.abs expected
    in T.check("scs/tolerance-inside-"^name^Real.toString expected,fn()=>C.close name(expected+0.5*bound,expected));
       T.check("scs/tolerance-outside-"^name^Real.toString expected,fn()=>not(C.close name(expected+4.0*bound,expected)))end)
    [("i:test",0.0),("i:test",1.0E~10),("v:test",0.0),("v:test",0.003),("v:test",~0.003)]
  val _=T.check("scs/nonfinite-value-rejected",fn()=>not(C.close "v:test"(Real.posInf,0.0)))
  val _=T.check("scs/nonfinite-reference-rejected",fn()=>not(C.close "v:test"(0.0,Real.posInf)))
  val base=["inverter.in","345","10n","20n","1","0"]
  val _=List.app(fn name=>
    (T.check("scs/lazy-reject-"^name,fn()=>((ignore(C.run false(base@[name^".exacttrace"]));false)
      handle Fail text=>String.isPrefix "incorrect result:" text));
     T.check("scs/strict-reject-"^name,fn()=>((ignore(C.run true(base@[name^".exacttrace"]));false)
      handle Fail text=>String.isPrefix "incorrect result:" text))))
    ["wrong-header","wrong-time","wrong-value","nonfinite","wrong-dimension","truncated","extra"]
end
