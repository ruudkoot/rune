structure SchedStatsPilot=
struct
 structure N=BenchSchedFn(BenchNeed)
 structure E=BenchSchedFn(BenchStrict)
 fun text(count,low,high,total,hash)=Int.toString count^" "^Int.toString low^" "^Int.toString high^" "^IntInf.toString total^" "^Word32.toString hash
 val _=List.app(fn size=>
   let val threshold=if size<=3 then 0 else size-3
       val _=print(Int.toString size^" lazy "^text(N.statistics(N.schedule(N.input size)threshold))^"\n")
       val _=TextIO.flushOut TextIO.stdOut
       val _=print(Int.toString size^" strict "^text(E.statistics(E.schedule(E.input size)threshold))^"\n")
   in TextIO.flushOut TextIO.stdOut end)[0,1,2,3,7,10,11,12]
end
