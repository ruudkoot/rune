(* Reachable connected-component kernel of nofib Hartel comp_lab_zift.
 * Preserve labelled persistent trees and the source sifting operation. *)
functor BenchCompLabFn(D:BENCH_SUSPEND)=
struct
 structure F=BenchIdaFiniteFn(D)
 structure L=BenchLazy
 fun view xs=case D.force xs of F.Nil=>NONE|F.Cons(x,rest)=>SOME(x,rest)
 fun null xs=case D.force xs of F.Nil=>true|_=>false
 fun singleton x=F.cons(D.delay(fn()=>x),F.empty())
 fun split n xs=L.delay(fn()=>if n=0 then(F.empty(),xs)
   else case view xs of NONE=>raise Fail"split past input"
    |SOME(x,rest)=>
      let val pair=split(n-1)rest
      in(F.cons(x,F.defer(fn()=> #1(L.force pair))),F.defer(fn()=> #2(L.force pair)))end)
 fun left (pair:('a F.seq*'a F.seq)L.delay)=F.defer(fn()=> #1(L.force pair))
 fun right (pair:('a F.seq*'a F.seq)L.delay)=F.defer(fn()=> #2(L.force pair))
 fun concat xss=D.delay(fn()=>case view xss of NONE=>F.Nil
   |SOME(xs,rest)=>D.force(F.append(D.force xs)(concat rest)))
 fun repeat 0 xs=F.empty()
   |repeat n xs=F.defer(fn()=>F.append xs(repeat(n-1)xs))
 fun merge (xs:int F.seq)(ys:int F.seq)=D.delay(fn()=>case(view xs,view ys)of
    (NONE,_)=>D.force ys|(_,NONE)=>D.force xs
   |(SOME(x,xs'),SOME(y,ys'))=>
      if D.force x<=D.force y then F.Cons(x,merge xs' ys)else F.Cons(y,merge xs ys'))
 datatype treeNode=Leaf of int D.t|Tree of int D.t*treeNode D.t*treeNode D.t
 type tree=treeNode D.t
 datatype setNode=Empty|Set of int D.t*tree
 type object=setNode D.t
 fun empty()=D.delay(fn()=>Empty)
 fun singletonSet label=D.delay(fn()=>Set(label,D.delay(fn()=>Leaf label)))
 fun top set=case D.force set of Set(label,_)=>D.force label|_=>raise Fail"empty object top"
 fun setEqual a b=case(D.force a,D.force b)of(Empty,Empty)=>true|(Set(x,_),Set(y,_))=>D.force x=D.force y|_=>false
 fun member tree label=case D.force tree of Leaf key=>label=D.force key
   |Tree(key,a,b)=>if label>D.force key then member b label else member a label
 fun setMember set label=case D.force set of Set(_,tree)=>member tree label|_=>raise Fail"empty object membership"
 fun treeMax tree=case D.force tree of Leaf key=>D.force key|Tree(_,_,right)=>treeMax right
 fun treeMin tree=case D.force tree of Leaf key=>D.force key|Tree(_,left,_)=>treeMin left
 fun flatten tree=F.defer(fn()=>case D.force tree of Leaf key=>F.cons(key,F.empty())
   |Tree(_,a,b)=>F.append(flatten a)(flatten b))
 fun makeTree n xs=D.delay(fn()=>case view xs of
     NONE=>raise Fail"makeTree empty"
    |SOME(x,rest)=>if null rest then(x,D.delay(fn()=>Leaf x))
       else let val half=n div 2 val parts=split half xs
                val first=makeTree half(left parts)
                val last=makeTree(n-half)(right parts)
                val maxLeft=D.delay(fn()=>D.force(#1(D.force first)))
                val leftTree=D.delay(fn()=>D.force(#2(D.force first)))
                val maxRight=D.delay(fn()=>D.force(#1(D.force last)))
                val rightTree=D.delay(fn()=>D.force(#2(D.force last)))
            in(maxRight,D.delay(fn()=>Tree(maxLeft,leftTree,rightTree)))end)
 fun treeUnion a b=D.delay(fn()=>
   let val maxLeft=treeMax a
   in if maxLeft<treeMin b then Tree(D.delay(fn()=>maxLeft),a,b)
      else let val values=merge(flatten a)(flatten b)
               val result=makeTree(F.length values)values
           in D.force(#2(D.force result))end end)
 fun unionSet a b=D.delay(fn()=>case(D.force a,D.force b)of
   (Set(label,first),Set(_,last))=>Set(label,treeUnion first last)
   |_=>raise Fail"empty object union")
 fun selectTree minimum upper tree=
   let fun select tree=D.delay(fn()=>case D.force tree of Leaf key=>(key,D.delay(fn()=>Leaf key))
         |Tree(key,a,b)=>
           if minimum>D.force key then D.force(select b)
           else if upper<=treeMin b then D.force(select a)
           else let val first=select a val last=select b
                    val maxLeft=D.delay(fn()=>D.force(#1(D.force first)))
                    val maxRight=D.delay(fn()=>D.force(#1(D.force last)))
                    val leftTree=D.delay(fn()=>D.force(#2(D.force first)))
                    val rightTree=D.delay(fn()=>D.force(#2(D.force last)))
                in(maxRight,D.delay(fn()=>Tree(maxLeft,leftTree,rightTree)))end)
   in D.delay(fn()=>D.force(#2(D.force(select tree))))end
 fun selectSet minimum upper set=D.delay(fn()=>case D.force set of
   Set(label,tree)=>Set(label,selectTree minimum upper tree)|_=>raise Fail"select empty object")
 fun extract set objects=D.delay(fn()=>case view objects of NONE=>F.Nil
   |SOME(head,rest)=>if setEqual set(D.force head)then D.force rest else F.Cons(head,extract set rest))
 fun extract2 a b objects=D.delay(fn()=>case view objects of NONE=>F.Nil
   |SOME(head,rest)=>
      if setEqual a(D.force head)then D.force(extract b rest)
      else if setEqual b(D.force head)then D.force(extract a rest)
      else F.Cons(head,extract2 a b rest))
 fun find objects label=
   if label= ~1 then empty()
   else let fun lookup objects=case view objects of NONE=>empty()
              |SOME(head,rest)=>if setMember(D.force head)label then D.force head else lookup rest
        in lookup objects end
 fun unionObjects objects a b=
   if setEqual a b then objects else F.cons(D.delay(fn()=>unionSet a b),extract2 a b objects)
 datatype genNode=Gen of int*int*int
 type gen=genNode L.delay
 fun generator width row col=L.delay(fn()=>Gen(width,row,col))
 fun splitBuy gen rows=L.delay(fn()=>
   let val Gen(width,row,col)=L.force gen
   in(generator width row col,generator width(row+rows)col)end)
 fun createLabel gen=D.delay(fn()=>
   let val Gen(width,row,col)=L.force gen
   in(D.delay(fn()=>width*row+col),generator width row(col+1))end)
 fun sift gen rows objects=F.defer(fn()=>
   let val Gen(width,row,_)=L.force gen
   in F.map(selectSet(row*width)((row+rows)*width))objects end)
 fun noSift _ _ objects=objects
 datatype range=Range of int D.t*int D.t
 datatype lenRow=LenRow of int D.t*range F.seq
 datatype labRange=LabRange of int D.t*range D.t
 datatype labRow=LabRow of labRange F.seq*object F.seq
 datatype lenLab=LenLab of int D.t*labRange F.seq
 datatype fieldNode=Field of labRange F.seq*labRange F.seq*object F.seq*lenLab F.seq
 type field=fieldNode D.t
 fun rowLength(LenRow(n,_))=D.force n
 fun labelsLength(LenLab(n,_))=D.force n
 fun ranges(LenRow(_,ranges))=ranges
 fun findWhite pixels count=L.delay(fn()=>case view pixels of NONE=>(count,F.empty())
   |SOME(pixel,rest)=>if D.force pixel then L.force(findWhite rest(count+1))else(count,rest))
 fun findBlack pixels count=D.delay(fn()=>case view pixels of NONE=>F.Nil
   |SOME(pixel,rest)=>
      if not(D.force pixel)then D.force(findBlack rest(count+1))
      else let val after=findWhite rest(count+1)
               val finish=D.delay(fn()=> #1(L.force after))
               val range=D.delay(fn()=>Range(D.delay(fn()=>count),finish))
               val next=F.defer(fn()=>findBlack(#2(L.force after))(D.force finish+1))
           in F.Cons(range,next)end)
 fun pixelsToRanges pixels=
   let val result=findBlack pixels 0
   in LenRow(D.delay(fn()=>F.length result),result)end
 fun assignRow ranges gen=D.delay(fn()=>case view ranges of NONE=>LabRow(F.empty(),F.empty())
   |SOME(range,rest)=>
      let val next=createLabel gen
          val label=D.delay(fn()=>D.force(#1(D.force next)))
          val generator=L.delay(fn()=>L.force(#2(D.force next)))
          val following=assignRow rest generator
          val labels=F.cons(D.delay(fn()=>LabRange(label,range)),F.defer(fn()=>case D.force following of LabRow(xs,_)=>xs))
          val objects=F.cons(D.delay(fn()=>singletonSet label),F.defer(fn()=>case D.force following of LabRow(_,xs)=>xs))
      in LabRow(labels,objects)end)
 fun labelOf(LabRange(label,_))=D.force label
 fun rangeOf(LabRange(_,range))=D.force range
 fun apLabel objects(LabRange(label,range))=
   let val found=find objects(D.force label)
       val result=D.delay(fn()=>if setEqual found(empty())then ~1 else top found)
   in LabRange(result,range)end
 fun unionBorder first last objects=
   case(view first,view last)of(NONE,_)=>objects|(_,NONE)=>objects
    |(SOME(l,left),SOME(r,right))=>
      let val lr=D.force l val rr=D.force r
          val Range(lb,lw)=rangeOf lr val Range(rb,rw)=rangeOf rr
      in if D.force lw<=D.force rb then unionBorder left last objects
         else if D.force rw<=D.force lb then unionBorder first right objects
         else let val united=unionObjects objects(find objects(labelOf lr))(find objects(labelOf rr))
              in if D.force rw<=D.force lw then unionBorder first right united
                 else unionBorder left last united end end
 fun unionFields first last=D.delay(fn()=>case(D.force first,D.force last)of
   (Field(ll,lr,lo,lp),Field(rl,rr,ro,rp))=>
    let val incoming=if null lr then ll else lr
        val outgoing=if null rr then rl else rr
        val objects=unionBorder incoming rl(F.append lo ro)
    in Field(F.map(apLabel objects)ll,F.map(apLabel objects)outgoing,objects,F.append lp rp)end)
 fun fieldLeft field=case D.force field of Field(x,_,_,_)=>x
 fun fieldRight field=case D.force field of Field(_,x,_,_)=>x
 fun fieldObjects field=case D.force field of Field(_,_,x,_)=>x
 fun fieldLabels field=case D.force field of Field(_,_,_,x)=>x
 fun pixelFieldSeq pixels count gen=D.delay(fn()=>case view pixels of NONE=>raise Fail"empty pixel field"
   |SOME(row,rest)=>
      if null rest then
        let val LenRow(n,ranges)=D.force row val assigned=assignRow ranges gen
            val labels=F.defer(fn()=>case D.force assigned of LabRow(xs,_)=>xs)
            val objects=F.defer(fn()=>case D.force assigned of LabRow(_,xs)=>xs)
        in Field(labels,F.empty(),objects,singleton(LenLab(n,labels)))end
      else let val half=count div 2 val rows=split half pixels val buys=splitBuy gen half
               val first=pixelFieldSeq(left rows)half(L.delay(fn()=>L.force(#1(L.force buys))))
               val last=pixelFieldSeq(right rows)(count-half)(L.delay(fn()=>L.force(#2(L.force buys))))
           in D.force(unionFields first last)end)
 fun sumMapped f values=
   let val mapped=F.map f values
       fun loop total values=case view values of NONE=>total
         |SOME(value,rest)=>loop(D.delay(fn()=>D.force total+D.force value))rest
   in D.force(loop(D.delay(fn()=>0))mapped)end
 fun sumRows rows=sumMapped rowLength rows
 datatype 'a sandArg=SandArg of 'a*int L.delay
 fun sandwich f(SandArg(first,_))(SandArg(last,_))=f first last
 fun pixelField pixels count gen threshold=D.delay(fn()=>case view pixels of NONE=>raise Fail"empty pixel field"
   |SOME(_,rest)=>if null rest then D.force(pixelFieldSeq pixels count gen)
      else let val half=count div 2 val rows=split half pixels
               val first=left rows val last=right rows
               val leftSum=sumRows first val rightSum=sumRows last
               val buys=splitBuy gen half
               val leftGen=L.delay(fn()=>L.force(#1(L.force buys)))
               val rightGen=L.delay(fn()=>L.force(#2(L.force buys)))
           in if leftSum>threshold andalso rightSum>threshold then
                D.force(sandwich unionFields(SandArg(pixelField first half leftGen threshold,L.delay(fn()=>2*leftSum)))(SandArg(pixelField last(count-half)rightGen threshold,L.delay(fn()=>2*rightSum))))
              else if rightSum>threshold then D.force(unionFields(pixelFieldSeq first half leftGen)(pixelField last(count-half)rightGen threshold))
              else if leftSum>threshold then D.force(unionFields(pixelField first half leftGen threshold)(pixelFieldSeq last(count-half)rightGen))
              else D.force(pixelFieldSeq pixels count gen)end)
 fun mapLabelSeq labels objects=F.map(fn LenLab(_,ranges)=>F.map(apLabel objects)ranges)labels
 fun sumLabels rows=sumMapped labelsLength rows
 fun mapLabel sift labels count gen objects threshold=F.defer(fn()=>case view labels of NONE=>raise Fail"empty label field"
   |SOME(row,rest)=>if null rest then case D.force row of LenLab(_,ranges)=>singleton(F.map(apLabel objects)ranges)
      else let val half=count div 2 val rows=split half labels val buys=splitBuy gen half
               val first=left rows val last=right rows
               val leftSum=sumLabels first val rightSum=sumLabels last
               fun recursiveLeft()=mapLabel sift first half(L.delay(fn()=>L.force(#1(L.force buys))))
                    (sift(L.delay(fn()=>L.force(#1(L.force buys))))half objects)threshold
               fun recursiveRight()=mapLabel sift last(count-half)(L.delay(fn()=>L.force(#2(L.force buys))))
                    (sift(L.delay(fn()=>L.force(#2(L.force buys))))(count-half)objects)threshold
           in if leftSum>threshold andalso rightSum>threshold then sandwich F.append(SandArg(recursiveLeft(),L.delay(fn()=>2*leftSum-1)))(SandArg(recursiveRight(),L.delay(fn()=>2*rightSum-1)))
              else if leftSum>threshold then F.append(recursiveLeft())(mapLabelSeq last objects)
              else if rightSum>threshold then F.append(mapLabelSeq first objects)(recursiveRight())
              else mapLabelSeq labels objects end)
 fun decimal n=let val text=Int.toString n in if String.isPrefix"~"text then"-"^String.extract(text,1,NONE)else text end
 fun toPixels width start ranges=F.defer(fn()=>case view ranges of NONE=>
      if start>=width then F.empty()else repeat(width-start)(singleton(~1))
   |SOME(value,rest)=>
      let val LabRange(label,range)=D.force value
          val Range(begin,finish)=D.force range
          val b=D.force begin val w=D.force finish
          val whites=if b<=start then F.empty()else repeat(b-start)(singleton(~1))
          val blacks=if w<=b then F.empty()else repeat(w-b)(F.cons(label,F.empty()))
      in F.append whites(F.append blacks(toPixels width w rest))end)
 fun showTree tree=case D.force tree of Leaf key=>"["^decimal(D.force key)^"()]"
   |Tree(key,a,b)=>"["^decimal(D.force key)^showTree a^showTree b^"]"
 fun showSet set=case D.force set of Empty=>"()"
   |Set(label,tree)=>case D.force tree of Leaf key=>"{"^decimal(D.force label)^" "^decimal(D.force key)^"}"
      |Tree(key,a,b)=>"{"^decimal(D.force label)^" "^decimal(D.force key)^" "^showTree a^" "^showTree b^"}"
 fun showRange(Range(a,b))="["^decimal(D.force a)^":"^decimal(D.force b)^"]"
 fun showLabRange(LabRange(label,range))=decimal(D.force label)^showRange(D.force range)
 fun showLenLab(LenLab(n,ranges))="{"^decimal(D.force n)^" | "^String.concat(List.map(fn range=>" "^showLabRange range)(F.toList ranges))^"}"
 val figures=Vector.map(fn rows=>L.delay(fn()=>F.fromList(List.map(fn row=>F.map(fn c=>c= #"B")(F.fromList(String.explode row)))rows)))BenchCompLabData.figures
 fun figure selector=L.force(Vector.sub(figures,selector))
 fun tile n image=repeat n(F.map(fn row=>repeat n row)image)
 fun components useSift selector n threshold=D.delay(fn()=>
   let val image=tile n(figure selector)
       val width=F.length(F.nth image 0)
       val pixels=F.map pixelsToRanges image
       val count=F.length pixels
       val gen=generator width 0 0
       val field=pixelField pixels count gen threshold
       val objects=F.defer(fn()=>fieldObjects field)
       val raw=F.defer(fn()=>fieldLabels field)
       val labels=mapLabel(if useSift then sift else noSift)raw count gen objects threshold
   in(labels,raw,objects,width)end)
 fun rendered useSift selector n threshold=
   let val result=components useSift selector n threshold
       val(labels,raw,objects,width)=D.force result
       val matrix=F.map(toPixels width 0)labels
       val image=String.concat(List.map(fn row=>"\n"^String.concat(List.map(fn n=>" "^decimal n)(F.toList row)))(F.toList matrix))
       val ranges=String.concat(List.map(fn row=>"\n"^showLenLab row)(F.toList raw))
       val sets=String.concat(List.map(fn set=>"\n"^showSet set)(F.toList objects))
   in"\ncomponent image:"^image^"\n\nlab-ranges:"^ranges^"\n\nobject-sets:"^sets^"\n\n"end
 fun sumcode text=
   let val size=String.size text val sum=List.foldl(fn(c,n)=>Char.ord c+n)0(String.explode text)
   in decimal(sum+size)^"/"^decimal size end
end
