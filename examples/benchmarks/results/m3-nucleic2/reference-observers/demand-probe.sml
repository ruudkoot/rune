structure AuditNeed=struct
 type 'a t='a BenchLazy.delay
 val hits=ref 0
 fun delay f=BenchLazy.delay(fn()=>(hits:= !hits+1;f()))
 val force=BenchLazy.force
end
functor SharingProbeFn(val shared:bool)=struct
 structure D=AuditNeed
 structure K=BenchNucleic2Fn(structure D=D val shared=shared)
 val variable=K.mk_var 77 K.wc_tfo K.rA
 fun query()=let val K.Pt(x,_,_)=D.force(K.atom_pos K.nuc_P variable)in D.force x end
 val hitsBefore= !D.hits
 val first=query()
 val firstCost= !D.hits-hitsBefore
 val hitsBefore= !D.hits
 val second=query()
 val secondCost= !D.hits-hitsBefore
 val hitsBefore= !D.hits
 val third=query()
 val thirdCost= !D.hits-hitsBefore
 val _=if Real.==(first,second)andalso Real.==(second,third)andalso secondCost=thirdCost then()
   else raise Fail"coordinate sharing values or repeated demands differ"
 val _=print((if shared then"shared"else"on-demand")^" evaluations "^Int.toString firstCost^" "^Int.toString secondCost^" "^Int.toString thirdCost^"\n")
end
structure OnDemandSharing=SharingProbeFn(val shared=false)
structure PlacedSharing=SharingProbeFn(val shared=true)
val _=if OnDemandSharing.secondCost>PlacedSharing.secondCost then print"PASS shared coordinates avoid repeated transformation demands\n"
 else raise Fail"shared placement does not reduce repeated coordinate evaluation"
structure UnusedPointProbe=struct
 structure D=BenchNeed
 structure K=BenchNucleic2Fn(structure D=D val shared=true)
 exception Demanded
 val K.Nuc(t0,t1,t2,t3,p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,x)=D.force K.rA
 val bad=D.delay(fn()=>K.Nuc(t0,t1,t2,t3,p0,D.delay(fn()=>raise Demanded),p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,x))
 val variable=K.mk_var 77 K.tfo_id bad
 val K.Pt(px,_,_)=D.force(K.atom_pos K.nuc_P variable)
 val _=if Real.==(D.force px,2.8929998874664307)then print"PASS shared placement skips unused atom coordinates\n"
   else raise Fail"reference atom differs"
 val _=(D.force(K.atom_pos(fn n=>
      let val K.Nuc(_,_,_,_,_,p1,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)=D.force n in p1 end)variable);
      raise Fail"unused-atom negative control did not fail")handle Demanded=>print"PASS poison atom is detected when demanded\n"
end
