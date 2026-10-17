structure Graph500Tests =
struct
  val base=""
  fun label s="graph500/"^s
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun bytes path=let val f=BinIO.openIn path val data=BinIO.inputAll f val _=BinIO.closeIn f in data end
  fun save path data=let val f=BinIO.openOut path val _=BinIO.output(f,data)in BinIO.closeOut f end
  fun hex text=
    let val text=String.concat(String.tokens Char.isSpace text)
        fun digit c=if c>= #"0"andalso c<= #"9"then Char.ord c-Char.ord #"0"
          else if c>= #"a"andalso c<= #"f"then Char.ord c-Char.ord #"a"+10
          else raise Fail "bad graph hex"
    in if String.size text mod 2<>0 then raise Fail "odd graph hex"else
      Word8Vector.tabulate(String.size text div 2,fn i=>
        Word8.fromInt(16*digit(String.sub(text,2*i))+digit(String.sub(text,2*i+1))))end
  fun fixture name=hex(read(base^name^".marshal.hex"))
  val smoke=fixture"smoke"
  val _=save"_graph_smoke.input"smoke
  val generated=BenchGraph500.generate(BenchOCamlRandom.default())6 4
  val _=T.check(label"generation-full-marshal-bytes",fn()=>
    let val _=BenchGraphMarshal.write"_graph_generated.data"generated
    in bytes"_graph_generated.data"=smoke end)
  val decoded=BenchGraphMarshal.read"_graph_smoke.input"
  fun wanted row=case String.tokens Char.isSpace row of[a,b,w]=>
       (BenchInput.integer a,BenchInput.integer b,valOf(Real.fromString w))
    |_=>raise Fail "bad graph edge row"
  val expected=List.map wanted(String.tokens(fn c=>c= #"\n")(read(base^"smoke.edges")))
  val _=List.app(fn(i,(a,b,w))=>T.check(label("edge-"^Int.toString i),fn()=>
    let val(x,y,z)=Array.sub(generated,i)
        val(dx,dy,dw)=Array.sub(decoded,i)
    in a=x andalso b=y andalso Real.==(w,z)andalso a=dx andalso b=dy andalso Real.==(w,dw)end))
    (ListPair.zip(List.tabulate(List.length expected,fn i=>i),expected))
  val _=T.check(label"adjacency-full-order-and-weights",fn()=>
    BenchGraph500Driver.sparseSummary decoded="256 64 480 E24F6A0768BB404D")
  val _=List.app(fn name=>T.check(label("codec-roundtrip-"^name),fn()=>
    let val input=fixture name val _=save"_graph_codec.input"input
        val edges=BenchGraphMarshal.read"_graph_codec.input"
        val _=BenchGraphMarshal.write"_graph_codec.output"edges
    in bytes"_graph_codec.output"=input end))["empty","boundary"]
  val _=save"_graph_codec.input"(fixture"boundary")
  val boundary=BenchGraphMarshal.read"_graph_codec.input"
  val _=T.check(label"boundary-semantic-half",fn()=>
    let val(a,b,w)=Array.sub(boundary,1)in a=64 andalso b=127 andalso Real.==(w,0.5)end)
  val _=T.check(label"boundary-negative-zero-sign",fn()=>Real.signBit(#3(Array.sub(boundary,2))))
  val _=T.check(label"empty-graph-summary",fn()=>
    BenchGraph500Driver.sparseSummary(Array.fromList[])="0 0 0 0")
  fun malformed name transform=T.check(label("malformed-"^name),fn()=>
    let val input=transform smoke val _=save"_graph_bad.input"input
    in ((BenchGraphMarshal.read"_graph_bad.input";false)handle Fail _=>true|Overflow=>true|Subscript=>true)end)
  fun change index value data=Word8Vector.tabulate(Word8Vector.length data,
    fn i=>if i=index then Word8.fromInt value else Word8Vector.sub(data,i))
  val _=malformed"magic"(change 0 0)
  val _=malformed"body-length"(change 7 0)
  val _=malformed"object-count"(change 11 0)
  val _=malformed"heap32"(change 15 0)
  val _=malformed"heap64"(change 19 0)
  val _=malformed"short-header"(fn data=>Word8Vector.tabulate(10,fn i=>Word8Vector.sub(data,i)))
  val _=malformed"short-data"(fn data=>Word8Vector.tabulate(Word8Vector.length data-1,fn i=>Word8Vector.sub(data,i)))
  val _=malformed"extra-data"(fn data=>Word8Vector.concat[data,Word8Vector.fromList[0w0]])
  val _=malformed"outer-tag"(change 24 1)
  val _=malformed"edge-shape"(change 25 160)
  val small=Array.fromList[(2,1,0.3),(2,2,0.9),(1,2,0.5),(2,1,0.7),(0,0,0.1)]
  val graph=BenchGraph500.sparse small
  fun same(a,b)=ListPair.allEq(fn((i,x),(j,y))=>i=j andalso Real.==(x,y))(a,b)
  val _=T.check(label"sparse-selfloops",fn()=>List.null(Array.sub(graph,0)))
  val _=T.check(label"sparse-duplicates-and-order-forward",fn()=>same(Array.sub(graph,1),[(2,0.7),(2,0.5),(2,0.3)]))
  val _=T.check(label"sparse-duplicates-and-order-backward",fn()=>same(Array.sub(graph,2),[(1,0.7),(1,0.5),(1,0.3)]))
  val _=T.check(label"observed-max-label",fn()=>Array.length graph=3)
  val _=T.check(label"generator-empty-sort",fn()=>
    let val a:int array=Array.fromList[] val _=BenchGraphSort.array Int.compare a
    in Array.length a=0 end)
  val _=T.check(label"sort-0",fn()=>
 let val values=[] val wanted=[]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-1",fn()=>
 let val values=[(3,0)] val wanted=[(3,0)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-2",fn()=>
 let val values=[(1,0),(3,1)] val wanted=[(1,0),(3,1)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-3",fn()=>
 let val values=[(4,0),(1,1),(3,2)] val wanted=[(1,1),(3,2),(4,0)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-4",fn()=>
 let val values=[(2,0),(4,1),(1,2),(3,3)] val wanted=[(1,2),(2,0),(3,3),(4,1)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-5",fn()=>
 let val values=[(0,0),(2,1),(4,2),(1,3),(3,4)] val wanted=[(0,0),(1,3),(2,1),(3,4),(4,2)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-6",fn()=>
 let val values=[(3,0),(0,1),(2,2),(4,3),(1,4),(3,5)] val wanted=[(0,1),(1,4),(2,2),(3,0),(3,5),(4,3)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-7",fn()=>
 let val values=[(1,0),(3,1),(0,2),(2,3),(4,4),(1,5),(3,6)] val wanted=[(0,2),(1,0),(1,5),(2,3),(3,1),(3,6),(4,4)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-8",fn()=>
 let val values=[(4,0),(1,1),(3,2),(0,3),(2,4),(4,5),(1,6),(3,7)] val wanted=[(0,3),(1,1),(1,6),(2,4),(3,2),(3,7),(4,0),(4,5)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-9",fn()=>
 let val values=[(2,0),(4,1),(1,2),(3,3),(0,4),(2,5),(4,6),(1,7),(3,8)] val wanted=[(0,4),(1,2),(1,7),(2,0),(2,5),(3,3),(3,8),(4,1),(4,6)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-10",fn()=>
 let val values=[(0,0),(2,1),(4,2),(1,3),(3,4),(0,5),(2,6),(4,7),(1,8),(3,9)] val wanted=[(0,0),(0,5),(1,3),(1,8),(2,1),(2,6),(3,4),(3,9),(4,2),(4,7)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-11",fn()=>
 let val values=[(3,0),(0,1),(2,2),(4,3),(1,4),(3,5),(0,6),(2,7),(4,8),(1,9),(3,10)] val wanted=[(0,1),(0,6),(1,4),(1,9),(2,2),(2,7),(3,0),(3,5),(3,10),(4,3),(4,8)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-12",fn()=>
 let val values=[(1,0),(3,1),(0,2),(2,3),(4,4),(1,5),(3,6),(0,7),(2,8),(4,9),(1,10),(3,11)] val wanted=[(0,2),(0,7),(1,0),(1,5),(1,10),(2,3),(2,8),(3,1),(3,6),(3,11),(4,4),(4,9)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-13",fn()=>
 let val values=[(4,0),(1,1),(3,2),(0,3),(2,4),(4,5),(1,6),(3,7),(0,8),(2,9),(4,10),(1,11),(3,12)] val wanted=[(0,3),(0,8),(1,1),(1,6),(1,11),(2,4),(2,9),(3,2),(3,7),(3,12),(4,0),(4,5),(4,10)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-14",fn()=>
 let val values=[(2,0),(4,1),(1,2),(3,3),(0,4),(2,5),(4,6),(1,7),(3,8),(0,9),(2,10),(4,11),(1,12),(3,13)] val wanted=[(0,4),(0,9),(1,2),(1,7),(1,12),(2,0),(2,5),(2,10),(3,3),(3,8),(3,13),(4,1),(4,6),(4,11)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-15",fn()=>
 let val values=[(0,0),(2,1),(4,2),(1,3),(3,4),(0,5),(2,6),(4,7),(1,8),(3,9),(0,10),(2,11),(4,12),(1,13),(3,14)] val wanted=[(0,0),(0,5),(0,10),(1,3),(1,8),(1,13),(2,1),(2,6),(2,11),(3,4),(3,9),(3,14),(4,2),(4,7),(4,12)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-16",fn()=>
 let val values=[(3,0),(0,1),(2,2),(4,3),(1,4),(3,5),(0,6),(2,7),(4,8),(1,9),(3,10),(0,11),(2,12),(4,13),(1,14),(3,15)] val wanted=[(0,1),(0,6),(0,11),(1,4),(1,9),(1,14),(2,2),(2,7),(2,12),(3,0),(3,5),(3,10),(3,15),(4,3),(4,8),(4,13)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-17",fn()=>
 let val values=[(1,0),(3,1),(0,2),(2,3),(4,4),(1,5),(3,6),(0,7),(2,8),(4,9),(1,10),(3,11),(0,12),(2,13),(4,14),(1,15),(3,16)] val wanted=[(0,2),(0,7),(0,12),(1,0),(1,5),(1,10),(1,15),(2,3),(2,8),(2,13),(3,1),(3,6),(3,11),(3,16),(4,4),(4,9),(4,14)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-18",fn()=>
 let val values=[(4,0),(1,1),(3,2),(0,3),(2,4),(4,5),(1,6),(3,7),(0,8),(2,9),(4,10),(1,11),(3,12),(0,13),(2,14),(4,15),(1,16),(3,17)] val wanted=[(0,3),(0,8),(0,13),(1,1),(1,6),(1,11),(1,16),(2,4),(2,9),(2,14),(3,2),(3,7),(3,12),(3,17),(4,0),(4,5),(4,10),(4,15)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-19",fn()=>
 let val values=[(2,0),(4,1),(1,2),(3,3),(0,4),(2,5),(4,6),(1,7),(3,8),(0,9),(2,10),(4,11),(1,12),(3,13),(0,14),(2,15),(4,16),(1,17),(3,18)] val wanted=[(0,4),(0,9),(0,14),(1,2),(1,7),(1,12),(1,17),(2,0),(2,5),(2,10),(2,15),(3,3),(3,8),(3,13),(3,18),(4,1),(4,6),(4,11),(4,16)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-20",fn()=>
 let val values=[(0,0),(2,1),(4,2),(1,3),(3,4),(0,5),(2,6),(4,7),(1,8),(3,9),(0,10),(2,11),(4,12),(1,13),(3,14),(0,15),(2,16),(4,17),(1,18),(3,19)] val wanted=[(0,0),(0,5),(0,10),(0,15),(1,3),(1,8),(1,13),(1,18),(2,1),(2,6),(2,11),(2,16),(3,4),(3,9),(3,14),(3,19),(4,2),(4,7),(4,12),(4,17)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-21",fn()=>
 let val values=[(3,0),(0,1),(2,2),(4,3),(1,4),(3,5),(0,6),(2,7),(4,8),(1,9),(3,10),(0,11),(2,12),(4,13),(1,14),(3,15),(0,16),(2,17),(4,18),(1,19),(3,20)] val wanted=[(0,1),(0,6),(0,11),(0,16),(1,4),(1,9),(1,14),(1,19),(2,2),(2,7),(2,12),(2,17),(3,0),(3,5),(3,10),(3,15),(3,20),(4,3),(4,8),(4,13),(4,18)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-22",fn()=>
 let val values=[(1,0),(3,1),(0,2),(2,3),(4,4),(1,5),(3,6),(0,7),(2,8),(4,9),(1,10),(3,11),(0,12),(2,13),(4,14),(1,15),(3,16),(0,17),(2,18),(4,19),(1,20),(3,21)] val wanted=[(0,2),(0,7),(0,12),(0,17),(1,0),(1,5),(1,10),(1,15),(1,20),(2,3),(2,8),(2,13),(2,18),(3,1),(3,6),(3,11),(3,16),(3,21),(4,4),(4,9),(4,14),(4,19)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-23",fn()=>
 let val values=[(4,0),(1,1),(3,2),(0,3),(2,4),(4,5),(1,6),(3,7),(0,8),(2,9),(4,10),(1,11),(3,12),(0,13),(2,14),(4,15),(1,16),(3,17),(0,18),(2,19),(4,20),(1,21),(3,22)] val wanted=[(0,3),(0,8),(0,13),(0,18),(1,1),(1,6),(1,11),(1,16),(1,21),(2,4),(2,9),(2,14),(2,19),(3,2),(3,7),(3,12),(3,17),(3,22),(4,0),(4,5),(4,10),(4,15),(4,20)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-24",fn()=>
 let val values=[(2,0),(4,1),(1,2),(3,3),(0,4),(2,5),(4,6),(1,7),(3,8),(0,9),(2,10),(4,11),(1,12),(3,13),(0,14),(2,15),(4,16),(1,17),(3,18),(0,19),(2,20),(4,21),(1,22),(3,23)] val wanted=[(0,4),(0,9),(0,14),(0,19),(1,2),(1,7),(1,12),(1,17),(1,22),(2,0),(2,5),(2,10),(2,15),(2,20),(3,3),(3,8),(3,13),(3,18),(3,23),(4,1),(4,6),(4,11),(4,16),(4,21)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-25",fn()=>
 let val values=[(0,0),(2,1),(4,2),(1,3),(3,4),(0,5),(2,6),(4,7),(1,8),(3,9),(0,10),(2,11),(4,12),(1,13),(3,14),(0,15),(2,16),(4,17),(1,18),(3,19),(0,20),(2,21),(4,22),(1,23),(3,24)] val wanted=[(0,0),(0,5),(0,10),(0,15),(0,20),(1,3),(1,8),(1,13),(1,18),(1,23),(2,1),(2,6),(2,11),(2,16),(2,21),(3,4),(3,9),(3,14),(3,19),(3,24),(4,2),(4,7),(4,12),(4,17),(4,22)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-26",fn()=>
 let val values=[(3,0),(0,1),(2,2),(4,3),(1,4),(3,5),(0,6),(2,7),(4,8),(1,9),(3,10),(0,11),(2,12),(4,13),(1,14),(3,15),(0,16),(2,17),(4,18),(1,19),(3,20),(0,21),(2,22),(4,23),(1,24),(3,25)] val wanted=[(0,1),(0,6),(0,11),(0,16),(0,21),(1,4),(1,9),(1,14),(1,19),(1,24),(2,2),(2,7),(2,12),(2,17),(2,22),(3,0),(3,5),(3,10),(3,15),(3,20),(3,25),(4,3),(4,8),(4,13),(4,18),(4,23)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-27",fn()=>
 let val values=[(1,0),(3,1),(0,2),(2,3),(4,4),(1,5),(3,6),(0,7),(2,8),(4,9),(1,10),(3,11),(0,12),(2,13),(4,14),(1,15),(3,16),(0,17),(2,18),(4,19),(1,20),(3,21),(0,22),(2,23),(4,24),(1,25),(3,26)] val wanted=[(0,2),(0,7),(0,12),(0,17),(0,22),(1,0),(1,5),(1,10),(1,15),(1,20),(1,25),(2,3),(2,8),(2,13),(2,18),(2,23),(3,1),(3,6),(3,11),(3,16),(3,21),(3,26),(4,4),(4,9),(4,14),(4,19),(4,24)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-28",fn()=>
 let val values=[(4,0),(1,1),(3,2),(0,3),(2,4),(4,5),(1,6),(3,7),(0,8),(2,9),(4,10),(1,11),(3,12),(0,13),(2,14),(4,15),(1,16),(3,17),(0,18),(2,19),(4,20),(1,21),(3,22),(0,23),(2,24),(4,25),(1,26),(3,27)] val wanted=[(0,3),(0,8),(0,13),(0,18),(0,23),(1,1),(1,6),(1,11),(1,16),(1,21),(1,26),(2,4),(2,9),(2,14),(2,19),(2,24),(3,2),(3,7),(3,12),(3,17),(3,22),(3,27),(4,0),(4,5),(4,10),(4,15),(4,20),(4,25)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-29",fn()=>
 let val values=[(2,0),(4,1),(1,2),(3,3),(0,4),(2,5),(4,6),(1,7),(3,8),(0,9),(2,10),(4,11),(1,12),(3,13),(0,14),(2,15),(4,16),(1,17),(3,18),(0,19),(2,20),(4,21),(1,22),(3,23),(0,24),(2,25),(4,26),(1,27),(3,28)] val wanted=[(0,4),(0,9),(0,14),(0,19),(0,24),(1,2),(1,7),(1,12),(1,17),(1,22),(1,27),(2,0),(2,5),(2,10),(2,15),(2,20),(2,25),(3,3),(3,8),(3,13),(3,18),(3,23),(3,28),(4,1),(4,6),(4,11),(4,16),(4,21),(4,26)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
val _=T.check(label"sort-30",fn()=>
 let val values=[(0,0),(2,1),(4,2),(1,3),(3,4),(0,5),(2,6),(4,7),(1,8),(3,9),(0,10),(2,11),(4,12),(1,13),(3,14),(0,15),(2,16),(4,17),(1,18),(3,19),(0,20),(2,21),(4,22),(1,23),(3,24),(0,25),(2,26),(4,27),(1,28),(3,29)] val wanted=[(0,0),(0,5),(0,10),(0,15),(0,20),(0,25),(1,3),(1,8),(1,13),(1,18),(1,23),(1,28),(2,1),(2,6),(2,11),(2,16),(2,21),(2,26),(3,4),(3,9),(3,14),(3,19),(3,24),(3,29),(4,2),(4,7),(4,12),(4,17),(4,22),(4,27)]
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)
  fun zeros()=BenchOCamlRandom.make(Vector.tabulate(55,fn _=>(0w0:Word32.word)))
  val _=T.check(label"array-permutation-key-ties-stay-stable",fn()=>
    let val result=BenchGraph500.permute(zeros())(Array.fromList[3,1,2])
    in Array.foldr(op ::)[]result=[3,1,2]end)
  val _=T.check(label"prototype-key-ties-compare-payload",fn()=>
    BenchKroneckerPrototype.permute Int.compare(zeros())[3,1,2]=[1,2,3])
  val _=T.check(label"prototype-full-csv-bytes",fn()=>
    let val rows=BenchKroneckerPrototype.generate(BenchOCamlRandom.default())3 1
        val _=BenchKroneckerPrototype.write"_graph_prototype.csv"rows
    in read"_graph_prototype.csv"=read(base^"smoke.csv")end)
end
