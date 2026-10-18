 fun list_of_common_atoms n=F.defer(fn()=>
   let val Nuc(_,_,_,_,p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,_)=D.force n
   in List.foldr(fn(p,rest)=>F.cons(p,rest))(F.empty())
      [p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24]end)
 fun list_of_specific_atoms n=F.defer(fn()=>
   let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,specific)=D.force n
       val values=case D.force specific of A(a,b,c,d,e,f,g,h)=>[a,b,c,d,e,f,g,h]
         |C(a,b,c,d,e,f)=>[a,b,c,d,e,f]
         |G(a,b,c,d,e,f,g,h,i)=>[a,b,c,d,e,f,g,h,i]|U(a,b,c,d,e)=>[a,b,c,d,e]
   in List.foldr(fn(p,rest)=>F.cons(p,rest))(F.empty())values end)
 fun list_of_atoms n=F.append(list_of_common_atoms n)(list_of_specific_atoms n)
 fun mapCells f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>F.cons(D.delay(fn()=>D.force(f value)),mapCells f rest))
 (* GHC 9.4.7 GHC.List.maximum uses foldl1', not a delayed left fold. *)
 fun maximum(values:real F.seq)=D.delay(fn()=>
   let fun loop accumulator values=case D.force values of F.Nil=>D.force accumulator
         |F.Cons(value,rest)=>
           let val a=D.force accumulator val b=D.force value
               val next=if a<=b then b else a
           in loop(D.delay(fn()=>next))rest end
   in case D.force values of F.Nil=>raise Fail"Prelude.maximum: empty list"
      |F.Cons(value,rest)=>loop value rest end)
 fun var_most_distant_atom v=D.delay(fn()=>
   let val Var(_,_,n)=D.force v
       fun distance p=D.delay(fn()=>
          let val Pt(x,y,z)=D.force(absolute_pos v p)
          in R.sqrt(R.add(R.add(R.mul(real x,real x),R.mul(real y,real y)),R.mul(real z,real z)))end)
   in D.force(maximum(mapCells distance(list_of_atoms n)))end)
 fun sol_most_distant_atom solution=maximum(mapCells var_most_distant_atom solution)
 fun most_distant_atom solutions=maximum(mapCells sol_most_distant_atom solutions)
 (* The measured source consumes only the maximum, without keeping a root
  * for a second traversal of the solution stream. *)
 fun compute input=D.force(most_distant_atom(pseudoknot input))
