structure SchedNormalPilot=
struct
 structure N=BenchSchedFn(BenchNeed)
 structure E=BenchSchedFn(BenchStrict)
 fun repeat f=
   let fun loop 0=()|loop n=if f 8 11=218 then loop(n-1)else raise Fail"incorrect result: scheduler optimum"
   in loop 100 end
 val _=repeat N.calculate
 val _=print"PASS lazy normal100 size11\n"
 val _=TextIO.flushOut TextIO.stdOut
 val _=repeat E.calculate
 val _=print"PASS strict normal100 size11\n"
end
