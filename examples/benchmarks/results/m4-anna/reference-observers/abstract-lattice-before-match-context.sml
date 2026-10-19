 fun joinRoute left right:route=D.delay(fn()=>case force left of
    Zero=>force right|One=>force left|Stop1=>force right|Stop2=>force right
   |Up1 xs=>(case force right of Stop1=>force left|Up1 ys=>Up1(zipExact joinRoute xs ys)|_=>raise Match)
   |Up2=>(case force right of Stop2=>force left|_=>force right)
   |UpUp2 xs=>(case force right of UpUp2 ys=>UpUp2(zipExact joinRoute xs ys)|_=>force left)
   |Rep x=>(case force right of Rep y=>Rep(joinRepresentation x y)|_=>raise Match))
 and joinFrel left right:frontierElem=D.delay(fn()=>
   let val MkFrel xs=force left val MkFrel ys=force right in MkFrel(zipExact joinRoute xs ys)end)
 and joinFrontier left right:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force left val Min1Max0(_,otherOnes,otherZeros)=force right
       val minimum=insertionSort compareFrel(foldRight(minimumAdd belowFrel)ones otherOnes)
       val products=flatMap(fn x=>map(meetFrel x)otherZeros)zeros
       val maximum=insertionSort compareFrel(maximal belowFrel products)
   in Min1Max0(arity,minimum,maximum)end)
 and joinRepresentation left right:representation=D.delay(fn()=>case(force left,force right)of
    (RepTwo x,RepTwo y)=>RepTwo(joinFrontier x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(joinFrontier x y,zipExact joinRepresentation xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(joinFrontier x y,joinFrontier z w,zipExact joinRepresentation xs ys)
   |_=>raise Match)
 and meetRoute left right:route=D.delay(fn()=>case force left of
    Zero=>force left|One=>force right|Stop1=>force left|Stop2=>force left
   |Up1 xs=>(case force right of Up1 ys=>Up1(zipExact meetRoute xs ys)|_=>force right)
   |Up2=>(case force right of Stop2=>force right|_=>force left)
   |UpUp2 xs=>(case force right of UpUp2 ys=>UpUp2(zipExact meetRoute xs ys)|_=>force right)
   |Rep x=>(case force right of Rep y=>Rep(meetRepresentation x y)|_=>raise Match))
 and meetFrel left right:frontierElem=D.delay(fn()=>
   let val MkFrel xs=force left val MkFrel ys=force right in MkFrel(zipExact meetRoute xs ys)end)
 and meetFrontier left right:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force left val Min1Max0(_,otherOnes,otherZeros)=force right
       val maximum=insertionSort compareFrel(foldRight(maximumAdd belowFrel)zeros otherZeros)
       val products=flatMap(fn x=>map(joinFrel x)otherOnes)ones
       val minimum=insertionSort compareFrel(minimal belowFrel products)
   in Min1Max0(arity,minimum,maximum)end)
 and meetRepresentation left right:representation=D.delay(fn()=>case(force left,force right)of
    (RepTwo x,RepTwo y)=>RepTwo(meetFrontier x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(meetFrontier x y,zipExact meetRepresentation xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(meetFrontier x y,meetFrontier z w,zipExact meetRepresentation xs ys)
   |_=>raise Match)
