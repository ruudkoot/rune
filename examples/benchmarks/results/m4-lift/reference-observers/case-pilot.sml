structure LiftCases=struct
 structure N=BenchLiftFn(val strict=false)
 structure E=BenchLiftFn(val strict=true)
 structure NS=BenchLiftSerializeFn(N)
 structure ES=BenchLiftSerializeFn(E)
 fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
 fun check key actual path=if actual^"\n"=read path then print("PASS "^key^"\n")else raise Fail key
 fun need(index,(_,input))=(check("need/input/"^Int.toString index)(NS.expression NS.name input)("case-"^Int.toString index^"-input.json");
   check("need/plain/"^Int.toString index)(NS.supercombinators(N.lambdaLift input))("case-"^Int.toString index^"-plain.json");
   check("need/full/"^Int.toString index)(NS.supercombinators(N.fullyLazyLift input))("case-"^Int.toString index^"-full.json"))
 fun strict(index,(_,input))=(check("strict/input/"^Int.toString index)(ES.expression ES.name input)("case-"^Int.toString index^"-input.json");
   check("strict/plain/"^Int.toString index)(ES.supercombinators(E.lambdaLift input))("case-"^Int.toString index^"-plain.json");
   check("strict/full/"^Int.toString index)(ES.supercombinators(E.fullyLazyLift input))("case-"^Int.toString index^"-full.json"))
 val _=List.app need(ListPair.zip(List.tabulate(7,fn i=>i),N.cases()))
 val _=List.app strict(ListPair.zip(List.tabulate(7,fn i=>i),E.cases()))
end
