structure CryptarithmPermutationTests =
struct
 structure L=BenchCryptarithmPermutationFn(BenchNeed)
 structure E=BenchCryptarithmPermutationFn(BenchStrict)
 fun read path=let val input=TextIO.openIn path val text=TextIO.inputAll input in TextIO.closeIn input;text end
 val _=T.check("cryptarithm1/empty-permutation",fn()=>L.renderRows(L.permutations(L.S.empty()))="[[]]\n"andalso E.renderRows(E.permutations(E.S.empty()))="[[]]\n")
 val _=T.check("cryptarithm1/lazy-original-insertion-order",fn()=>L.renderRows(L.permutations(L.S.fromList[0,1,2,3]))=read "permutations4.expected")
 val _=T.check("cryptarithm1/strict-original-insertion-order",fn()=>E.renderRows(E.permutations(E.S.fromList[0,1,2,3]))=read "permutations4.expected")
 val _=T.check("cryptarithm1/all-720-permutations",fn()=>
   let val left=List.map L.S.toList(L.S.toList(L.permutations(L.S.fromList[0,1,2,3,4,5])))
       val right=List.map E.S.toList(E.S.toList(E.permutations(E.S.fromList[0,1,2,3,4,5])))
       fun distinct []=true |distinct(x::xs)=not(List.exists(fn y=>x=y)xs)andalso distinct xs
   in List.length left=720 andalso left=right andalso distinct left end)
 val _=T.check("cryptarithm1/original-equation",fn()=>L.condition(L.S.fromList[1,9,4,2,5,3,0,7,6,8]))
 val _=T.check("cryptarithm1/rejects-perturbed-assignment",fn()=>not(L.condition(L.S.fromList[2,9,4,1,5,3,0,7,6,8])))
 val _=T.check("cryptarithm1/lazy-prefix-leaves-digit-payload-delayed",fn()=>
   let val input=L.S.cons(BenchNeed.delay(fn()=>raise Fail "unused digit"))(L.S.fromList[1,2])
       val row=L.S.head(L.permutations input)
   in case BenchNeed.force row of L.S.Cons _=>true | _=>false end)
end
structure CryptarithmFilterSharing =
struct
 structure L=BenchCryptarithmPermutationFn(BenchNeed)
 val _=T.check("cryptarithm1/filter-prefix-is-shared-and-stops-on-demand",fn()=>
   let val calls=ref 0
       val selected=L.filter(fn n=>(calls:= !calls+1;n=2))(L.S.fromList[0,1,2,3])
   in L.S.head selected=2 andalso L.S.head selected=2 andalso !calls=3 end)
end
