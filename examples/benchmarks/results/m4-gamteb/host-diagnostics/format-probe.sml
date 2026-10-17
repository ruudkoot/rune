structure Need=BenchGamtebFn(BenchNeed)
structure Strict=BenchGamtebFn(BenchStrict)
structure Probe=struct
 fun show(mode,values)=List.app(fn value=>
   let val original=Real.fmt(StringCvt.GEN(SOME 17))value
       val text=String.translate(fn #"~"=>"-"|c=>String.str c)original
       val parsed=Real.fromString text
       val _=print(mode^" value="^original^" text="^text^
         " parsed="^(case parsed of NONE=>"NONE"|SOME x=>Real.fmt(StringCvt.GEN(SOME 17))x)^
         " equal="^Bool.toString(case parsed of SOME x=>Real.==(x,value)|_=>false)^"\n")
   in()end)values
 val _=show("Need",Need.tableHeads())
 val _=show("Strict",Strict.tableHeads())
end
structure NeedDriver=BenchGamtebDriverFn(Need)
structure StrictDriver=BenchGamtebDriverFn(Strict)
structure Finish=struct
 val _=T.check("gamma-prefix/need",fn()=>String.size NeedDriver.tableText>0)
 val _=T.check("gamma-prefix/strict",fn()=>String.size StrictDriver.tableText>0)
end
