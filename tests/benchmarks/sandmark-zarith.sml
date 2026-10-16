structure ZarithPilot =
struct
 structure I=BenchZarithFibFn(BenchZarithInt)
 structure Z=BenchZarithFibFn(BenchZarithBig)
 structure N=BenchZarithFibFn(BenchZarithNative)
 structure U=BenchZarithFibFn(BenchZarithNum)
 structure TI=BenchZarithTakFn(BenchZarithInt)
 structure TZ=BenchZarithTakFn(BenchZarithBig)
 structure TN=BenchZarithTakFn(BenchZarithNative)
 structure TU=BenchZarithTakFn(BenchZarithNum)
 val _=T.check("zarith/fib-small-modes",fn()=>List.all(fn n=>
   let val value=BenchZarithInt.toString(I.fib n)
   in value=BenchZarithBig.toString(Z.fib n)andalso value=BenchZarithNative.toString(N.fib n)
     andalso value=BenchZarithNum.toString(U.fib n)end)(List.tabulate(16,fn i=>i)))
 val _=T.check("zarith/fib-base",fn()=>BenchZarithInt.toString(I.fib 0)="1"andalso BenchZarithInt.toString(I.fib 1)="1")
 val _=T.check("zarith/factorial",fn()=>IntInf.toString(BenchZarithFact.fact 10)="3628800")
 val _=T.check("zarith/negative-factorial-base",fn()=>IntInf.toString(BenchZarithFact.fact ~2)="1")
 val _=T.check("zarith/tak-small-modes",fn()=>
   BenchZarithInt.toString(TI.tak(6,4,2))="3"andalso
   BenchZarithBig.toString(TZ.tak(BenchZarithBig.fromInt 6,BenchZarithBig.fromInt 4,BenchZarithBig.fromInt 2))="3"andalso
   BenchZarithNative.toString(TN.tak(BenchZarithNative.fromInt 6,BenchZarithNative.fromInt 4,BenchZarithNative.fromInt 2))="3"andalso
   BenchZarithNum.toString(TU.tak(BenchZarithNum.fromInt 6,BenchZarithNum.fromInt 4,BenchZarithNum.fromInt 2))="3")
 val _=T.check("zarith/native-signed-order",fn()=>BenchZarithNative.greater(BenchZarithNative.fromInt 0,BenchZarithNative.fromInt ~1))
end

structure ZarithPiTests =
struct
 fun read path = let val input=TextIO.openIn path val text=TextIO.inputAll input
   in TextIO.closeIn input; text end
 fun fails thunk = (thunk();false)handle Fail _=>true
 val _=T.check("zarith/pi-lft-full-product",fn()=>
   BenchZarithPi.comp(1,2,3,4)(5,6,7,8)=(19,22,43,50))
 val _=T.check("zarith/pi-division-truncates",fn()=>
   BenchZarithPi.floorEv(1,0,0,~2)3= ~1)
 val _=List.app(fn n=>T.check("zarith/pi-layout-"^Int.toString n,fn()=>
   (BenchZarithPi.check n (read("pi-"^Int.toString n^".expected"));true))) [0,1,9,10,11,27]
 val _=T.check("zarith/pi-rejects-digit-perturbation",fn()=>
   fails(fn()=>BenchZarithPi.check 1 "4         \t:1\n"))
 val _=T.check("zarith/pi-rejects-padding-perturbation",fn()=>
   fails(fn()=>BenchZarithPi.check 1 "3        \t:1\n"))
 val _=T.check("zarith/pi-rejects-extra-output",fn()=>
   fails(fn()=>BenchZarithPi.check 1 "3         \t:1\nextra"))
 val _=T.check("zarith/repeat-extra-call",fn()=>
   let val calls=ref 0 val checks=ref 0
       val last=BenchZarithRepeat.run 3 (fn n=>(calls:= !calls+1;n)) 7 (fn _=>checks:= !checks+1)
   in !calls=4 andalso !checks=4 andalso last=7 end)
 val _=T.check("zarith/repeat-negative-base",fn()=>
   let val calls=ref 0
   in BenchZarithRepeat.run ~1 (fn n=>(calls:= !calls+1;n)) 7 (fn _=>())=7 andalso !calls=1 end)
 val _=T.check("zarith/repeat-checks-discarded-values",fn()=>
   fails(fn()=>ignore(BenchZarithRepeat.run 3 (fn n=>n) 7 (fn _=>raise Fail "wrong"))))
 val _=T.check("zarith/native-wraparound",fn()=>
   BenchZarithNative.toString(BenchZarithNative.add(0wx7FFFFFFFFFFFFFFF,0w1))="~9223372036854775808")
end
