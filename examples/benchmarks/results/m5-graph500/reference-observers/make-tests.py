from pathlib import Path
p=Path(__file__).resolve().parent
head=r'''structure Graph500Tests =
struct
  val base="PRIVATE/"
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
  SORTS
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
'''
sorts=[]
for n in range(31):
 values=[((i*17+n*3)%5,i)for i in range(n)]
 wanted=sorted(values,key=lambda p:p[0])
 def sml(items):return'['+','.join('('+str(k)+','+str(i)+')'for k,i in items)+']'
 sorts.append('''val _=T.check(label"sort-%d",fn()=>
 let val values=%s val wanted=%s
     fun cmp((a,_),(b,_))=Int.compare(a,b)
     val a=Array.fromList values val _=BenchGraphSort.array cmp a
 in Array.foldr(op ::)[]a=wanted andalso BenchGraphSort.list cmp values=wanted end)'''%(n,sml(values),sml(wanted)))
(p/'tests.sml').write_text(head.replace('PRIVATE',str(p)).replace('SORTS','\n'.join(sorts)))
