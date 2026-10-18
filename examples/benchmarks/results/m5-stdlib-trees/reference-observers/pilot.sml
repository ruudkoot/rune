structure M=BenchStdlibIntMap
structure S=BenchStdlibIntSet
val map=List.foldl(fn(k,m)=>M.add k k m)M.Empty[5,1,9,2,6,7,3,8,4]
val set=List.foldl(fn(k,s)=>S.add k s)S.Empty[5,1,9,2,6,7,3,8,4]
val _=print(M.shape map^"\n"^S.shape set^"\n")
val _=if M.invariant map andalso S.invariant set then()else raise Fail"invariant"
