val _=T.check("expert/lazy phrase leaves unused children delayed",fn()=>
  let val p=LazyExpertTests.K.term "unused"
        (BenchStream.singleton(BenchLazy.delay(fn()=>raise Fail "unused phrase")))
  in case BenchLazy.force p of LazyExpertTests.K.Term(word,_)=>word="unused"|_=>false end)
val _=T.check("expert/strict phrase evaluates finite children",fn()=>
  let val p=StrictExpertTests.K.term "unused"
        (BenchStream.singleton(BenchLazy.delay(fn()=>raise Fail "unused phrase")))
  in ((BenchLazy.force p;false)handle Fail why=>why="unused phrase")end)
val _=T.check("expert/table delete and ordered entries",fn()=>
  let val table=BenchExpertTable.updateList(BenchExpertTable.newTable())
        (BenchStream.fromList[LazyExpertTests.entry("c",3),LazyExpertTests.entry("a",1),LazyExpertTests.entry("b",2)])
      val deleted=BenchExpertTable.delete table "b"
      val actual=BenchStream.take 3(BenchExpertTable.entries deleted)
  in List.map(fn(k,v)=>(BenchLazy.force k,BenchLazy.force v))actual=[("a",1),("c",3)]
    andalso LazyExpertTests.lookup table "b"=SOME 2 end)
