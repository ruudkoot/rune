functor BenchLiftSerializeFn(K:sig
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
 fun quote text="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"|c=>String.str c)text^"\""
 fun array values="["^String.concatWith","values^"]"
 fun name value=quote(L.force value)
 fun number value=String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value)
 fun expression binder expr=case L.force expr of
     K.EConst(K.CNum n)=>array[quote"num",number n]
    |K.EConst(K.CBool b)=>array[quote"bool",if b then"true"else"false"]
    |K.EConst(K.CFun n)=>array[quote"fun",name n]
    |K.EVar n=>array[quote"var",name n]
    |K.EAp(a,b)=>array[quote"app",expression binder a,expression binder b]
    |K.ELam(args,body)=>array[quote"lam",array(List.map binder args),expression binder body]
    |K.ELet(recursive,definitions,body)=>array[quote"let",if recursive then"true"else"false",
       array(List.map(fn(n,rhs)=>array[binder n,expression binder rhs])definitions),expression binder body]
 fun supercombinators values=array(List.map(fn(n,args,body)=>array[name n,array(List.map name args),expression name body])values)
end
