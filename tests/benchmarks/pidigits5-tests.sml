structure PiFiveTests =
struct
  structure P=BenchPiDigitsFive
  fun file path=let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input;text end
  fun rejects f=(f();false)handle Fail _=>true
  fun triple(a,b,c)=(IntInf.fromInt a,IntInf.fromInt b,IntInf.fromInt c)
  val _=T.check("pidigits5/initial-extractions",fn()=>P.extract P.initial P.three=3 andalso P.extract P.initial P.four=4)
  val _=T.check("pidigits5/first-refinement",fn()=>P.consume P.initial 1=triple(1,3,6))
  val _=T.check("pidigits5/first-produced-state",fn()=>P.produce(triple(1,3,6))3=triple(10,3,~30))
  val _=T.check("pidigits5/negative-accumulator-refinement",fn()=>P.consume(triple(10,3,~30))2=triple(20,15,~50))
  val _=T.check("pidigits5/truncating-extraction",fn()=>P.extract(triple(1,2,~4))P.three=0)
  val _=List.app(fn n=>T.check("pidigits5/complete-digits-layout-"^Int.toString n,fn()=>
    (P.check n(file("digits-"^Int.toString n^".expected"));true)))[0,1,10,11,27]
  val expected=file "digits-27.expected"
  val _=T.check("pidigits5/wrong-digit-rejected",fn()=>rejects(fn()=>P.check 27("2"^String.extract(expected,1,NONE))))
  val _=T.check("pidigits5/missing-layout-rejected",fn()=>rejects(fn()=>P.check 27(String.substring(expected,0,String.size expected-1))))
  val _=T.check("pidigits5/extra-layout-rejected",fn()=>rejects(fn()=>P.check 27(expected^"x")))
end
