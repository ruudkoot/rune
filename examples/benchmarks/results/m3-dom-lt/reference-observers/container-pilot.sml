structure M=BenchDomIntMap
structure S=BenchDomIntSet
val keys=[~130,~65,~64,~63,~1,0,1,2,63,64,65,127,128,1024]
val first=S.fromList keys
val _=if S.toList first=keys then print"set order PASS\n"else raise Fail"set order"
val second=S.fromList[~65,0,2,128]
val _=if S.toList(S.difference first second)=[~130,~64,~63,~1,1,63,64,65,127,1024]then print"set difference PASS\n"else raise Fail"set difference"
val _=if S.toList(S.union first second)=keys then print"set union PASS\n"else raise Fail"set union"
val _=if S.toList(S.filter(fn x=>x mod 2=0)first)=[~130,~64,0,2,64,128,1024]then print"set filter PASS\n"else raise Fail"set filter"
val map=M.fromList(List.map(fn key=>(key,key+1))keys)
val _=if M.toList map=List.map(fn key=>(key,key+1))keys then print"map order PASS\n"else raise Fail"map order"
val _=if M.lookup 64(M.unionWith(fn x=>fn y=>x-y)(M.fromList[(64,5)])(M.fromList[(64,3),(~1,4)]))=SOME 2
 then print"map union PASS\n"else raise Fail"map union"
