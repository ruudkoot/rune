val epoch=RealArray.fromList[2451545.0,1.0]
val pv=Array.fromList[RealArray.array(3,0.0),RealArray.array(3,0.0)]
val position=RealArray.array(3,0.0)
val _=List.app(fn p=>(BenchAlma.planetPV epoch p pv;BenchAlma.raDecDist pv position;
 print(Int.toString p^" "^String.concatWith" "(List.tabulate(3,fn i=>Real.toString(RealArray.sub(position,i))))^"\n")))(List.tabulate(8,fn p=>p))
