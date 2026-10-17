from pathlib import Path
import re
p=Path(__file__).resolve().parent
raw=(p/'Input.code.txt').read_text();pairs=[]
for i in range(6):
 line=re.search(r'(?m)^temp'+str(i)+r' = (.+)$',raw)[1]
 pairs.extend((int(a),int(b))for a,b in re.findall(r'Pt (\d+) (\d+)',line))
assert len(pairs)==60
data='['+','.join('('+str(a)+','+str(b)+')'for a,b in pairs)+']'
s=r'''functor BenchBSPTProgramFn(D:BENCH_SUSPEND) =
struct
  structure T=BenchBSPTTreeFn(D)
  structure G=T.G
  structure R=G.R
  structure L=BenchLazy
  structure S=BenchStream
  structure UI=BenchBSPTUI
  fun text value=S.fromList(String.explode value)
  fun append a b=S.append a b
  fun delayed f=L.delay(fn()=>L.force(f()))
  fun drawSegment segment=L.delay(fn()=>
    let val(a,b)=L.force segment val G.Pt(x1,y1)=L.force a val G.Pt(x2,y2)=L.force b
    in L.force(text(UI.largeLine(List.map R.round[x1,y1,x2,y2])))end)
  fun drawFaces faces=S.concatMap(fn f=>drawSegment(G.getSegment f))faces
  fun drawTree tree=L.delay(fn()=>case L.force tree of T.Cell _=>S.Nil
    |T.BSP(_,(faces,_),left,right)=>L.force(append(drawFaces faces)(append(drawTree left)(drawTree right))))
  fun pretty le re depth tree=L.delay(fn()=>
    let val mid=(le+re)div 2
        fun vertical value=UI.writeVert(mid,depth)(List.map String.str(String.explode value))
    in case L.force tree of
      T.Cell(status,_,_)=>L.force(text(if re-le<=20 then vertical(statusName status)
         else UI.movePrintTo mid depth(statusName status)))
     |T.BSP(_,_,left,right)=>if re-le<=20 then L.force(text(vertical(Int.toString(T.countLeaves tree))))
       else L.force(append(text(UI.movePrintTo mid depth"@"))
         (append(pretty le mid(depth+14)left)(pretty mid re(depth+14)right)))end)
  and statusName T.In="In"|statusName T.Out="Out"|statusName T.On="On"
  fun prettyTree tree=append(text(UI.func 4))(append(pretty 120 900 550 tree)(text(UI.func 15)))
  fun partitioned tree=L.delay(fn()=>case L.force tree of T.Cell(_,region,_)=>
       L.force(drawFaces(G.getRegion region))
    |T.BSP(_,_,left,right)=>L.force(append(partitioned left)(partitioned right)))
  fun scanRules current=L.delay(fn()=>if R.greater current(R.number 510)then S.Nil else
      S.Cons(L.delay(fn()=>G.mkFace(G.point(R.number 120,current),G.point(R.number 900,current))),
        scanRules(R.add current(R.number 15))))
  fun render tree=drawFaces(S.concatMap(T.scanLine tree)(scanRules(R.number 1)))
  fun transform points=S.map(fn p=>L.delay(fn()=>let val G.Pt(x,y)=L.force p
      in G.Pt(R.grid x,R.grid y)end))points
  fun validate polygon=delayed(fn()=>if G.length polygon<3 then S.empty()else polygon)
  fun boolean UI.Union current operand=T.union current operand
    |boolean UI.Intersect current operand=T.intersection current operand
    |boolean UI.Subtract current operand=T.subtract current operand
    |boolean _ _ _=raise Match
  type operation=UI.command*G.point S.stream
  fun perform current(cmd,points)=
    case cmd of
      UI.Partition=>([fn()=>text(UI.clearRender()),fn()=>partitioned current],current)
    |UI.Render=>([fn()=>render current],current)
    |UI.Classify=>([
        fn()=>text(UI.labelClassify()),fn()=>text(UI.toTextRegion()),fn()=>text(UI.clearText()),
        fn()=>append(S.concatMap(fn point=>text("Status: "^statusName(T.classify point current)^"\n"))points)(text"\n"),
        fn()=>text(UI.unlabelButtons()),fn()=>text(UI.toNoTextRegion())],current)
    |UI.Area=>([fn()=>text(UI.toTextRegion()),fn()=>text"Area (pixels)\n",
         fn()=>text(UI.largeInteger(R.round(T.area current))),fn()=>text(UI.toNoTextRegion())],current)
    |UI.Complement=>
       let val tree=T.complement current
       in([fn()=>text(UI.clearTree()),fn()=>prettyTree tree,fn()=>text(UI.clearRender()),fn()=>drawTree tree],tree)end
    |UI.Polygon=>
       let val polygon=G.mkPolygon(transform points)
           val tree=T.build(validate polygon)
       in([fn()=>text(UI.clearRender()),fn()=>text(UI.labelDefinePoly()),fn()=>drawFaces polygon,
           fn()=>text"\n",fn()=>text(UI.clearTree()),fn()=>prettyTree tree,
           fn()=>text(UI.clearRender()),fn()=>drawTree tree,fn()=>text(UI.unlabelButtons())],tree)end
    |UI.Null=>([],current)
    |_=>let val polygon=G.mkPolygon(transform points)
            val tree=boolean cmd current(T.build(validate polygon))
        in([fn()=>text(UI.labelDefinePoly()),fn()=>drawFaces polygon,fn()=>text"\n",
            fn()=>text(UI.clearTree()),fn()=>prettyTree tree,fn()=>text(UI.clearRender()),
            fn()=>drawTree tree,fn()=>text(UI.unlabelButtons())],tree)end
  fun modeller current operations=L.delay(fn()=>case L.force operations of S.Nil=>raise Match
    |S.Cons(operation,rest)=>
      let val opValue as(cmd,_)=L.force operation
      in if cmd=UI.Quit then L.force(text(UI.reset()))
         else let val result=L.delay(fn()=>perform current opValue)
                  val following=L.delay(fn()=>L.force(modeller(#2(L.force result))rest))
              in if cmd=UI.Null then L.force following else
                 L.force(append(text(UI.mark cmd))
                   (append(S.concatMap(fn f=>f())(delayed(fn()=>S.fromList(#1(L.force result)))))
                     (append(text(UI.noMark cmd))following)))end end)
  fun splitLine text=
    let val n=String.size text
        fun find i=if i=n then n else if String.sub(text,i)= #" "then i else find(i+1)
        val i=find 0
    in(String.substring(text,0,i),if i=n then""else String.extract(text,i+1,NONE))end
  fun parseUnsigned text=
    let fun run exponent []=IntInf.fromInt 0
          |run exponent(c::rest)=R.iadd(R.imul(IntInf.fromInt(Char.ord c-Char.ord #"0"),
             R.wrap(IntInf.pow(IntInf.fromInt 10,exponent))),run(exponent-1)rest)
    in run(String.size text-1)(String.explode text)end
  fun pointOfLine value=
    let val(a,b)=splitLine value
    in if List.all Char.isDigit(String.explode(a^b))then
         G.point(R.node(R.integer(fn()=>R.iadd(parseUnsigned a,IntInf.fromInt ~5)),R.integer(fn()=>IntInf.fromInt 1)),
                 R.node(R.integer(fn()=>R.iadd(parseUnsigned b,IntInf.fromInt ~4)),R.integer(fn()=>IntInf.fromInt 1)))
       else G.integerPoint(0,0)end
  fun inScreen point=
    let val G.Pt(x,y)=L.force point
    in R.lessEqual(R.number 120)x andalso R.lessEqual x(R.number 900)
       andalso R.lessEqual(R.number 0)y andalso R.lessEqual y(R.number 510)end
  fun toCommand point=
    let val G.Pt(x,y)=L.force point
        fun search []=UI.Null|search((cmd,depth,_)::rest)=
          if R.lessEqual(R.number depth)y andalso R.lessEqual y(R.number(depth+40))
          then cmd else search rest
    in if R.less x(R.number 5)orelse R.greater x(R.number 115)then UI.Null else search UI.buttons end
  fun splitDelimiter []=([],[])
    |splitDelimiter(line::rest)=if line=UI.delimiter then([],rest)
      else let val(a,b)=splitDelimiter rest in(line::a,b)end
  fun interpret lines=L.delay(fn()=>case lines of []=>raise Match|line::rest=>
    let val cmd=toCommand(pointOfLine line)
        val(points,following)=case cmd of UI.Polygon=>splitDelimiter rest|UI.Union=>splitDelimiter rest
           |UI.Intersect=>splitDelimiter rest|UI.Subtract=>splitDelimiter rest|UI.Classify=>splitDelimiter rest
           |_ =>([],rest)
        val vertices=S.filter inScreen(S.map pointOfLine(S.fromList points))
    in S.Cons(L.delay(fn()=>(cmd,vertices)),interpret following)end)
  val batchPoints=S.fromList(List.map G.integerPoint BATCHDATA)
  val batchOperations=S.fromList[(UI.Polygon,batchPoints),(UI.Quit,S.empty())]
  val initialTree=T.build(S.empty())
  (* GHC's Prog.prog1 is an updatable batch-result thunk, shared across calls. *)
  val batchBody=modeller initialTree batchOperations
  val mouse=text UI.initialiseMouse
  val screen=text UI.initialiseScreen
  fun lines value=
    let val fields=String.fields(fn c=>c= #"\n")value
    in if value=""then[]else if String.sub(value,String.size value-1)= #"\n"
       then List.take(fields,List.length fields-1)else fields end
  fun prog input=append mouse(append screen(L.delay(fn()=>
     case lines input of []=>raise Match|first::rest=>
       L.force(if first="batch"then batchBody else modeller initialTree(interpret(first::rest))))))
end
'''
(p/'program.sml').write_text(s.replace('BATCHDATA',data))
