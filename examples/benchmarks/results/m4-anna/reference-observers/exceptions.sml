 fun addException a b=D.delay(fn()=>let val MkExInt(n,xs)=force a val MkExInt(m,ys)=force b
   in MkExInt(add n m,F.append xs ys)end)
 fun multiplyException a b=D.delay(fn()=>let val MkExInt(n,xs)=force a val MkExInt(m,ys)=force b
   in MkExInt(multiply n m,F.append xs ys)end)
