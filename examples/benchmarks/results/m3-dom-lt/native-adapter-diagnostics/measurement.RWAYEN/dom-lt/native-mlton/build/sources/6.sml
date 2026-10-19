(* Copyright (c) Matt Morrow 2009; BSD3, as declared in pinned Dom.hs. *)
(* Lengauer-Tarjan dominators, translated from Matt Morrow's BSD3 Dom.hs.
   CPS state actions preserve the source's continuation/state structure.
   Their answer type is specialized to the result consumed by this program. *)
functor BenchDomFn(P:sig val checkInitialized:bool end)=
struct
  structure G=BenchDomGraph
  structure M=G.M
  structure S=G.S
  datatype iarr=A of int Array.array*bool Array.array option
  fun newI n=A(Array.array(n,0),if P.checkInitialized then SOME(Array.array(n,false))else NONE)
  fun read(A(data,flags))i=
    (case flags of NONE=>()|SOME valid=>if Array.sub(valid,i)then()else raise Fail("uninitialized dominator array read "^Int.toString i);
     Array.sub(data,i))
  fun write(A(data,flags))i value=
    (Array.update(data,i,value);case flags of NONE=>()|SOME valid=>Array.update(valid,i,true))
  type env={succ:G.graph,pred:G.graph,bucket:G.graph,dfs:int,zero:int,root:int,
    label:iarr,parent:iarr,ancestor:iarr,child:iarr,ndfs:iarr,dfn:iarr,sdno:iarr,size:iarr,dom:iarr,rn:iarr}
  type answer=(int*int)list
  type 'a action=('a->env->answer)->env->answer
  fun pure value k state=k value state
  fun bind(m:'a action)(f:'a->'b action):'b action=fn k=>fn state=>m(fn value=>f value k)state
  fun gets getter k state=k(getter state)state
  fun modify f k state=k()(f state)
  fun store select index value k state=(write(select state)index value;k()state)
  fun fetch select index k state=k(read(select state)index)state
  fun forEach [] f=pure()
    |forEach(x::xs)f=bind(f x)(fn()=>forEach xs f)
  fun range lo hi f=if lo>hi then pure()else bind(f lo)(fn()=>range(lo+1)hi f)
  fun backwards hi lo f=if hi<lo then pure()else bind(f hi)(fn()=>backwards(hi-1)lo f)
  fun aLabel(e:env)= #label e
  fun aParent(e:env)= #parent e
  fun aAncestor(e:env)= #ancestor e
  fun aChild(e:env)= #child e
  fun aNdfs(e:env)= #ndfs e
  fun aDfn(e:env)= #dfn e
  fun aSdno(e:env)= #sdno e
  fun aSize(e:env)= #size e
  fun aDom(e:env)= #dom e
  fun aRn(e:env)= #rn e
  fun withDfs(e:env)value:env={succ = #succ e,pred = #pred e,bucket = #bucket e,dfs = value,zero = #zero e,root = #root e,label = #label e,parent = #parent e,ancestor = #ancestor e,child = #child e,ndfs = #ndfs e,dfn = #dfn e,sdno = #sdno e,size = #size e,dom = #dom e,rn = #rn e}
  fun withBucket(e:env)value:env={succ = #succ e,pred = #pred e,bucket = value,dfs = #dfs e,zero = #zero e,root = #root e,label = #label e,parent = #parent e,ancestor = #ancestor e,child = #child e,ndfs = #ndfs e,dfn = #dfn e,sdno = #sdno e,size = #size e,dom = #dom e,rn = #rn e}
  fun succs i=gets(fn(e:env)=>S.toList(G.get(#succ e)i))
  fun preds i=gets(fn(e:env)=>S.toList(G.get(#pred e)i))
  fun bucket i=gets(fn(e:env)=>S.toList(G.get(#bucket e)i))
  fun next k(e:env)=let val value= #dfs e+1 in k value(withDfs e value)end
  fun eval v=
    bind(fetch aAncestor v)(fn a=>if a=0 then fetch aLabel v else
      bind(compress v)(fn()=>bind(fetch aAncestor v)(fn a=>
      bind(fetch aLabel v)(fn label=>bind(fetch aLabel a)(fn ancestorLabel=>
      bind(fetch aSdno label)(fn small=>bind(fetch aSdno ancestorLabel)(fn ancestorSmall=>
        pure(if small<=ancestorSmall then label else ancestorLabel))))))))
  and compress v=
    bind(fetch aAncestor v)(fn a=>bind(fetch aAncestor a)(fn aa=>
      if aa=0 then pure()else
      bind(compress a)(fn()=>bind(fetch aAncestor v)(fn a=>bind(fetch aAncestor a)(fn aa=>
      bind(fetch aLabel v)(fn label=>bind(fetch aLabel a)(fn ancestorLabel=>
      bind(fetch aSdno label)(fn small=>bind(fetch aSdno ancestorLabel)(fn ancestorSmall=>
      bind(if ancestorSmall<small then store aLabel v ancestorLabel else pure())(fn()=>
        store aAncestor v aa))))))))))
  fun link v w=
    bind(fetch aLabel w)(fn labelW=>bind(fetch aSdno labelW)(fn smallW=>
      let fun balance s=
            bind(fetch aChild s)(fn c=>bind(fetch aLabel c)(fn labelC=>bind(fetch aSdno labelC)(fn smallC=>
              if smallW>=smallC then pure s else
              bind(fetch aSize s)(fn sizeS=>bind(fetch aSize c)(fn sizeC=>bind(fetch aChild c)(fn cc=>
              bind(fetch aSize cc)(fn sizeCC=>
              if 2*sizeC<=sizeS+sizeCC then
                bind(store aAncestor c s)(fn()=>bind(store aChild s cc)(fn()=>balance s))
              else bind(store aSize c sizeS)(fn()=>bind(store aAncestor s c)(fn()=>balance c)))))))))
          fun follow s=if s=0 then pure()else bind(store aAncestor s v)(fn()=>
            bind(fetch aChild s)(fn child=>follow child))
      in bind(balance w)(fn s=>bind(fetch aLabel w)(fn labelW=>bind(fetch aSize w)(fn sizeW=>
         bind(store aLabel s labelW)(fn()=>bind(fetch aSize v)(fn sizeV=>
         bind(store aSize v(sizeV+sizeW))(fn()=>bind(fetch aSize v)(fn sizeV=>
         bind(if sizeV<2*sizeW then bind(fetch aChild v)(fn child=>
                bind(store aChild v s)(fn()=>pure child))else pure s)follow)))))))end))
  fun dfs root=
    let fun go node=
          bind next(fn n=>bind(store aDfn node n)(fn()=>bind(store aSdno node n)(fn()=>
          bind(store aNdfs n node)(fn()=>bind(store aLabel node node)(fn()=>bind(succs node)(fn targets=>
            forEach targets(fn target=>bind(fetch aSdno target)(fn seen=>
              if seen<>0 then pure()else bind(store aParent target node)(fn()=>go target)))))))))
    in bind(go root)(fn()=>store aParent root 0)end
  fun fromEnv k(e:env)=
    let val A(values,_)= #dom e val n=Array.length values-1
        fun collect i=if i>n then pure[]else
          bind(fetch aRn i)(fn node=>bind(fetch aDom i)(fn parent=>bind(fetch aRn parent)(fn originalParent=>
            bind(collect(i+1))(fn rest=>pure((node,originalParent)::rest)))))
    in collect 1 k e end
  fun updatePredecessor w v=
    bind(eval v)(fn u=>bind(fetch aSdno u)(fn candidate=>bind(fetch aSdno w)(fn current=>
      if candidate<current then store aSdno w candidate else pure())))
  fun assignDominator parent v=
    bind(eval v)(fn u=>bind(fetch aSdno u)(fn candidate=>bind(fetch aSdno v)(fn current=>
      store aDom v(if candidate<current then u else parent))))
  fun processReverse i=
    bind(fetch aNdfs i)(fn w=>bind(preds w)(fn predecessors=>
    bind(forEach predecessors(updatePredecessor w))(fn()=>
    bind(fetch aSdno w)(fn small=>bind(fetch aNdfs small)(fn z=>
    bind(modify(fn(e:env)=>withBucket e(M.adjust(fn values=>S.insert w values)z(#bucket e))))(fn()=>
    bind(fetch aParent w)(fn parent=>bind(link parent w)(fn()=>bind(bucket parent)(fn values=>
      forEach values(assignDominator parent))))))))))
  fun processForward i=
    bind(fetch aNdfs i)(fn w=>bind(fetch aSdno w)(fn j=>bind(fetch aNdfs j)(fn z=>
    bind(fetch aDom w)(fn dominator=>if dominator=z then pure()else
      bind(fetch aDom dominator)(fn parent=>store aDom w parent)))))
  val idomM:answer action=
    bind(gets(fn(e:env)=> #root e))(fn root=>bind(dfs root)(fn()=>
    bind(gets(fn(e:env)=> #dfs e))(fn n=>
    bind(backwards n 1 processReverse)(fn()=>
    bind(range 1 n processForward)(fn()=>fromEnv)))))
  fun initEnv(root,graph)=
    let val(graph,rnames)=G.renumber 1 graph
        val root=valOf(M.lookup root rnames)
        val pred=G.pred graph val n=M.size graph val m=n+1
        val buckets=M.fromList(List.tabulate(m,fn i=>(i,S.Nil)))
        val rn=newI m
        val _=List.app(fn(old,renamed)=>write rn renamed old)(M.toList rnames)
        val dom=newI m val sdno=newI m val size=newI m val parent=newI m
        val ancestor=newI m val child=newI m val label=newI m val ndfs=newI m val dfn=newI m
        val _=List.app(fn i=>write dom i 0)(List.tabulate(m,fn i=>i))
        val _=List.app(fn i=>write sdno i 0)(List.tabulate(m,fn i=>i))
        val _=List.app(fn i=>write size(i+1)1)(List.tabulate(n,fn i=>i))
        val _=List.app(fn i=>write ancestor i 0)(List.tabulate(m,fn i=>i))
        val _=List.app(fn i=>write child i 0)(List.tabulate(m,fn i=>i))
        val _=write dom root root val _=write size 0 0 val _=write label 0 0
    in {succ=graph,pred=pred,bucket=buckets,dfs=0,zero=0,root=root,label=label,parent=parent,
        ancestor=ancestor,child=child,ndfs=ndfs,dfn=dfn,sdno=sdno,size=size,dom=dom,rn=rn}:env end
  fun idom graph=
    let val _=G.validate graph val initial=initEnv(G.prune graph)
    in idomM(fn value=>fn _=>value)initial end
end
