 fun makeFrontier arity ones zeros=cell(Min1Max0(arity,ones,zeros))
 fun uncurryDomain arguments domain=D.delay(fn()=>case force domain of
   Func(more,result)=>Func(F.append arguments more,result)|_=>Func(arguments,domain))
 fun topRoute domain:route=D.delay(fn()=>case force domain of
    Two=>One|Lift1 ds=>Up1(map topRoute ds)|Lift2 ds=>UpUp2(map topRoute ds)
   |Func _=>Rep(topRepresentation domain))
 and topFrontier arguments=makeFrontier(length arguments)
     (singleton(cell(MkFrel(map bottomRoute arguments))))(F.empty())
 and topRepresentation domain:representation=D.delay(fn()=>case force domain of
    Func(arguments,result)=>(case force result of
      Two=>RepTwo(topFrontier arguments)
     |Lift1 ds=>let val low=topFrontier arguments
        in Rep1(low,map topRepresentation(map(uncurryDomain arguments)ds))end
     |Lift2 ds=>let val low=topFrontier arguments
        in Rep2(low,low,map topRepresentation(map(uncurryDomain arguments)ds))end
     |_=>raise Match)|_=>raise Match)
 and bottomRoute domain:route=D.delay(fn()=>case force domain of
    Two=>Zero|Lift1 _=>Stop1|Lift2 _=>Stop2|Func _=>Rep(bottomRepresentation domain))
 and bottomFrontier arguments=makeFrontier(length arguments)(F.empty())
     (singleton(cell(MkFrel(map topRoute arguments))))
 and bottomRepresentation domain:representation=D.delay(fn()=>case force domain of
    Func(arguments,result)=>(case force result of Two=>RepTwo(bottomFrontier arguments)
     |Lift1 ds=>let val low=bottomFrontier arguments
        in Rep1(low,map bottomRepresentation(map(uncurryDomain arguments)ds))end
     |Lift2 ds=>let val low=bottomFrontier arguments
        in Rep2(low,low,map bottomRepresentation(map(uncurryDomain arguments)ds))end
     |_=>raise Match)|_=>raise Match)
 fun isBottomRoute route=case force route of Zero=>true|Stop1=>true|Stop2=>true
   |One=>false|Up1 _=>false|Up2=>false|UpUp2 _=>false|Rep rep=>isBottomRepresentation rep
 and isBottomRepresentation rep=
   let val low=case force rep of RepTwo low=>low|Rep1(low,_)=>low|Rep2(low,_,_)=>low
       val Min1Max0(_,ones,_)=force low
   in null ones end
 fun isTopRoute route=case force route of Zero=>false|One=>true|Stop1=>false
   |Up1 rs=>all isTopRoute rs|Stop2=>false|Up2=>false|UpUp2 rs=>all isTopRoute rs
   |Rep rep=>isTopRepresentation rep
 and isTopRepresentation rep=case force rep of
    RepTwo f=>let val Min1Max0(_,_,zeros)=force f in null zeros end
   |Rep1(_,highs)=>all isTopRepresentation highs|Rep2(_,_,highs)=>all isTopRepresentation highs
