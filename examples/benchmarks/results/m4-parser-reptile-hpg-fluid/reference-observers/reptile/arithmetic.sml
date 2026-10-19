 fun square n=mul n n
 fun diff a b=D.delay(fn()=>D.force(if gt a b then sub a b else sub b a))
 fun bcroot n=D.delay(fn()=>
   let fun root a b=if ge(add a(int 1))b then b
         else let val m=divide(add a b)(int 2)val s=mul m m
              in if lt s n then root m b else if lt n s then root a m else m end
   in D.force(root(int 0)n)end)
 fun norm rational=D.delay(fn()=>
   let val(x,y)=D.force rational
       val u=D.delay(fn()=>D.force(if gt y(int 0)then x else negative x))
       val v=absolute y
       fun gcd n1 n2=D.delay(fn()=>
         if eq n1(int 0)then D.force n2 else if eq n2(int 0)then D.force n1
         else D.force(if lt n1 n2 then gcd n1(modulo n2 n1)else gcd(modulo n1 n2)n2))
       val d=gcd(absolute u)v
   in(divide u d,divide v d)end)
 fun radd first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(add(mul x v)(mul u y))(mul y v)))end)
 fun rsub first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(sub(mul x v)(mul u y))(mul y v)))end)
 fun rmul first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(mul x u)(mul y v)))end)
 fun rdiv first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(mul x v)(mul y u)))end)
 fun rmin first second=D.delay(fn()=>
   let val(a,_)=D.force(rsub first second)
   in D.force(if gt a(int 0)then second else first)end)
 fun rabs rational=D.delay(fn()=>let val(x,y)=D.force rational
   in(if lt x(int 0)then negative x else x,y)end)
 fun intval rational=D.delay(fn()=>let val(x,y)=D.force rational in D.force(divide x y)end)
 fun torat n=pair n(int 1)
 fun show_rat rational=F.defer(fn()=>let val(x,y)=D.force rational
   in F.append(showInt x)(F.append(text"/")(showInt y))end)
