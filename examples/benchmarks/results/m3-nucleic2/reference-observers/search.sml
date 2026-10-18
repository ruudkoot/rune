 datatype variableNode=Var of int*tfo*nuc
 type variable=variableNode D.t
 type partial=variableNode F.seq
 fun mk_var i t n=D.delay(fn()=>Var(i,t,if shared then make_relative_nuc t n else n))
 fun absolute_pos v p=D.delay(fn()=>
   let val Var(_,t,_)=D.force v in if shared then D.force p else D.force(tfo_apply t p)end)
 fun atom_pos atom v=D.delay(fn()=>
   let val Var(_,_,n)=D.force v in D.force(absolute_pos v(atom n))end)
 fun get_var wanted values=D.delay(fn()=>
   let fun seek values=case D.force values of F.Nil=>raise Match
         |F.Cons(value,rest)=>let val node as Var(i,_,_)=D.force value
           in if i=wanted then node else seek rest end
   in seek values end)
 fun search partial domains constraint=F.defer(fn()=>
   case D.force domains of F.Nil=>F.cons(partial,F.empty())
    |F.Cons(domain,rest)=>
      let fun try values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
            |F.Cons(value,tail)=>if constraint value partial then
               F.append(search(F.cons(value,partial))rest constraint)(try tail)
              else try tail)
      in try(D.force domain partial)end)
 fun dgf_base relation v nuc=D.delay(fn()=>
   let val Var(_,t,n)=D.force v
       val x=if is_A n then tfo_align(atom_pos nuc_C1XXX v)(atom_pos rA_N9 v)(atom_pos nuc_C4 v)
         else if is_C n then tfo_align(atom_pos nuc_C1XXX v)(atom_pos nuc_N1 v)(atom_pos nuc_C2 v)
         else if is_G n then tfo_align(atom_pos nuc_C1XXX v)(atom_pos rG_N9 v)(atom_pos nuc_C4 v)
         else tfo_align(atom_pos nuc_C1XXX v)(atom_pos nuc_N1 v)(atom_pos nuc_C2 v)
   in D.force(tfo_combine(nuc_dgf_base_tfo nuc)(tfo_combine relation(tfo_inv_ortho x)))end)
 fun reference nuc i partial=F.cons(mk_var i tfo_id nuc,F.empty())
 fun wc nuc i j partial=F.cons(mk_var i(dgf_base wc_tfo(get_var j partial)nuc)nuc,F.empty())
 fun wc_dumas nuc i j partial=F.cons(mk_var i(dgf_base wc_dumas_tfo(get_var j partial)nuc)nuc,F.empty())
 fun helix5XXX nuc i j partial=F.cons(mk_var i(dgf_base helix5XXX_tfo(get_var j partial)nuc)nuc,F.empty())
 fun helix3XXX nuc i j partial=F.cons(mk_var i(dgf_base helix3XXX_tfo(get_var j partial)nuc)nuc,F.empty())
 fun g37_a38 nuc i j partial=mk_var i(dgf_base g37_a38_tfo(get_var j partial)nuc)nuc
 fun a38_g37 nuc i j partial=mk_var i(dgf_base a38_g37_tfo(get_var j partial)nuc)nuc
 fun stacked5XXX nuc i j partial=F.cons(g37_a38 nuc i j partial,helix5XXX nuc i j partial)
 fun stacked3XXX nuc i j partial=F.cons(a38_g37 nuc i j partial,helix3XXX nuc i j partial)
 fun p_o3XXX nucs i j partial=F.defer(fn()=>
   let val reference=get_var j partial
       val align=tfo_inv_ortho(tfo_align(atom_pos nuc_O3XXX reference)
           (atom_pos nuc_C3XXX reference)(atom_pos nuc_C4XXX reference))
       fun generate domains values=case D.force values of F.Nil=>domains
         |F.Cons(n,rest)=>generate
            (F.cons(mk_var i(tfo_combine(nuc_p_o3XXX_60_tfo n)align)n,
             F.cons(mk_var i(tfo_combine(nuc_p_o3XXX_180_tfo n)align)n,
             F.cons(mk_var i(tfo_combine(nuc_p_o3XXX_275_tfo n)align)n,domains))))rest
   in generate(F.empty())nucs end)
 fun anticodon_constraint v partial=
   let val Var(i,_,_)=D.force v
   in i<>33 orelse real(pt_dist(atom_pos nuc_P(get_var 34 partial))(atom_pos nuc_O3XXX v))<=R.round 3.0 end
 fun pseudoknot_constraint v partial=
   let val Var(i,_,_)=D.force v
       fun distance j=real(pt_dist(atom_pos nuc_P(get_var j partial))(atom_pos nuc_O3XXX v))
   in if i=18 then distance 19<=R.round 4.0 else if i=6 then distance 7<=R.round 4.5 else true end
