structure FishPilot =
struct
 structure N=BenchFishFn(BenchNeed)
 structure S=BenchFishFn(BenchStrict)
 fun point point=let val(x,y)=BenchNeed.force point in(BenchNeed.force x,BenchNeed.force y)end
 val _=T.check("fish/negative-floor",fn()=>point(N.scale_vec2(N.vector(~3,7))1 2)=(~2,3))
 val _=T.check("fish/identity-grid",fn()=>N.tuples(N.p(N.vector(0,0))(N.vector(16,0))(N.vector(0,16)))=N.Q.toList N.p_tile)
 val _=T.check("fish/segment-count",fn()=>List.length(N.tuples(N.pseudolimit(N.vector(0,0))(N.vector(640,0))(N.vector(0,640))))=9344)
 val _=T.check("fish/variants",fn()=>N.tuples(N.pseudolimit(N.vector(0,0))(N.vector(640,0))(N.vector(0,640)))=
   S.tuples(S.pseudolimit(S.vector(0,0))(S.vector(640,0))(S.vector(0,640))))
 val _=T.check("fish/empty-format",fn()=>String.implode(N.Q.toList(N.fmt(N.Q.empty())))="[]")
 val _=T.check("fish/deferred-segment-prefix",fn()=>String.implode(N.Q.toList(N.Q.take 2
   (N.fmt(N.Q.cons(BenchNeed.delay(fn()=>raise Fail "unneeded segment"))(N.Q.empty())))))="[\n")

 fun read path=let val input=TextIO.openIn path
                   val text=TextIO.inputAll input
                   val _=TextIO.closeIn input
               in text end
 fun segments size=List.map(fn line=>case List.map(fn token=>valOf(Int.fromString token))
     (String.tokens Char.isSpace line)of [a,b,c,d]=>(a,b,c,d) | _=>raise Fail "invalid segment fixture")
   (String.tokens(fn c=>c= #"\n")(read(Int.toString size^".segments")))
 val _=List.app(fn size=>T.check("fish/original-coordinates-and-format-"^Int.toString size,fn()=>
   let val n=N.pseudolimit(N.vector(0,0))(N.vector(size,0))(N.vector(0,size))
       val strict=S.pseudolimit(S.vector(0,0))(S.vector(size,0))(S.vector(0,size))
       val expected=segments size
       val formatted=read(Int.toString size^".txt")
   in N.tuples n=expected andalso S.tuples strict=expected andalso
      String.implode(N.Q.toList(N.fmt n))=formatted andalso
      String.implode(S.Q.toList(S.fmt strict))=formatted end))[255,640,641]
 val _=T.check("fish/decimal-spine-length",fn()=>
   N.length(N.positive 123)=3)
end
