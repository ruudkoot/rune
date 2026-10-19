(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained. *)
structure BenchMiniSpatial=
struct
 structure V=BenchMiniVector
 structure T=BenchMiniTriangle
 datatype tree=Empty|Node of{bound:RealArray.array,parts:parts}
 and parts=Cells of tree array|Items of T.t array
 val maxLevels=44
 fun bit value i=Word.toInt(Word.andb(Word.>>(Word.fromInt value,Word.fromInt i),0w1))
 fun flip value i=Word.toInt(Word.xorb(Word.fromInt value,Word.<<(0w1,Word.fromInt i)))
 fun construct bound items level=
   if List.length items>8 andalso level<maxLevels-1 then
     let val copied=ref 0
         fun subcell index=
           let val subBound=RealArray.tabulate(6,fn i=>
                 let val m=i mod 3
                 in if bit index m<>i div 3 then
                    (RealArray.sub(bound,m)+RealArray.sub(bound,m+3))*0.5 else RealArray.sub(bound,i)end)
               fun overlaps item=
                 let val bounds=T.bounds item
                     fun loop j all=if j=6 then all=1
                       else let val d=j div 3 val m=j mod 3
                                val comparison=if V.sub(Array.sub(bounds,1-d))m>=RealArray.sub(subBound,j)then 1 else 0
                                val keep=if d=0 then comparison else 1-comparison
                            in loop(j+1)(Word.toInt(Word.andb(Word.fromInt all,Word.fromInt keep)))end
                 in loop 0 1 end
               val subItems=List.filter overlaps items
               val _=copied:= !copied+(if List.length subItems=List.length items then 1 else 0)
               val small=RealArray.sub(subBound,3)-RealArray.sub(subBound,0)<T.tolerance*4.0
           in if List.length subItems>0 then
                construct subBound subItems(if !copied>1 orelse small then maxLevels else level+1)
              else Empty end
         val cells=Array.tabulate(8,subcell)
     in Node{bound=bound,parts=Cells cells}end
   else Node{bound=bound,parts=Items(Array.fromList items)}
 fun create eye items=
   let fun encompass(item,(low,high))=
         let val bounds=T.bounds item
             val high=V.zip(fn a=>fn b=>Real.max(a,b))high(Array.sub(bounds,1))
             val low=V.zip(fn a=>fn b=>Real.min(a,b))low(Array.sub(bounds,0))
         in(low,high)end
       val(low,high)=List.foldl encompass(eye,eye)items
       val size=V.fold(fn a=>fn b=>Real.max(a,b))(V.subtract high low)
       val high=V.zip(fn a=>fn b=>Real.max(a,b))high(V.add low(V.scale V.one size))
       val bound=RealArray.tabulate(6,fn i=>if i<3 then V.sub low i else V.sub high(i-3))
   in construct bound items 0 end
 fun intersection tree origin direction lastHit=
   let fun query Empty start=NONE
         |query(Node{bound,parts=Cells cells})start=
           let fun cellBit i=if V.sub start i>=(RealArray.sub(bound,i)+RealArray.sub(bound,i+3))*0.5
                             then(if i=0 then 1 else if i=1 then 2 else 4)else 0
               val initial=cellBit 0+cellBit 1+cellBit 2
               fun walk cell position=
                 case query(Array.sub(cells,cell))position of SOME hit=>SOME hit
                  |NONE=>
                     let fun next i step axis=if i=3 then(step,axis)
                           else let val high=bit cell i
                                    val negative=if V.sub direction i<0.0 then 1 else 0
                                    val face=if negative<>high then RealArray.sub(bound,i+high*3)
                                      else(RealArray.sub(bound,i)+RealArray.sub(bound,i+3))*0.5
                                    val distance=(face-V.sub origin i)/V.sub direction i
                                in if distance<=step then next(i+1)distance i else next(i+1)step axis end
                         val(step,axis)=next 0 Real.maxFinite 0
                         val negative=if V.sub direction axis<0.0 then 1 else 0
                     in if negative<>bit cell axis then NONE
                        else walk(flip cell axis)(V.add origin(V.scale direction step))end
           in walk initial start end
         |query(Node{bound,parts=Items items})start=
           let fun nearest(item,best as(previous,position,distance))=
                 if(case lastHit of NONE=>false|SOME last=>T.same(last,item))then best
                 else case T.intersection item origin direction of
                   NONE=>best
                  |SOME d=>if not(d<distance)then best else
                    let val hit=V.add origin(V.scale direction d)
                        val tol=T.tolerance
                        val outside=RealArray.sub(bound,0)-V.sub hit 0>tol orelse V.sub hit 0-RealArray.sub(bound,3)>tol orelse
                          RealArray.sub(bound,1)-V.sub hit 1>tol orelse V.sub hit 1-RealArray.sub(bound,4)>tol orelse
                          RealArray.sub(bound,2)-V.sub hit 2>tol orelse V.sub hit 2-RealArray.sub(bound,5)>tol
                    in if outside then best else(SOME item,hit,d)end
               val(item,position,_)=Array.foldl nearest(NONE,V.zero,Real.posInf)items
           in case item of NONE=>NONE|SOME item=>SOME(item,position)end
   in query tree origin end
end
