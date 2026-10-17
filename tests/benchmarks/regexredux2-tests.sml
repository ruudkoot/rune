structure RegexReduxTests=struct
 structure R=BenchRegexReduxStr
 structure B=BenchRegexRedux2
 val base=""
 fun label name="regexredux2/"^name
 fun read path=B.read(base^path)
 val _=List.app(fn(name,mode)=>T.check(label("original Str "^name),fn()=>
   let val pattern=read("cases/"^name^".pattern")val input=read("cases/"^name^".input")
       val regex=R.compile pattern
       val actual=if mode="replace"then R.replace regex(read("cases/"^name^".replacement"))input
         else if mode="count"then Int.toString(R.count regex input)^"\n"
         else case R.search false regex input 0 of NONE=>"none\n"
           |SOME(start,finish)=>Int.toString start^" "^Int.toString finish^"\n"
   in actual=read("cases/"^name^".output")end))[("overlap","count"),("alternative-left","search"),("alternative-right","search"),("greedy","search"),("backtracking","search"),("line-anchors","replace"),("tags","replace"),("pipes","replace"),("folded-class","count"),("class-exclusion","search"),("no-match","search"),("finish-eof","search")]
 val _=List.app(fn name=>T.check(label("original program "^name),fn()=>
   B.calculate(read("cases/"^name^".fasta"))=read("cases/"^name^".result")))
   ["empty","mixed-case","adjacent-tags","unterminated-header","overlapping-motifs"]
 val _=T.check(label "original smoke FASTA",fn()=>B.run[base^"smoke.fasta",base^"smoke.output"]="259")
 val _=T.check(label "wrong output rejected",fn()=>
   ((B.run[base^"smoke.fasta",base^"cases/empty.result"];false)handle Fail why=>String.isPrefix "incorrect result:"why))
 val _=T.check(label "negative search index rejected",fn()=>
   ((R.search false(R.compile "a")"a"(~1);false)handle Subscript=>true))
 val _=T.check(label "literal pipe is distinct from escaped alternation",fn()=>
   R.search false(R.compile "a|b")"a|b"0=SOME(0,3)andalso R.search false(R.compile "a\\|b")"ab"0=SOME(0,1))
 val _=T.check(label "malformed class rejected",fn()=>((R.compile "[abc";false)handle Fail _=>true))
 val _=T.check(label "empty replacement match rejected",fn()=>
   ((R.replace(R.compile "a*")"x""bbb";false)handle Fail why=>why="empty regex substitution unsupported"))
end
