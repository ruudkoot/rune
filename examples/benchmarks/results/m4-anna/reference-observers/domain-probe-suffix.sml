 fun one(domain,values)=
   let fun pairs f=let fun outer values=case D.force values of K.F.Nil=>[]
          |K.F.Cons(x,rest)=>let fun inner ys=case D.force ys of K.F.Nil=>[]
              |K.F.Cons(y,rest)=>f x y::inner rest
            in inner values@outer rest end
         fun outerFrom xs=case D.force xs of K.F.Nil=>[]
          |K.F.Cons(x,rest)=>let fun inner ys=case D.force ys of K.F.Nil=>[]
               |K.F.Cons(y,rest)=>f x y::inner rest
            in inner values@outerFrom rest end
       in list(fn x=>x)(outerFrom values)end
   in check"routes"(seq route(K.allRoutes domain));
      check"bounds"(pair(route(K.topRoute domain))(route(K.bottomRoute domain)));
      check"predicates"(seq(fn r=>pair(boolean(K.isTopRoute r))(boolean(K.isBottomRoute r)))values);
      check"below"(pairs(fn x=>fn y=>boolean(K.belowRoute x y)));
      check"join"(pairs(fn x=>fn y=>route(K.joinRoute x y)));
      check"meet"(pairs(fn x=>fn y=>route(K.meetRoute x y)));
      check"successors"(seq(fn r=>seq route(K.successors domain r))values);
      check"predecessors"(seq(fn r=>seq route(K.predecessors domain r))values);
      index:= !index+1 end
 val _=List.app one cases
 val _=TextIO.closeIn source
end
structure Need=DomainTests(structure D=BenchNeed val label="lazy")
structure Strict=DomainTests(structure D=BenchStrict val label="strict")
