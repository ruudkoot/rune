structure AnnaDemand=BenchNofibAnnaFn(BenchNeed)
val eof=AnnaDemand.lex(AnnaDemand.int 1)(AnnaDemand.input"")
val _=T.check("nofib-anna/singleton-eof",fn()=>
  case BenchLazy.force eof of AnnaDemand.C.Nil=>false
   |AnnaDemand.C.Cons(token,rest)=>
      let val(line,name)=BenchLazy.force token
      in AnnaDemand.equalInt line(AnnaDemand.int 999999)andalso AnnaDemand.string name="$$$"
         andalso(case BenchLazy.force rest of AnnaDemand.C.Nil=>true|_=>false)end)
