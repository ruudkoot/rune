structure SchedTests=struct
 structure D=BenchNeed
 structure L=BenchLazy
 structure N=BenchSchedFn(BenchNeed)
 structure E=BenchSchedFn(BenchStrict)
 fun check name f=T.check("sched/"^name,f)
 val _=check"source-tree/N/0/0"(fn()=>N.statistics(N.schedule(N.input 0)0)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/N/0/100"(fn()=>N.statistics(N.schedule(N.input 0)100)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/N/1/0"(fn()=>N.statistics(N.schedule(N.input 1)0)=(1,10,10,valOf(IntInf.fromString"10"),0wxF0C6CDD))
 val _=check"source-tree/N/1/100"(fn()=>N.statistics(N.schedule(N.input 1)100)=(1,10,10,valOf(IntInf.fromString"10"),0wxF0C6CDD))
 val _=check"source-tree/N/2/0"(fn()=>N.statistics(N.schedule(N.input 2)0)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/N/2/100"(fn()=>N.statistics(N.schedule(N.input 2)100)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/N/3/0"(fn()=>N.statistics(N.schedule(N.input 3)0)=(2,60,60,valOf(IntInf.fromString"120"),0wx33E000DE))
 val _=check"source-tree/N/3/100"(fn()=>N.statistics(N.schedule(N.input 3)100)=(2,60,60,valOf(IntInf.fromString"120"),0wx33E000DE))
 val _=check"source-tree/N/7/0"(fn()=>N.statistics(N.schedule(N.input 7)0)=(32,148,178,valOf(IntInf.fromString"5304"),0wxF761F0CC))
 val _=check"source-tree/N/7/4"(fn()=>N.statistics(N.schedule(N.input 7)4)=(32,148,178,valOf(IntInf.fromString"5304"),0wxF761F0CC))
 val _=check"source-tree/N/7/100"(fn()=>N.statistics(N.schedule(N.input 7)100)=(32,148,178,valOf(IntInf.fromString"5304"),0wxF761F0CC))
 val _=check"source-tree/N/10/0"(fn()=>N.statistics(N.schedule(N.input 10)0)=(262,190,240,valOf(IntInf.fromString"55420"),0wx465B9F86))
 val _=check"source-tree/N/10/7"(fn()=>N.statistics(N.schedule(N.input 10)7)=(262,190,240,valOf(IntInf.fromString"55420"),0wx465B9F86))
 val _=check"source-tree/N/10/100"(fn()=>N.statistics(N.schedule(N.input 10)100)=(262,190,240,valOf(IntInf.fromString"55420"),0wx465B9F86))
 val _=check"source-tree/N/11/0"(fn()=>N.statistics(N.schedule(N.input 11)0)=(5746,218,270,valOf(IntInf.fromString"1382788"),0wxB3132CE0))
 val _=check"source-tree/N/11/8"(fn()=>N.statistics(N.schedule(N.input 11)8)=(5746,218,270,valOf(IntInf.fromString"1382788"),0wxB3132CE0))
 val _=check"source-tree/N/11/100"(fn()=>N.statistics(N.schedule(N.input 11)100)=(5746,218,270,valOf(IntInf.fromString"1382788"),0wxB3132CE0))
 val _=check"source-tree/N/12/0"(fn()=>N.statistics(N.schedule(N.input 12)0)=(5766,228,275,valOf(IntInf.fromString"1452840"),0wx5D39AD74))
 val _=check"source-tree/N/12/9"(fn()=>N.statistics(N.schedule(N.input 12)9)=(5766,228,275,valOf(IntInf.fromString"1452840"),0wx5D39AD74))
 val _=check"source-tree/N/12/100"(fn()=>N.statistics(N.schedule(N.input 12)100)=(5766,228,275,valOf(IntInf.fromString"1452840"),0wx5D39AD74))
 val _=check"source-tree/E/0/0"(fn()=>E.statistics(E.schedule(E.input 0)0)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/E/0/100"(fn()=>E.statistics(E.schedule(E.input 0)100)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/E/1/0"(fn()=>E.statistics(E.schedule(E.input 1)0)=(1,10,10,valOf(IntInf.fromString"10"),0wxF0C6CDD))
 val _=check"source-tree/E/1/100"(fn()=>E.statistics(E.schedule(E.input 1)100)=(1,10,10,valOf(IntInf.fromString"10"),0wxF0C6CDD))
 val _=check"source-tree/E/2/0"(fn()=>E.statistics(E.schedule(E.input 2)0)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/E/2/100"(fn()=>E.statistics(E.schedule(E.input 2)100)=(1,0,0,valOf(IntInf.fromString"0"),0wx50C5D1F))
 val _=check"source-tree/E/3/0"(fn()=>E.statistics(E.schedule(E.input 3)0)=(2,60,60,valOf(IntInf.fromString"120"),0wx33E000DE))
 val _=check"source-tree/E/3/100"(fn()=>E.statistics(E.schedule(E.input 3)100)=(2,60,60,valOf(IntInf.fromString"120"),0wx33E000DE))
 val _=check"source-tree/E/7/0"(fn()=>E.statistics(E.schedule(E.input 7)0)=(32,148,178,valOf(IntInf.fromString"5304"),0wxF761F0CC))
 val _=check"source-tree/E/7/4"(fn()=>E.statistics(E.schedule(E.input 7)4)=(32,148,178,valOf(IntInf.fromString"5304"),0wxF761F0CC))
 val _=check"source-tree/E/7/100"(fn()=>E.statistics(E.schedule(E.input 7)100)=(32,148,178,valOf(IntInf.fromString"5304"),0wxF761F0CC))
 val _=check"source-tree/E/10/0"(fn()=>E.statistics(E.schedule(E.input 10)0)=(262,190,240,valOf(IntInf.fromString"55420"),0wx465B9F86))
 val _=check"source-tree/E/10/7"(fn()=>E.statistics(E.schedule(E.input 10)7)=(262,190,240,valOf(IntInf.fromString"55420"),0wx465B9F86))
 val _=check"source-tree/E/10/100"(fn()=>E.statistics(E.schedule(E.input 10)100)=(262,190,240,valOf(IntInf.fromString"55420"),0wx465B9F86))
 val _=check"source-tree/E/11/0"(fn()=>E.statistics(E.schedule(E.input 11)0)=(5746,218,270,valOf(IntInf.fromString"1382788"),0wxB3132CE0))
 val _=check"source-tree/E/11/8"(fn()=>E.statistics(E.schedule(E.input 11)8)=(5746,218,270,valOf(IntInf.fromString"1382788"),0wxB3132CE0))
 val _=check"source-tree/E/11/100"(fn()=>E.statistics(E.schedule(E.input 11)100)=(5746,218,270,valOf(IntInf.fromString"1382788"),0wxB3132CE0))
 val _=check"source-tree/E/12/0"(fn()=>E.statistics(E.schedule(E.input 12)0)=(5766,228,275,valOf(IntInf.fromString"1452840"),0wx5D39AD74))
 val _=check"source-tree/E/12/9"(fn()=>E.statistics(E.schedule(E.input 12)9)=(5766,228,275,valOf(IntInf.fromString"1452840"),0wx5D39AD74))
 val _=check"source-tree/E/12/100"(fn()=>E.statistics(E.schedule(E.input 12)100)=(5766,228,275,valOf(IntInf.fromString"1452840"),0wx5D39AD74))
 val _=check"lazy-anyjob-empty-keeps-pid-pending"(fn()=>
 let val pid=D.delay(fn()=>raise Fail"unused pid")
     val selected=N.second(N.anyJob(N.F.cons(N.emptyStat(),N.F.empty()))(N.F.empty())pid)
 in not(N.null selected)andalso N.isEmptyStat(N.head selected)end)
 val _=check"lazy-anyjob-fork-skips-unused-fields"(fn()=>
 let val bad=D.delay(fn()=>raise Fail"unused scalar")
     val definition=D.delay(fn()=>raise Fail"unused definition")
     val state=N.stat(N.value 1)bad bad bad definition
     val selected=N.second(N.anyJob(N.F.cons(state,N.F.empty()))(N.F.empty())bad)
 in N.mark(N.head selected)=1 end)
 val _=check"lazy-perform-terminal-projection-skips-pid"(fn()=>
 let val pid=D.delay(fn()=>raise Fail"unused pid")
     val p=N.procCell pid(N.emptyStat())
 in N.null(N.first(N.perform(N.F.cons(p,N.F.empty()))1))end)
 val _=check"lazy-empty-ack-skips-parent"(fn()=>
 N.null(N.acknowledge(D.delay(fn()=>raise Fail"unused parent"))(N.F.empty())))
 val _=check"lazy-empty-child-skips-parent"(fn()=>
 N.isEmptyStat(N.addChild(N.emptyDef())(D.delay(fn()=>raise Fail"unused parent"))))
 val _=check"lazy-leaf-child-does-not-force-join-or-id"(fn()=>
 let val bad=D.delay(fn()=>raise Fail"unused scalar")
     val child=D.delay(fn()=>raise Fail"unused child")
     val definition=D.delay(fn()=>N.JobDef(bad,N.value 0,bad,child,child))
 in N.mark(N.addChild definition bad)=4 end)
 val _=check"source-pair-fields-are-shared"(fn()=>
 let val calls=ref 0
     val pair=N.pair(fn()=>(calls:= !calls+1;N.F.empty()))(fn()=>(calls:= !calls+1;N.F.empty()))
     val _=N.first pair val _=N.first pair val _=N.second pair val _=N.second pair
 in !calls=2 end)
 val _=check"sandwich-hints-remain-unforced"(fn()=>
 let val hint=L.delay(fn()=>raise Fail"unused metadata")
 in N.sandwich(fn(a,b)=>a+b)(N.Sandwarg(2,hint))(N.Sandwarg(3,hint))=5 end)
 val _=check"strict-variant-also-keeps-control-hints-unforced"(fn()=>
 let val hint=L.delay(fn()=>raise Fail"unused metadata")
 in E.sandwich(fn(a,b)=>a+b)(E.Sandwarg(2,hint))(E.Sandwarg(3,hint))=5 end)
 val _=check"strict-finite-fields-evaluate"(fn()=>
 let val calls=ref 0 val field=BenchStrict.delay(fn()=>(calls:= !calls+1;7))
 in !calls=1 andalso BenchStrict.force field=7 end)
 val _=check"zero-is-source-minimum-sentinel"(fn()=>N.minZero 0 7=7 andalso N.minZero 9 0=9 andalso N.minZero 0 0=0)
end
