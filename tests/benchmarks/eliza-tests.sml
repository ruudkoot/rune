structure ElizaNeed=BenchElizaFn(BenchNeed)
structure ElizaStrict=BenchElizaFn(BenchStrict)
structure ElizaNeedCheck=ElizaCheckFn(ElizaNeed)
structure ElizaStrictCheck=ElizaCheckFn(ElizaStrict)
structure ElizaTests=
struct
 structure N=ElizaNeed
 fun readLines path=
  let val input=TextIO.openIn path
      fun loop()=case TextIO.inputLine input of NONE=>[]|SOME line=>
        (if String.size line>0 andalso String.sub(line,String.size line-1)= #"\n"then String.substring(line,0,String.size line-1)else line)::loop()
      val lines=loop()val _=TextIO.closeIn input
  in lines end
 val lines=readLines "eliza.stdin"
 val _=List.app(fn n=>
  (T.check("eliza/full-lazy-prefix-"^Int.toString n,fn()=>ElizaNeedCheck.run lines n(Int.toString n^".session")>=0);
   T.check("eliza/full-strict-prefix-"^Int.toString n,fn()=>ElizaStrictCheck.run lines n(Int.toString n^".session")>=0)))
   (List.tabulate(20,fn i=>i))
 val cases=[("repeat",["hello","hello","hello","hello","hello","hello"]),
   ("rotate",["I feel sad","something","I feel sad","different","I feel sad","other","I feel sad"]),
   ("trailing-I",["can you I"]),("no-tail-default",["can you"]),("fallback",["flibbertigibbet"]),
   ("punctuation",[" ... Hello?! ","Hello","Hello"])]
 val _=List.app(fn(name,lines)=>
  (T.check("eliza/lazy-edge-"^name,fn()=>ElizaNeedCheck.run lines(List.length lines)("edge-"^name^".session")>=0);
   T.check("eliza/strict-edge-"^name,fn()=>ElizaStrictCheck.run lines(List.length lines)("edge-"^name^".session")>=0)))cases
 val _=T.check("eliza/unused-conjugation-not-demanded",fn()=>N.response "fixed"(BenchNeed.delay(fn()=>raise Fail "suffix demanded"))="fixed")
 val _=T.check("eliza/requested-conjugation-is-demanded",fn()=>
  let val calls=ref 0 val suffix=BenchNeed.delay(fn()=>(calls:= !calls+1;"you"))
  in N.response "?Tell" suffix="Tell you?"andalso N.response "?Tell" suffix="Tell you?"andalso !calls=1 end)
 val _=T.check("eliza/cyclic-queue-sharing",fn()=>
  let val root=N.cycle["a","b"]
      val N.QCons(a,tail)=BenchLazy.force root
      val N.QCons(b,again)=BenchLazy.force tail
      val N.QCons(c,_)=BenchLazy.force again
  in a="a"andalso b="b"andalso c="a"andalso root=again end)
 val _=T.check("eliza/punctuation-set-preserved",fn()=>N.trim " ..Hi?!, "="Hi"andalso N.trim ":Hi;"=":Hi;")
 val _=T.check("eliza/prefix-key-case-insensitive",fn()=>
  case BenchNeed.force(N.replies["CAN","YOU"]["cAn","yOu","help"])of
   N.RCons(suffix,_)=>BenchNeed.force suffix="help"|_=>false)
 fun rejects path=(ignore(ElizaNeedCheck.run lines 14 path);false)handle Fail message=>String.isPrefix "incorrect result:" message
 val _=T.check("eliza/wrong-response-rejected",fn()=>rejects "wrong.session")
 val _=T.check("eliza/truncated-response-rejected",fn()=>rejects "truncated.session")
 val _=T.check("eliza/extra-response-rejected",fn()=>rejects "extra.session")
end
