 fun nuc_C1XXX n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,value,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_C2 n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,value,_,_,_,_)=D.force n in D.force value end)
 fun nuc_C3XXX n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,value,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_C4 n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,value,_,_,_)=D.force n in D.force value end)
 fun nuc_C4XXX n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,value,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_N1 n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,value,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_O3XXX n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,value,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_P n=D.delay(fn()=>let val Nuc(_,_,_,_,value,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_dgf_base_tfo n=D.delay(fn()=>let val Nuc(value,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_p_o3XXX_180_tfo n=D.delay(fn()=>let val Nuc(_,_,value,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_p_o3XXX_275_tfo n=D.delay(fn()=>let val Nuc(_,value,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun nuc_p_o3XXX_60_tfo n=D.delay(fn()=>let val Nuc(_,_,_,value,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in D.force value end)
 fun is_A n=let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,specific)=D.force n in case D.force specific of A _=>true|_=>false end
 fun is_C n=let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,specific)=D.force n in case D.force specific of C _=>true|_=>false end
 fun is_G n=let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,specific)=D.force n in case D.force specific of G _=>true|_=>false end
 fun rA_N9 n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,specific)=D.force n
   in case D.force specific of A(_,_,value,_,_,_,_,_)=>D.force value|_=>raise Match end)
 fun rG_N9 n=D.delay(fn()=>let val Nuc(_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,specific)=D.force n
   in case D.force specific of G(_,_,value,_,_,_,_,_,_)=>D.force value|_=>raise Match end)
 fun make_relative_nuc t n=D.delay(fn()=>
   let val Nuc(dgf_base_tfo,p_o3XXX_275_tfo,p_o3XXX_180_tfo,p_o3XXX_60_tfo,p,o1p,o2p,o5XXX,c5XXX,h5XXX,h5XXXXXX,c4XXX,h4XXX,o4XXX,c1XXX,h1XXX,c2XXX,h2XXXXXX,o2XXX,h2XXX,c3XXX,h3XXX,o3XXX,n1,n3,c2,c4,c5,c6,specific)=D.force n
       val relativeSpecific=case D.force specific of
          A(a0,a1,a2,a3,a4,a5,a6,a7)=>D.delay(fn()=>A(tfo_apply t a0,tfo_apply t a1,tfo_apply t a2,tfo_apply t a3,tfo_apply t a4,tfo_apply t a5,tfo_apply t a6,tfo_apply t a7))
         |C(a0,a1,a2,a3,a4,a5)=>D.delay(fn()=>C(tfo_apply t a0,tfo_apply t a1,tfo_apply t a2,tfo_apply t a3,tfo_apply t a4,tfo_apply t a5))
         |G(a0,a1,a2,a3,a4,a5,a6,a7,a8)=>D.delay(fn()=>G(tfo_apply t a0,tfo_apply t a1,tfo_apply t a2,tfo_apply t a3,tfo_apply t a4,tfo_apply t a5,tfo_apply t a6,tfo_apply t a7,tfo_apply t a8))
         |U(a0,a1,a2,a3,a4)=>D.delay(fn()=>U(tfo_apply t a0,tfo_apply t a1,tfo_apply t a2,tfo_apply t a3,tfo_apply t a4))
   in Nuc(dgf_base_tfo,p_o3XXX_275_tfo,p_o3XXX_180_tfo,p_o3XXX_60_tfo,tfo_apply t p,tfo_apply t o1p,tfo_apply t o2p,tfo_apply t o5XXX,tfo_apply t c5XXX,tfo_apply t h5XXX,tfo_apply t h5XXXXXX,tfo_apply t c4XXX,tfo_apply t h4XXX,tfo_apply t o4XXX,tfo_apply t c1XXX,tfo_apply t h1XXX,tfo_apply t c2XXX,tfo_apply t h2XXXXXX,tfo_apply t o2XXX,tfo_apply t h2XXX,tfo_apply t c3XXX,tfo_apply t h3XXX,tfo_apply t o3XXX,tfo_apply t n1,tfo_apply t n3,tfo_apply t c2,tfo_apply t c4,tfo_apply t c5,tfo_apply t c6,relativeSpecific)end)
