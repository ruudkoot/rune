val state=BenchOCamlRandom.default()
val edges=BenchGraph500.generate state 6 4
val _=print(Int.toString(Array.length edges)^" edges\n")
val _=List.app(fn i=>let val(s,e,w)=Array.sub(edges,i)
 in print(Int.toString s^" "^Int.toString e^" "^Real.fmt(StringCvt.GEN(SOME 17))w^"\n")end)[0,1,2,3]
