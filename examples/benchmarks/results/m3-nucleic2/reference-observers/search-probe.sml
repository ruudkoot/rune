structure K=BenchNucleic2Fn(structure D=BenchNeed val shared=false)
val solutions=K.pseudoknot"1"
val result=BenchNeed.force(K.most_distant_atom solutions)
val _=print("MAXIMUM "^Real.toString result^"\n")
val _=print("SOLUTIONS "^Int.toString(K.F.length solutions)^"\n")
