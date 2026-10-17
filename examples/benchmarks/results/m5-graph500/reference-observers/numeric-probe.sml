fun report label x=print(label^" "^x^"\n")
val _=List.app(fn power=>
 let val result=Math.pow(2.0,Real.fromInt power)
     val size=Real.trunc result
     val expected=Word.toInt(Word.<<(0w1,Word.fromInt power))
     val _=report("pow-"^Int.toString power)(Real.fmt(StringCvt.GEN(SOME 17))result^" -> "^Int.toString size)
 in T.check("graph-probe/pow-size-"^Int.toString power,fn()=>size=expected)end)[0,1,2,3,8,10]
val _=List.app(fn text=>
 let val wanted=valOf(IntInf.fromString text)
     val input=Real.fromLargeInt wanted
     val nearest=Real.toLargeInt IEEEReal.TO_NEAREST input
     val trunc=Real.toLargeInt IEEEReal.TO_ZERO input
     val _=report("integer-"^text)(Real.fmt(StringCvt.GEN(SOME 17))input^" nearest "^IntInf.toString nearest^" trunc "^IntInf.toString trunc)
 in T.check("graph-probe/nearest-"^text,fn()=>nearest=wanted);
    T.check("graph-probe/trunc-"^text,fn()=>trunc=wanted)end)
 ["4503599627370495","4503599627370496","4503599627370497","9007199254740990","9007199254740991"]
val literal:Word64.word=0wx8495a6be
val parsed=valOf(Word64.fromString"8495A6BE")
val converted=Word64.fromLargeInt(valOf(IntInf.fromString"2224408254"))
val shifted=Word64.orb(Word64.<<(0w132,0w24),0wx95a6be)
val _=List.app(fn(label,value)=>
 let val top=Word64.toInt(Word64.andb(Word64.>>(value,0w24),0wxFF))
     val _=report label(Word64.toString value^" top "^Int.toString top)
 in T.check("graph-probe/"^label^"/top-byte",fn()=>top=132)end)
 [("literal",literal),("parsed",parsed),("converted",converted),("shifted",shifted)]
