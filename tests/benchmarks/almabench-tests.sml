structure AlmaTests =
struct
  val base=""
  fun read name=BenchAlmaDriver.read(base^name)
  fun rows text=String.tokens(fn c=>c= #"\n")text
  fun signed text=BenchInput.integer(String.translate(fn #"-"=>"~"|c=>String.str c)text)
  fun parsed row=case String.tokens Char.isSpace row of day::planet::values=>
     (signed day,BenchInput.integer planet,List.map BenchAlmaDriver.real values)
    |_=>raise Fail "bad alma state reference"
  fun evaluate day planet=
    let val jd=RealArray.fromList[BenchAlmaTables.j2000+Real.fromInt day,0.0]
        val pv=Array.fromList[RealArray.array(3,0.0),RealArray.array(3,0.0)]
        val result=RealArray.array(3,0.0)
        val _=BenchAlma.planetPV jd planet pv val _=BenchAlma.raDecDist pv result
    in List.tabulate(9,fn i=>if i<6 then RealArray.sub(Array.sub(pv,i div 3),i mod 3)
         else RealArray.sub(result,i-6))end
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~11,1.0E~11)
  fun check row=
    let val(day,planet,wanted)=parsed row
    in T.check("alma/source-state-"^Int.toString day^"-"^Int.toString planet,fn()=>
      ListPair.allEq close(evaluate day planet,wanted))end
  val _=List.app check(rows(read"points.reference"))
  val _=List.app(fn row=>
    let val(day,planet,wanted)=parsed row
    in T.check("alma/independent-ERFA-"^Int.toString day^"-"^Int.toString planet,fn()=>
      ListPair.allEq close(List.take(evaluate day planet,6),wanted))end)
    (rows(read"erfa.reference"))
  val _=T.check("alma/source-angle-minus-pi",fn()=>Real.==(BenchAlma.anpm(~BenchAlmaTables.pic),BenchAlmaTables.pic))
  val _=T.check("alma/source-angle-plus-pi",fn()=>Real.==(BenchAlma.anpm BenchAlmaTables.pic,~BenchAlmaTables.pic))
  val _=T.check("alma/negative-remainder-exact-result",fn()=>Real.==(Real.rem(~7.0,3.0),~1.0))
  val _=T.check("alma/smoke-all-moments",fn()=>BenchAlmaDriver.run["1","32",base^"smoke.reference"]="264:27")
  val wanted=BenchAlmaDriver.reference(read"normal.reference")
  val _=T.check("alma/baseline-aggregate-accepted",fn()=>BenchAlmaDriver.valid(wanted,wanted))
  val _=List.app(fn i=>T.check("alma/perturbed-moment-"^Int.toString i,fn()=>
    let val changed=ListPair.mapEq(fn(j,v)=>if i=j then v+0.01*(1.0+Real.abs v)else v)
      (List.tabulate(27,fn j=>j),wanted)
    in not(BenchAlmaDriver.valid(changed,wanted))end))(List.tabulate(27,fn i=>i))
  val _=T.check("alma/nonfinite-aggregate-rejected",fn()=>
    not(BenchAlmaDriver.valid((0.0/0.0)::tl wanted,wanted)))
  val _=T.check("alma/short-aggregate-rejected",fn()=>not(BenchAlmaDriver.valid(tl wanted,wanted)))
  val _=T.check("alma/malformed-reference-rejected",fn()=>((BenchAlmaDriver.reference"invalid";false)handle Fail _=>true))
end
