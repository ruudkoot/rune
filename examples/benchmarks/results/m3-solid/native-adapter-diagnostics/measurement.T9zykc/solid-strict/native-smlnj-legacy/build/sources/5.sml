(* Rune port of Hartel solid. Classification vector indices are corrected
 * from source one-based indices to the zero-based portable vector adapter. *)
functor BenchSolidFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 datatype pointNode=Point of real D.t*real D.t
 type point=pointNode D.t
 datatype primitiveNode=Circle of real D.t*point*int D.t
   |Line of real D.t*real D.t*real D.t*int D.t
 type primitive=primitiveNode D.t
 datatype operation=Union|Intersection|Difference
 datatype csgNode=Full|Empty|Primitive of primitive|Compose of csgNode L.delay*operation*csgNode L.delay
 type csg=csgNode L.delay
 datatype cellNode=Cell of real D.t*real D.t*real D.t*real D.t
 type cell=cellNode D.t
 datatype gdtNode=Terminal of cell*csg|Interior of gdtNode L.delay F.seq
 type gdt=gdtNode L.delay
 fun point x y=D.delay(fn()=>Point(D.delay(fn()=>x),D.delay(fn()=>y)))
 fun cell xmin xmax ymin ymax=D.delay(fn()=>Cell(D.delay(fn()=>xmin),D.delay(fn()=>xmax),D.delay(fn()=>ymin),D.delay(fn()=>ymax)))
 fun bounds box=case D.force box of Cell(a,b,c,d)=>(D.force a,D.force b,D.force c,D.force d)
 fun coordinates p=case D.force p of Point(x,y)=>(D.force x,D.force y)
 fun circle radius x y surface=D.delay(fn()=>Circle(D.delay(fn()=>radius),point x y,D.delay(fn()=>surface)))
 fun line a b c surface=D.delay(fn()=>Line(D.delay(fn()=>a),D.delay(fn()=>b),D.delay(fn()=>c),D.delay(fn()=>surface)))
 fun full()=L.delay(fn()=>Full)
 fun empty()=L.delay(fn()=>Empty)
 fun primitive p=L.delay(fn()=>Primitive p)
 fun composed a operation b=L.delay(fn()=>Compose(a,operation,b))
 val universe=cell 0.0 1.0 0.0 1.0
 fun distance a b=
   let val(x1,y1)=coordinates a val(x2,y2)=coordinates b
       val dx=x1-x2 val dy=y1-y2
   in Math.sqrt(dx*dx+dy*dy)end
 fun isFull tree=case L.force tree of Full=>true|_=>false
 fun isEmpty tree=case L.force tree of Empty=>true|_=>false
 fun merge a Union b=L.delay(fn()=>
      if isFull a then L.force a else if isFull b then L.force b
      else if isEmpty a then L.force b else if isEmpty b then L.force a
      else Compose(a,Union,b))
   |merge a Intersection b=L.delay(fn()=>
      if isFull a then L.force b else if isFull b then L.force a
      else if isEmpty a then L.force a else if isEmpty b then L.force b
      else Compose(a,Intersection,b))
   |merge a Difference b=L.delay(fn()=>
      if isEmpty a then Empty else if isFull b then Empty
      else if isEmpty b then L.force a else Compose(a,Difference,b))
 fun prunePrimitive p box=L.delay(fn()=>case D.force p of
      Circle(radius,center,_)=>
       let val(xmin,xmax,ymin,ymax)=bounds box
           val middle=point((xmin+xmax)*0.5)((ymin+ymax)*0.5)
           val boxRadius=distance middle(point xmin ymin)
           val separation=distance center middle
       in if separation+boxRadius<=D.force radius then Full
          else if separation>=boxRadius+D.force radius then Empty else Primitive p end
     |Line(a,b,c,_)=>
       let val(xmin,xmax,ymin,ymax)=bounds box
           fun value x y=D.force a*x+(D.force b*y+D.force c)
           val c0=L.delay(fn()=>value xmin ymin)
           val c1=L.delay(fn()=>value xmax ymin)
           val c2=L.delay(fn()=>value xmax ymax)
           val c3=L.delay(fn()=>value xmin ymax)
       in if L.force c0>0.0 andalso L.force c1>0.0 andalso L.force c2>0.0 andalso L.force c3>0.0 then Empty
          else if L.force c0<=0.0 andalso L.force c1<=0.0 andalso L.force c2<=0.0 andalso L.force c3<=0.0 then Full
          else Primitive p end)
 fun prune box tree=L.delay(fn()=>case L.force tree of Full=>Full|Empty=>Empty
   |Primitive p=>L.force(prunePrimitive p box)
   |Compose(a,operation,b)=>L.force(merge(prune box a)operation(prune box b)))
 val unionTable=Vector.fromList[0,0,0,0,0,3,1,3,0,1,2,3,0,3,3,3]
 val intersectionTable=Vector.fromList[0,1,2,3,1,3,2,3,2,2,2,2,3,3,2,3]
 val differenceTable=Vector.fromList[2,1,0,3,2,3,1,3,2,2,2,2,2,3,3,3]
 fun combine first operation last=
   Vector.sub(case operation of Union=>unionTable|Intersection=>intersectionTable|Difference=>differenceTable,4*first+last)
 fun classifyPrimitive p query=case D.force p of Circle(radius,center,_)=>
     let val(x,y)=coordinates query val(cx,cy)=coordinates center
         val dx=x-cx val dy=y-cy val r=D.force radius
         val value=dx*dx+(dy*dy-r*r)
     in if value>0.0 then 2 else if value<0.0 then 0 else 1 end
   |Line(a,b,c,_)=>let val(x,y)=coordinates query
                       (* Preserve the source's line-expression grouping. *)
                       val value=D.force a*(x+D.force b*(y+D.force c))
                  in if value>0.0 then 2 else if value<0.0 then 0 else 1 end
 fun classify query tree=case L.force tree of Full=>0|Empty=>2
   |Primitive p=>classifyPrimitive p query
   |Compose(a,operation,b)=>combine(classify query a)operation(classify query b)
 fun approximate box tree=L.delay(fn()=>
   let val middle=D.delay(fn()=>let val(xmin,xmax,ymin,ymax)=bounds box
                               in D.force(point((xmin+xmax)*0.5)((ymin+ymax)*0.5))end)
   in if classify middle tree=2 then Empty else Full end)
 fun split box=
   case D.force box of Cell(xmin,xmax,ymin,ymax)=>
     let val x=D.delay(fn()=>(D.force xmin+D.force xmax)*0.5)
         val y=D.delay(fn()=>(D.force ymin+D.force ymax)*0.5)
         fun make a b c d=D.delay(fn()=>Cell(a,b,c,d))
     in F.fromList[make xmin x ymin y,make xmin x y ymax,make x xmax ymin y,make x xmax y ymax]end
 fun simple tree=case L.force tree of Full=>true|Empty=>true|_=>false
 fun build maximum box tree=
   let fun create depth box tree=L.delay(fn()=>
         if simple tree orelse depth=maximum then Terminal(box,approximate box tree)
         else Interior(F.map(fn child=>create(depth+1)child(prune child tree))(split box)))
   in create 0 box tree end
 fun leafArea box tree=case L.force tree of Empty=>0.0|Full=>
      let val(xmin,xmax,_,_)=bounds box val d=xmax-xmin in d*d end
   |_=>raise Fail"unapproximated terminal solid"
 fun area tree=case L.force tree of Terminal(box,solid)=>leafArea box solid
   |Interior children=>
     let fun sum children=case D.force children of F.Nil=>0.0
           |F.Cons(child,rest)=>area(D.force child)+sum rest
     in sum children end
 fun shape tree=case L.force tree of Terminal(_,solid)=>if isFull solid then"F"else"E"
   |Interior children=>"("^String.concat(List.map shape(F.toList children))^")"
 fun operation #"u"=Union|operation #"d"=Difference|operation _=Intersection
 fun parse text=
   let val size=String.size text
       fun white c=c= #" "orelse c= #"\t"orelse c= #"\n"
       fun skip i=if i<size andalso white(String.sub(text,i))then skip(i+1)else i
       fun scan test i=if i<size andalso test(String.sub(text,i))then scan test(i+1)else i
       fun token test i=
         let val first=skip i val last=scan test first
         in(String.substring(text,first,last-first),last)end
       fun integerValue text=
         List.foldl(fn(c,n)=>10*n+Char.ord c-Char.ord #"0")0(String.explode text)
       fun realValue text=
         case String.fields(fn c=>c= #".")text of
          [a,b]=>Real.fromInt(integerValue a)+Real.fromInt(integerValue b)/Math.pow(10.0,Real.fromInt(String.size b))
         |_=>raise Fail"source solid decimal requires a dot"
       fun number i=let val(text,last)=token Char.isDigit i in(integerValue text,last)end
       fun realToken i=token(fn c=>Char.isDigit c orelse c= #".")i
       fun primitiveAt i=
         let val first=skip i val kind=String.substring(text,first,2)
             val(a,next)=realToken(first+2)
             val(b,next)=realToken next
             val(c,next)=realToken next
             val(surface,last)=token Char.isDigit next
             val value=D.delay(fn()=>if kind="ci"then
                 Circle(D.delay(fn()=>realValue a),D.delay(fn()=>D.force(point(realValue b)(realValue c))),D.delay(fn()=>integerValue surface))
               else Line(D.delay(fn()=>realValue a),D.delay(fn()=>realValue b),D.delay(fn()=>realValue c),D.delay(fn()=>integerValue surface)))
         in(value,last)end
       val(count,next)=number 0
       val first=skip next val nodes=String.substring(text,first,count)
       val(_,afterCount)=token Char.isDigit(first+count)
       fun loop [] cursor stack=(case stack of tree::_=>tree|_=>raise Fail"empty source solid stack")
         |loop(code::rest)cursor stack=
            if code= #"h"then let val(p,next)=primitiveAt cursor in loop rest next(primitive p::stack)end
            else if code= #"e"then loop rest cursor(empty()::stack)
            else if code= #"f"then loop rest cursor(full()::stack)
            else case stack of b::a::tail=>loop rest cursor(composed a(operation code)b::tail)
                 |_=>raise Fail"source solid stack underflow"
   in loop(String.explode nodes)afterCount[]end
 fun solution text depth=build depth universe(parse text)
 fun evaluate text depth=area(solution text depth)
end
