structure A=BenchBSPTProgramFn(BenchNeed)
structure B=BenchBSPTProgramFn(BenchStrict)
structure DA=BenchBSPTDriverFn(A)
structure DB=BenchBSPTDriverFn(B)
val base="tests/out/benchmarks/bspt-originals/cases/"
fun run name=
 let val input=DA.read(base^name^".input")
     val wanted=DA.read(base^name^".output")
     val _=DA.consume wanted(A.prog input)
     val _=print(name^" lazy matches\n")
     val _=DB.consume wanted(B.prog input)
 in print(name^" strict matches\n")end
val _=List.app run ["quit", "polygon", "area", "classify", "partition", "render", "complement", "union", "intersection", "subtract", "null-before-quit"]
