functor BenchHartelTypecheckProgramFn(P:sig val eagerChildren:bool end)=
struct
  structure C=BenchHartelTypecheckFn(P)
  open C
  fun ap3 a b c=apply(apply a b)c
  fun ap4 a b c d=apply(apply(apply a b)c)d
  val cons=variable"cons"
  val one=variable"1"
  val zero=variable"0"
  val ifExp=variable"if"
  val nullExp=variable"null"
  val tailExp=variable"tail"
  val headExp=variable"head"
  val nilExp=variable"NIL"
  val add=variable"add"
  val x=variable"x"
  val f=variable"f"
  val len=variable"len"
  val sum=variable"sum"
  val mapExp=variable"map"
  val ones=variable"ones"
  val y=variable"Y"
  val n=variable"n"
  val a=variable"a"
  val b=variable"b"
  val z=variable"z"
  val s=variable"S"
  val k=variable"K"
  val programs=S.fromList[
    ("ones",recursive["ones"][ap3 cons one ones]ones),
    ("len ",recursive["len"][lambdas["x"](ap4 ifExp(apply nullExp x)zero(ap3 add one(apply len(apply tailExp x))))]len),
    ("map ",recursive["map"][lambdas["f","x"](ap4 ifExp(apply nullExp x)nilExp
       (ap3 cons(apply f(apply headExp x))(ap3 mapExp f(apply tailExp x))))]mapExp),
    ("skk ",letExp["S","K"][lambdas["x","y","z"](ap3 x z(apply(variable"y")z)),lambdas["x","y"]x](ap3 s k k)),
    ("inc ",lambdas["x"](ap3 add one x)),
    ("sum ",recursive["sum"][lambdas["x"](ap4 ifExp(apply nullExp x)zero
       (ap3 add(apply headExp x)(apply sum(apply tailExp x))))]sum),
    ("y   ",recursive["Y"][lambdas["f"](apply f(apply y f))]y),
    ("succ",lambdas["n","a","b"](ap3 b n(ap3 n a b)))]
  fun row(name,expression)=name^" :: "^check expression^"\n"
  fun allRows()=String.concat(rev(S.foldl(fn(pair,rows)=>row pair::rows)[]programs))
  fun repeat n xs=L.delay(fn()=>if n=0 then S.Nil else
    L.force(S.append xs(repeat(n-1)xs)))
  fun sumcode output=
    let val(sum,length)=S.foldl(fn(c,(sum,n))=>(sum+Char.ord c,n+1))(0,0)output
    in Int.toString(sum+length)^"/"^Int.toString length^"\n"end
  fun calculate count observe=
    let val rows=S.map(fn pair=>let val text=row pair val _=observe text in text end)(repeat count programs)
        fun chars text=S.fromList(String.explode text)
    in sumcode(S.concatMap chars rows)end
  fun benchmark count=calculate count(fn _=>())

end
