structure CryptarithmTests =
struct
 structure L=BenchCryptarithmFn(BenchNeed)
 structure E=BenchCryptarithmFn(BenchStrict)
 val words=["THIRTY","TWELVE","TWELVE","TWELVE","TWELVE","TWELVE"]
 val mapping=[(#"W",3),(#"H",9),(#"N",8),(#"I",4),(#"L",7),(#"R",2),(#"V",6),(#"T",1),(#"E",0),(#"Y",5)]
 val rendered="W => 3\nH => 9\nN => 8\nI => 4\nL => 7\nR => 2\nV => 6\nT => 1\nE => 0\nY => 5\n"
 val _=T.check("cryptarithm2/lazy-unique-full-mapping",fn()=>L.all words "NINETY"=[mapping])
 val _=T.check("cryptarithm2/strict-unique-full-mapping",fn()=>E.all words "NINETY"=[mapping])
 val _=T.check("cryptarithm2/render-and-validation",fn()=>L.puzzle words "NINETY"=rendered andalso E.puzzle words "NINETY"=rendered)
 val _=T.check("cryptarithm2/ragged-transpose",fn()=>L.transpose[[1,2],[],[3]]=[[1,3],[2]])
 val _=T.check("cryptarithm2/delete-first-only",fn()=>L.S.toList(L.delete 1(L.S.fromList[0,1,1,2]))=[0,1,2])
 val _=T.check("cryptarithm2/small-search-variants",fn()=>L.all["A","B"]"C"=E.all["A","B"]"C")
 val _=T.check("cryptarithm2/final-carry-is-rejected",fn()=>L.all["A","A"]"B"=E.all["A","A"]"B" andalso List.length(L.all["A","A"]"B")=4)
 val _=T.check("cryptarithm2/leading-zero-is-allowed",fn()=>List.exists(fn env=>List.exists(fn(c,n)=>c= #"A" andalso n=0)env)(L.all["A"]"A"))
 val _=T.check("cryptarithm2/reused-symbol-does-not-force-digits",fn()=>
   let val digit=BenchNeed.delay(fn()=>7)
       val state=BenchNeed.delay(fn()=>L.Digits(BenchNeed.delay(fn()=>raise Fail "unused digits"),L.S.fromList[(#"A",digit)]))
   in case BenchNeed.force(L.select #"A" state)of L.S.Cons(x,_)=>
      let val(value,_)=BenchNeed.force x in BenchNeed.force value=7 end | _=>false end)
 val _=T.check("cryptarithm2/first-choice-does-not-force-tail",fn()=>
   let val choices=BenchNeed.delay(fn()=>L.S.Cons(BenchNeed.delay(fn()=>2),BenchNeed.delay(fn()=>raise Fail "unused tail")))
       val state=BenchNeed.delay(fn()=>L.Digits(choices,L.S.empty()))
   in case BenchNeed.force(L.permute #"A" state)of L.S.Cons(x,_)=>
      let val(value,_)=BenchNeed.force x in BenchNeed.force value=2 end | _=>false end)
end
