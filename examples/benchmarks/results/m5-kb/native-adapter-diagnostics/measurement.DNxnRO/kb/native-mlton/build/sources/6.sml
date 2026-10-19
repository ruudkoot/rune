(* Xavier Leroy, INRIA, 1996; Q Public License version 1.0. *)
structure BenchSandmarkKBData =
struct
  structure T=BenchSandmarkKBTerms
  fun symbol name=T.Term(name,[])
  fun inverse t=T.Term("I",[t])
  fun product(a,b)=T.Term("*",[a,b])
  val u=symbol"U"val a=symbol"A"val b=symbol"B"val c=symbol"C"
  val rules:T.rule list=[
    {number=1,numvars=1,lhs=product(u,T.Var 1),rhs=T.Var 1},
    {number=2,numvars=1,lhs=product(inverse(T.Var 1),T.Var 1),rhs=u},
    {number=3,numvars=3,lhs=product(product(T.Var 1,T.Var 2),T.Var 3),
      rhs=product(T.Var 1,product(T.Var 2,T.Var 3))},
    {number=4,numvars=0,lhs=product(a,b),rhs=product(b,a)},
    {number=5,numvars=0,lhs=product(c,c),rhs=u},
    {number=6,numvars=0,lhs=product(c,product(a,inverse c)),rhs=inverse a},
    {number=7,numvars=0,lhs=product(c,product(b,inverse c)),rhs=b}]
end
