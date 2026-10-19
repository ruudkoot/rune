(* PostScript support for Iain Checkland's GRIP graph package.
   Preserve source commands, operand types and historical formatting. *)
functor BenchGGGraphicsFn(D:BENCH_SUSPEND) =
struct
 structure I=IntInf
 structure L=BenchLazy
 structure S=BenchStream
 structure F=BenchMandelSingle
 type number=I.int D.t
 datatype point=Pt of number*number
 type text=char S.stream
 fun lit s=S.fromList(String.explode s)
 fun append a b=S.append a b
 fun concat texts=List.foldr(fn(a,b)=>append a b)(S.empty())texts
 fun delay make=L.delay(fn()=>L.force(make()))
 fun n(x:I.int)=D.delay(fn()=>x)
 fun value(x:number)=D.force x
 fun integer x=String.translate(fn #"~"=>"-"|c=>String.str c)(I.toString x)
 fun real value=
   if Real.isNan value then"NaN"
   else if not(Real.isFinite value)then if Real.signBit value then"-Infinity"else"Infinity"
   else let val raw=String.translate(fn #"~"=>"-"| #"E"=>"e"|c=>String.str c)
                (Real.fmt(StringCvt.GEN(SOME 17))value)
        in if List.exists(fn c=>c= #"."orelse c= #"e")(String.explode raw)then raw else raw^".0"end
 fun fromInt x=Real.fromLargeInt x
 fun single x=if Real.isFinite x then F.round x else x
 fun fromSingle x=single(fromInt x)
 fun singleDiv(a,b)=single(a/b)
 fun singleMul(a,b)=single(a*b)
 fun printFloat x=
   let val r=integer(Real.toLargeInt IEEEReal.TO_NEAREST(singleMul(x,10.0)))
   in if r="0"then"0"else if x<1.0 then"0."^r
      else if x<10.0 then
        if String.size r=2 andalso String.sub(r,1)= #"0"then String.substring(r,0,1)
        else String.substring(r,0,1)^"."^String.extract(r,1,NONE)
      else integer(Real.toLargeInt IEEEReal.TO_NEAREST x)end
 val paperX=I.fromInt 280 val paperY=I.fromInt 190
 val dimX=I.fromInt 250 val dimY=I.fromInt 150
 fun command name args=lit(String.concat(List.map(fn x=>integer x^" ")args)^name^"\n")
 val newpath=lit"newpath\n"
 val stroke=lit"stroke\n"
 val closepath=lit"closepath\n"
 val fill=lit"fill\n"
 val thinlines=lit"0.2 setlinewidth\n"
 val showpage=lit"showpage\n\n"
 fun font name=lit(name^" setfont\n")
 fun gray value=lit(if value=0 then"0 setgray\n"else if value=10 then"1 setgray\n"else"."^integer value^" setgray\n")
 fun moveto(Pt(x,y))=delay(fn()=>command"moveto"[value x,value y])
 fun lineto(Pt(x,y))=delay(fn()=>command"lineto"[value x,value y])
 fun rlineto x y=command"rlineto"[x,y]
 fun translate x y=command"translate"[x,y]
 fun scale x y=lit(real x^" "^real y^" scale\n")
 fun text s=append(gray 0)(lit("("^s^") show\n"))
 fun right s=lit("("^s^") rightshow\n")
 fun centre s=lit("("^s^") centreshow\n")
 fun drawBox pt dx dy=concat[thinlines,newpath,moveto pt,rlineto 0 dy,rlineto dx 0,
   rlineto 0(~dy),closepath,stroke]
 fun fillBox pt dx dy color=concat[newpath,moveto pt,rlineto 0 dy,rlineto dx 0,
   rlineto 0(~dy),closepath,gray color,fill]
 fun fillObject points=concat[newpath,moveto(Pt(n 0,n 0)),
   S.concatMap lineto points,closepath,fill,stroke]
 fun plotCurve color points=append(gray color)(fillObject points)
 val header="%!PS-Adobe-2.0\n%%Created by Haskell Graph Package\n"
 val procedures="/rightshow\n{dup stringwidth pop\n0 exch sub\n0 rmoveto\nshow } def \n"^
   "/centreshow\n{dup stringwidth pop\n0 exch sub\n2 div\n0 rmoveto\nshow } def \n"
 fun initialise head=lit(head^"/SMALL /Helvetica findfont 4 scalefont def\n"^
   "/SMALLBOLD /Helvetica-Bold findfont 4 scalefont def\n"^
   "/SMALLITALIC /Helvetica-Oblique findfont 4 scalefont def\n"^
   "/NORM /Helvetica findfont 5 scalefont def\n"^
   "/BOLD /Helvetica-Bold findfont 5 scalefont def\n"^
   "/LARGE /Helvetica-Bold findfont 11 scalefont def\n"^
   "NORM setfont\n2.84584 2.84584 scale\n"^procedures^"0.2 setlinewidth\n")
 fun landscape body=concat[initialise header,translate 8 290,command"rotate"[270],
   translate 20 10,lit"0.9 0.9 scale\n",body,lit"showpage\n"]
 fun portrait body=concat[initialise header,body,lit"showpage\n"]
 fun encapsulated(dx,dy)body=
   let fun points x=Real.toLargeInt IEEEReal.TO_NEAREST(28.4584*fromInt x)
       val head=header^"%%BoundingBox: 0 0 "^integer(points dx)^" "^integer(points dy)^"\n%%EndComments\n"
   in concat[initialise head,scale(fromInt dx*10.0/fromInt paperX)(fromInt dy*10.0/fromInt paperY),
     body,showpage]end
 fun inv(color:I.int)=gray(if color>=5 then 0 else 10)
 fun markOnX count=
   let val m=fromInt dimX/fromInt count
       fun notch k=concat[lit(real(m*fromInt k)^" 0 moveto\n"),rlineto 0(~1),stroke]
   in concat[concat(List.tabulate(I.toInt count,fn i=>notch(I.fromInt(i+1)))),stroke]end
 fun calibrate(x:I.int)=if x<=1 then 1 else if x<=100 then x else calibrate(I.div(x,10))
 fun markOnY count=
   let val m=fromInt dimY/fromInt count
       fun notch k=concat[lit("0 "^real(m*fromInt k)^" moveto\n"),rlineto(~1)0]
   in concat[concat(List.tabulate(I.toInt count,fn i=>notch(I.fromInt(i+1)))),stroke]end
 fun markXAxis maxX=
   let fun label k=if k=0 then S.empty()else
         let val notch=I.*(k,I.div(dimX,10))
             val t=singleMul(fromSingle k,singleDiv(fromSingle maxX,10.0))
         in concat[newpath,moveto(Pt(n notch,n 0)),rlineto 0(~2),moveto(Pt(n notch,n(~5))),
           centre(printFloat t),stroke,label(k-1)]end
   in append(label 10)(markOnX 100)end
 fun markYAxis maxY=
   let fun label k=if k=0 then S.empty()else
         let val notch=I.*(k,I.div(dimY,10))
             val t=singleMul(fromSingle k,singleDiv(fromSingle maxY,10.0))
         in concat[newpath,moveto(Pt(n 0,n notch)),rlineto(~2)0,moveto(Pt(n(~3),n notch)),
           right(printFloat t),stroke,label(k-1)]end
   in append(label 10)(markOnY(calibrate maxY))end
 fun axisScale(x:I.int)=
   let fun loop m=if x<=m then m else if x<=m*2 then m*2 else if x<=m*5 then m*5
         else if x<=m*10 then m*10 else loop(m*10)
   in loop 1 end
 fun keys entries=
   let val no=I.div(dimX,I.fromInt(List.length entries))
       fun loop _ []=S.empty()
         |loop index((color,title,percent)::rest)=
           if I.fromInt index=no then S.empty()else
           let val x=I.*(I.fromInt index,no)val y=I.fromInt(~17)val pt=Pt(n x,n y)
           in concat[fillBox pt 16 9 color,stroke,moveto(Pt(n(x+17),n(y+3))),text title,stroke,
             moveto(Pt(n(x+8),n(y+3))),inv color,font"BOLD",delay(fn()=>centre(L.force percent)),stroke,font"NORM",gray 10,
             loop(index+1)rest]end
   in loop 0 entries end
 fun processorText entries=
   let val no=I.div(paperX-27,I.fromInt(List.length entries*2+1))
       fun loop _ []=S.empty()
         |loop index((f,label)::rest)=
           if I.fromInt index>2*no then S.empty()else
           let val x=no*(I.fromInt index*2+1)+27
           in concat[font f,moveto(Pt(n x,n 2)),text label,stroke,loop(index+1)rest]end
   in loop 0 entries end
 fun configuration pes selected=
   let val master=hd pes val workers=tl pes
       val used=if List.null selected then List.map #1 workers else selected
       val _=if List.all(fn p=>List.exists(fn(q,_)=>p=q)workers)used then()
         else raise Fail "attempt to gather inactive GRIP processor"
       fun row(p,label)=(if List.exists(fn q=>q=p)used then"SMALLBOLD"else"SMALL",label)
   in concat[font"LARGE",moveto(Pt(n 10,n 16)),centre(Int.toString(List.length used)),
     font"SMALL",moveto(Pt(n 10,n 12)),centre"PE(s)",stroke,
     font"SMALL",moveto(Pt(n 10,n 8)),centre"displayed",stroke,font"NORM",
     moveto(Pt(n 2,n 2)),font"SMALL",text"Configuration:",
     processorText(("SMALLITALIC",#2 master)::List.map row workers),stroke,font"NORM"]end
 fun initGraph title pes selected topX topY xlabel ylabel legend=concat[
   drawBox(Pt(n 0,n 0))paperX paperY,drawBox(Pt(n 1,n 1))(paperX-2)5,
   drawBox(Pt(n 1,n(paperY-7)))(paperX-2)6,font"BOLD",
   moveto(Pt(n(I.div(paperX,2)),n(paperY-6))),centre title,font"NORM",
   delay(fn()=>configuration(L.force pes)selected),translate 20 25,newpath,moveto(Pt(n 0,n(~5))),
   lineto(Pt(n 0,n dimY)),moveto(Pt(n(~5),n 0)),lineto(Pt(n dimX,n 0)),stroke,font"SMALL",
   delay(fn()=>markXAxis(value topX)),delay(fn()=>markYAxis(value topY)),moveto(Pt(n 0,n(dimY+4))),right ylabel,stroke,
   moveto(Pt(n dimX,n(~8))),right xlabel,stroke,font"NORM",delay(fn()=>keys(L.force legend))]
end
