structure BenchWordSetTests =
struct
  val inputs=[["a","b","c","d","e","f"],["f","e","d","c","b","a"],["a","c","b","b","d","a"],["f","a","d","b","e","c"]]
  val _=List.app(fn words=>
    let val tree=BenchWordSet.fromList words
        val _=T.check("set/balance-and-members",fn()=>(BenchWordSet.validate tree;List.all(fn w=>BenchWordSet.member w tree)words))
        val _=T.check("set/absent-word",fn()=>not(BenchWordSet.member "missing" tree))
    in()end)inputs
  val _=T.check("set/duplicate-size",fn()=>BenchWordSet.size(BenchWordSet.fromList["a","c","b","b","d","a"])=4)
  fun shape BenchWordSet.Tip="."
    |shape(BenchWordSet.Bin(n,key,l,r))="("^Int.toString n^":"^key^shape l^shape r^")"
  val tree=BenchWordSet.fromList(String.tokens BenchSpellCheck.space(BenchSpellCheck.file "dictionary.txt"))
  val _=T.check("set/reference-tree-shape",fn()=>shape tree^"\n"=BenchSpellCheck.file "shape.txt")
  val _=T.check("set/Latin1-whitespace",fn()=>BenchSpellCheck.space(Char.chr 133)andalso BenchSpellCheck.space(Char.chr 160)andalso not(BenchSpellCheck.space(Char.chr 233)))
end
