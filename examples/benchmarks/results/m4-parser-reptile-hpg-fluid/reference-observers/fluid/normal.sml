 type 'a normalPack='a L.delay*bool L.delay
 fun andAnd a b=if a then if b()then true else raise Fail"andAnd: 2nd argument not True"
   else raise Fail"andAnd: first argument not True\n"
 fun normalReal value=let val x=force value in if Real.==(x,0.0)then true else true end
 fun normalArray normal a=
   let val A.Array(_,_,default,trie)=L.force a
       fun node trie=case L.force trie of A.Null=>true|A.Leaf value=>normal value
          |A.Fork(left,right)=>andAnd(node left)(fn()=>node right)
       val default=case default of NONE=>true|SOME value=>normal value
   in andAnd default(fn()=>node trie)end
 fun normalVelocity(x,y)=andAnd(normalArray normalReal x)(fn()=>normalArray normalReal y)
 fun pack normal thunk=let val root=L.delay thunk
   in(root,L.delay(fn()=>normal(L.force root)))end
 fun normalize(_,flag)=L.force flag
 fun retrieve(root,_)=L.force root
