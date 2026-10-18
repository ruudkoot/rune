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
