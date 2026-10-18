structure E=BenchCompLabFn(BenchStrict)
val a=E.makeTree 2(E.F.fromList[1,2])
val b=E.makeTree 2(E.F.fromList[2,3])
val tree=E.treeUnion(#2(BenchStrict.force a))(#2(BenchStrict.force b))
val _=if E.F.toList(E.flatten tree)=[1,2,2,3]then print"PASS strict merge\n"else raise Fail"strict merge"
