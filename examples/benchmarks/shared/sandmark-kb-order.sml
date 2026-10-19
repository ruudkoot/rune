(* Xavier Leroy, INRIA, 1996; Q Public License version 1.0. *)
structure BenchSandmarkKBOrder =
struct
  structure T=BenchSandmarkKBTerms
  datatype ordering=Greater|Equal|NotGE
  fun ge order pair=case order pair of NotGE=>false|_=>true
  fun gt order pair=case order pair of Greater=>true|_=>false
  fun eq order pair=case order pair of Equal=>true|_=>false
  fun remove _ _ []=raise T.Failure "rem_eq"
    |remove equiv x(y::ys)=if equiv(x,y)then ys else y::remove equiv x ys
  fun difference equiv(x,y)=
    let fun loop([],ys)=([],ys)
          |loop(h::rest,ys)=
            (loop(rest,remove equiv h ys)handle T.Failure _=>
              let val(xs,ys')=loop(rest,ys)in(h::xs,ys')end)
    in if List.length x>List.length y then loop(y,x)else loop(x,y)end
  fun multiset order(T.Term(_,xs),T.Term(_,ys))=
      (case difference(eq order)(xs,ys)of([],[])=>Equal
       |(a,b)=>if List.all(fn n=>List.exists(fn m=>gt order(m,n))a)b then Greater else NotGE)
    |multiset _ _=raise T.Failure "mult_ext"
  fun lex order(m as T.Term(_,xs),n as T.Term(_,ys))=
      let fun loop([],[])=Equal|loop([],_) =NotGE|loop(_,[])=Greater
            |loop(x::xr,y::yr)=case order(x,y)of
                Greater=>if List.all(fn n'=>gt order(m,n'))yr then Greater else NotGE
              |Equal=>loop(xr,yr)
              |NotGE=>if List.exists(fn m'=>ge order(m',n))xr then Greater else NotGE
      in loop(xs,ys)end
    |lex _ _=raise T.Failure "lex_ext"
  fun rpo precedence extension=
    let fun order(m,n)=if m=n then Equal else case m of T.Var _=>NotGE
          |T.Term(op1,sons1)=>case n of T.Var vn=>if T.occurs vn m then Greater else NotGE
            |T.Term(op2,sons2)=>case precedence op1 op2 of
               Greater=>if List.all(fn n'=>gt order(m,n'))sons2 then Greater else NotGE
              |Equal=>extension order(m,n)
              |NotGE=>if List.exists(fn m'=>ge order(m',n))sons1 then Greater else NotGE
    in order end
  fun rank "U"=0|rank"*"=1|rank"I"=2|rank"B"=3|rank"C"=4|rank"A"=5
    |rank _=raise T.Invalid "source group_rank assertion"
  fun precedence a b=if rank a=rank b then Equal else if rank a>rank b then Greater else NotGE
  val groupOrder=rpo precedence lex
  fun greater pair=case groupOrder pair of Greater=>true|_=>false
end
