(* Copyright (c) Matt Morrow 2009; BSD3, as declared in pinned Dom.hs. *)
(* Matt Morrow's Dom.hs graph operations, nofib's pinned dom-lt.
   Original BSD3 notice and containers dependency notices are retained. *)
structure BenchDomGraph =
struct
  structure M=BenchDomIntMap
  structure S=BenchDomIntSet
  type graph=S.set M.map
  type rooted=int*graph
  fun get graph node=case M.lookup node graph of NONE=>S.Nil|SOME values=>values
  fun fromAdj values=M.fromList(List.map(fn(node,successors)=>(node,S.fromList successors))values)
  fun toAdj graph=List.map(fn(node,successors)=>(node,S.toList successors))(M.toList graph)
  fun pred graph=
    let val empty=M.map(fn _=>S.Nil)graph
        fun add acc node targets=List.foldl(fn(target,acc)=>
          M.insertWith S.union target(S.singleton node)acc)acc(S.toList targets)
    in M.unionWith S.union(M.foldl add M.Nil graph)empty end
  fun reachable successors root=
    let fun go seen node=
          let val targets=successors node
              val unseen=S.toList(S.difference targets seen)
          in List.foldl(fn(child,seen)=>go seen child)(S.union targets seen)unseen end
    in go(S.singleton root)root end
  fun prune(root,graph)=
    let val seen=reachable(get graph)root
        val nodes=List.filter(fn(node,_)=>S.member node seen)(M.toList graph)
    in(root,M.fromList(List.map(fn(node,values)=>(node,S.filter(fn value=>S.member value seen)values))nodes))end
  fun renumber first graph=
    let fun one next env node=case M.lookup node env of SOME renamed=>(renamed,next,env)
          |NONE=>(next,next+1,M.insert node next env)
        fun node(next,env,new)key targets=
          let val(renamed,next,env)=one next env key
              fun target old(next,env,values)=
                let val(renamed,next,env)=one next env old
                in(next,env,S.insert renamed values)end
              val(next,env,values)=S.foldr target(next,env,S.Nil)targets
          in(next,env,M.insertWith S.union renamed values new)end
        val(_,env,new)=M.foldl node(first,M.Nil,M.Nil)graph
    in(new,env)end
  fun validate(root,graph)=
    if Option.isSome(M.lookup root graph)andalso
       List.all(fn(_,targets)=>List.all(fn node=>Option.isSome(M.lookup node graph))(S.toList targets))(M.toList graph)
    then()else raise Fail "dominator graph requires a root and an adjacency entry for every successor"
end
