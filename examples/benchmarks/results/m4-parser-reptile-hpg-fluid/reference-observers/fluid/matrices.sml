 val massRowSums=A.defListArray eq(1,6)(divide(number 12.0)(number 180.0))
   (F.fromList[force(divide(number 12.0)(number 180.0)),force(divide(number 12.0)(number 180.0)),
     force(divide(number 12.0)(number 180.0)),force(divide(number 68.0)(number 180.0)),
     force(divide(number 68.0)(number 180.0)),force(divide(number 68.0)(number 180.0))])
 val massMatrix=let val inverse=divide one(number 180.0)
     val rows=[[6,~1,~1,~4,0,0],[~1,6,~1,0,~4,0],[~1,~1,6,0,0,~4],
       [~4,0,0,32,16,16],[0,~4,0,16,32,16],[0,0,~4,16,16,32]]
   in A.listArray(1,6)(F.fromList(List.map(fn row=>
     map(mult inverse)(F.fromList(List.map Real.fromInt row)))rows))end
 fun components((a,b,c),(x,y,z))=(a,b,c,x,y,z)
 fun ff1 x y u v=add(mul x y)(mul u v)
 fun ff2 x y u v=let fun part x y=add(mul x(add x y))(mul y y)
   in add(part x y)(part u v)end
 fun ff3 x y z u v w=let fun part x y z=add(mul x y)(mul(add x z)(add y z))
   in add(part x y z)(part u v w)end
 fun f0 _=zero
 fun f11((x,_,_),(y,_,_))=mul(number 3.0)(ff1 x x y y)
 fun f12((x,y,_),(u,v,_))=negative(ff1 x y u v)
 fun f13((x,_,z),(u,_,w))=negative(ff1 x z u w)
 fun f15 value=mul(number(~4.0))(f13 value)
 fun f16 value=mul(number(~4.0))(f12 value)
 fun f22((_,x,_),(_,y,_))=mul(number 3.0)(ff1 x x y y)
 fun f23((_,y,z),(_,v,w))=negative(ff1 y z v w)
 fun f24 value=mul(number(~4.0))(f23 value)
 fun f33((_,_,x),(_,_,y))=mul(number 3.0)(ff1 x x y y)
 fun f44((_,y,z),(_,v,w))=mul(number 8.0)(ff2 y z v w)
 fun f45((x,y,z),(u,v,w))=mul(number 4.0)(ff3 x y z u v w)
 fun f46((x,y,z),(u,v,w))=mul(number 4.0)(ff3 x z y u w v)
 fun f55((x,_,z),(u,_,w))=mul(number 8.0)(ff2 x z u w)
 fun f56((x,y,z),(u,v,w))=mul(number 4.0)(ff3 y z x v w u)
 fun f66((x,y,_),(u,v,_))=mul(number 8.0)(ff2 x y u v)
 val diffusionMatrix=
   let val rows=[[f11,f12,f13,f0,f15,f16],[f12,f22,f23,f24,f0,f16],
      [f13,f23,f33,f24,f15,f0],[f0,f24,f24,f44,f45,f46],
      [f15,f0,f15,f45,f55,f56],[f16,f16,f0,f46,f56,f66]]
   in A.listArray(1,6)(F.fromList(List.map(fn row=>fn factors=>
     map(fn f=>force f factors)(F.fromList row))rows))end
 val gradientMatrix=
   let fun row1(a,b,c)=F.cons(a,F.cons(zero,F.cons(zero,F.empty())))
       fun row2(a,b,c)=F.cons(zero,F.cons(b,F.cons(zero,F.empty())))
       fun row3(a,b,c)=F.cons(zero,F.cons(zero,F.cons(c,F.empty())))
       fun row4(a,b,c)=F.cons(add b c,F.cons(add(add b c)c,F.cons(add(add c b)b,F.empty())))
       fun row5(a,b,c)=F.cons(add(add a c)c,F.cons(add a c,F.cons(add(add c a)a,F.empty())))
       fun row6(a,b,c)=F.cons(add(add a b)b,F.cons(add(add a a)b,F.cons(add a b,F.empty())))
   in A.listArray(1,6)(F.fromList[row1,row2,row3,row4,row5,row6])end
 val transposedGradient=
   let fun row1(a,b,c)=F.cons(a,F.cons(zero,F.cons(zero,F.cons(add b c,F.cons(add(add a c)c,F.cons(add(add a b)b,F.empty()))))))
       fun row2(a,b,c)=F.cons(zero,F.cons(b,F.cons(zero,F.cons(add(add b c)c,F.cons(add a c,F.cons(add(add a a)b,F.empty()))))))
       fun row3(a,b,c)=F.cons(zero,F.cons(zero,F.cons(c,F.cons(add(add c b)b,F.cons(add(add c a)a,F.cons(add a b,F.empty()))))))
   in A.listArray(1,3)(F.fromList[row1,row2,row3])end
