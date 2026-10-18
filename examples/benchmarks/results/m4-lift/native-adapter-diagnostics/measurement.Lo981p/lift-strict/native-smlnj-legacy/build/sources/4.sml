functor BenchLiftPrintFn(K:sig
 type name=string BenchLazy.delay
 datatype constant=CNum of IntInf.int|CBool of bool|CFun of name
 datatype 'b exprNode=EConst of constant|EVar of name
  |EAp of 'b exprNode BenchLazy.delay*'b exprNode BenchLazy.delay
  |ELam of 'b list*'b exprNode BenchLazy.delay
  |ELet of bool*('b*'b exprNode BenchLazy.delay)list*'b exprNode BenchLazy.delay
 type 'b expr='b exprNode BenchLazy.delay
end)=
struct
 structure L=BenchLazy
 type oseq=int->bool->char list
 type iseq=oseq->oseq
 fun nilSeq rest=rest
 fun append first last rest=first(last rest)
 fun char #"\n" rest indent pending= #"\n"::rest indent true
   |char value rest indent false=value::rest indent false
   |char value rest indent true=List.tabulate(indent,fn _=> #" ")@(value::rest indent false)
 fun text value=List.foldr(fn(c,result)=>append(char c)result)nilSeq(String.explode value)
 fun concat values=List.foldr(fn(a,b)=>append a b)nilSeq values
 fun interleave separator []=nilSeq
   |interleave separator[first]=first
   |interleave separator(first::rest)=append first(append separator(interleave separator rest))
 fun indent amount value rest oldIndent pending=
   let fun continuation _ newPending=rest oldIndent newPending
   in value continuation(oldIndent+amount)pending end
 fun mkstr seq=String.implode(seq(fn _=>fn _=>[])0 false)
 fun name value rest ind pend=text(L.force value)rest ind pend
 fun number value=text(String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value))
 val space=text" "
 val newline=text"\n"
 fun ppr binder expr rest ind pend=
   let val result=case L.force expr of
        K.EAp(a,b)=>concat[ppr binder a,space,atomic binder b]
       |K.ELet(recursive,definitions,body)=>concat[
          text(if recursive then"letrec"else"let"),newline,
          indent 4(interleave(text";\n")(List.map(definition binder)definitions)),
          text"\nin ",ppr binder body]
       |K.ELam(args,body)=>concat[text"\\[",interleave(text",")(List.map binder args),text"] ",ppr binder body]
       |_=>atomic binder expr
   in result rest ind pend end
 and atomic binder expr rest ind pend=
   let val result=case L.force expr of
        K.EConst(K.CNum n)=>number n
       |K.EConst(K.CBool b)=>text(if b then"True"else"False")
       |K.EConst(K.CFun n)=>name n
       |K.EVar n=>name n
       |_=>concat[text"(",ppr binder expr,text")"]
   in result rest ind pend end
 and definition binder(name,rhs)rest ind pend=
   let val result=case L.force rhs of K.ELam(args,body)=>
          concat[binder name,space,interleave space(List.map binder args),text" = ",ppr binder body]
        |_=>concat[binder name,text" = ",ppr binder rhs]
   in result rest ind pend end
 fun expression expr=mkstr(ppr name expr)
 fun sc(scname,args,body)=concat[newline,text(L.force scname),text" ",
   interleave(text" ")(List.map(fn n=>text(L.force n))args),text" = ",indent 6(ppr name body)]
 fun supercombinators values=mkstr(concat(List.map sc values))
end
