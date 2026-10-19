functor BenchHpgFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure R=BenchHpgRandomFn(D)
 structure C=R.C
 type text=char C.seq
 datatype numkind=IntType|IntegerType|FloatType|DoubleType
 datatype basetype=NumType of numkind|BoolType|CharType
 datatype argnode=NameType of string D.t|BasicType of basetype D.t
   |ListType of argnode D.t|TupleType of argnode F.seq|ArrayType of argnode D.t*argnode D.t
 type argtype=argnode D.t
 type htype=(string D.t*argnode F.seq)F.seq
 type typedecl=string D.t*htype
 datatype valnode=NumVal of numkind*int D.t|BoolVal of bool D.t|CharVal of char D.t
   |ListVal of valnode F.seq|TupleVal of valnode F.seq|TaggedVal of string D.t*valnode F.seq
   |ArrayVal of (valnode D.t*valnode D.t)*(valnode D.t*valnode D.t)F.seq
 type value=valnode D.t
 datatype expnode=ApplyExp of expnode D.t*expnode D.t|IdExp of string D.t|ValExp of value
   |TaggedExp of string D.t*expnode F.seq|ListExp of expnode F.seq|TupleExp of expnode F.seq
   |LambdaExp of string D.t*expnode D.t|ArrayExp of expnode D.t*expnode D.t
 type expression=expnode D.t
 type output=text->unit
 datatype env=Env of real D.t C.seq*string C.seq*string C.seq*string C.seq*
   typedecl F.seq*(string D.t*value)F.seq*(string D.t*value)F.seq*output
 fun force value=D.force value
 fun scalar x=D.delay(fn()=>x)
 fun empty()=F.empty()
 fun singleton x=F.cons(x,F.empty())
 fun head xs=case force xs of F.Nil=>raise Empty|F.Cons(x,_)=>x
 fun tail xs=F.defer(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(_,rest)=>rest)
 fun null xs=case force xs of F.Nil=>true|_=>false
 fun map f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.cons(D.delay(fn()=>force(f x)),map f rest))
 fun flatMap f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.append(f x)(flatMap f rest))
 fun zip xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()|F.Cons(x,xt)=>
   case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>F.cons(D.delay(fn()=>(x,y)),zip xt yt))
 fun pairs xs ys=map(fn p=>let val(x,y)=force p in D.delay(fn()=>(x,y))end)(zip xs ys)
 fun listPairs xs ys=map(fn p=>let val(x,y)=force p in scalar(x,force y)end)(zip xs ys)
 fun nth xs n=case force xs of F.Nil=>raise Subscript|F.Cons(x,rest)=>if n=0 then x else nth rest(n-1)
 fun last xs=case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>if null rest then x else last rest
 fun length xs=case force xs of F.Nil=>0|F.Cons(_,rest)=>1+length rest
 fun repeat x=let val root=ref NONE
     fun node()=case !root of SOME xs=>xs|NONE=>
       let val xs=BenchNeed.delay(fn()=>C.Cons(L.delay(fn()=>x),node()))
       in root:=SOME xs;xs end
   in node()end
 fun rep n x=let
     fun take n xs=F.defer(fn()=>if n<=0 then F.empty()else case BenchNeed.force xs of
        C.Nil=>F.empty()|C.Cons(v,rest)=>F.cons(D.delay(fn()=>L.force v),take(n-1)rest))
   in take n(repeat x)end
 fun cmap xcs k env=case force xcs of F.Nil=>k(F.empty())env|F.Cons(xc,rest)=>
   force xc(fn x=>cmap rest(fn xs=>k(F.cons(x,xs))))env
 fun names prefix n=C.defer(fn()=>C.cons(L.delay(fn()=>prefix^Int.toString n),names prefix(n+1)))
 fun makeEnv seeds opn=Env(R.random seeds,names "Cons" 1,names "Type" 1,names "val" 1,
       F.empty(),F.empty(),F.empty(),opn)
 fun upto n k(Env(rs,cs,ts,vs,te,ve,le,out))=case BenchNeed.force rs of
   C.Nil=>raise Empty|C.Cons(r,rest)=>let val value=R.upto n(L.force r)
     in k(scalar value)(Env(rest,cs,ts,vs,te,ve,le,out))end
 fun choose xs k=upto(length xs-1)(fn n=>k(nth xs(force n)))
 fun choosew ps k=let
     fun sum xs=case force xs of F.Nil=>0|F.Cons(p,rest)=> #1(force p)+sum rest
     fun select xs n=let val(i,x)=force(head xs)
       in if n<i then k x else select(tail xs)(n-i)end
   in upto(sum ps-1)(fn n=>select ps(force n))end
 fun takeNames 0 xs=F.empty()|takeNames n xs=F.defer(fn()=>case BenchNeed.force xs of
   C.Nil=>F.empty()|C.Cons(x,rest)=>F.cons(D.delay(fn()=>L.force x),takeNames(n-1)rest))
 fun getConstructors n k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(takeNames n cs)(Env(rs,C.drop n cs,ts,vs,te,ve,le,out))
 fun getTypeNames n k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(takeNames n ts)(Env(rs,cs,C.drop n ts,vs,te,ve,le,out))
 fun getValNames n k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(takeNames n vs)(Env(rs,cs,ts,C.drop n vs,te,ve,le,out))
 fun allTypeNames k(e as Env(_,_,_,_,te,_,_,_))=k(map(fn p=> #1(force p))te)e
 fun allTypes k(e as Env(_,_,_,_,te,_,_,_))=k te e
 fun allValues k(e as Env(_,_,_,_,_,ve,_,_))=k ve e
 fun allLambdas k(e as Env(_,_,_,_,_,_,le,_))=k le e
 fun getType name k(e as Env(_,_,_,_,te,_,_,_))=
   k(#2(force(head(F.filter(fn(n,_)=>force n=force name)te))))e
 fun getOutput k(e as Env(_,_,_,_,_,_,_,out))=k out e
 fun extendTypes tds k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(Env(rs,cs,ts,vs,F.append tds te,ve,le,out))
 fun extendValues vds k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(Env(rs,cs,ts,vs,te,F.append vds ve,le,out))
 fun pushLambda v k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(Env(rs,cs,ts,vs,te,ve,F.cons(scalar v,le),out))
 fun popLambda k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(force(head le))(Env(rs,cs,ts,vs,te,ve,tail le,out))
 fun text str=C.fromList(String.explode str)
 fun append a b=C.append a b
 fun string xs=String.implode(C.toList xs)
 fun number n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun base b=scalar(BasicType(scalar b))
 fun numeric k n=scalar(NumVal(k,scalar n))
 fun tuple vs=scalar(TupleVal vs)
 fun intVal n=numeric IntType n
 fun valExp v=scalar(ValExp v)
 fun idExp name=scalar(IdExp(scalar name))
 fun apply a b=scalar(ApplyExp(a,b))
 fun tagged name vs=scalar(TaggedVal(name,vs))
 fun list values=F.fromList values
 (* Prefix-consumed index producers retain memoized control spines even
    when finite AST attributes use the strict evaluation policy. *)
 fun controlFromFinite values=C.defer(fn()=>case force values of F.Nil=>C.empty()
   |F.Cons(x,rest)=>C.cons(L.delay(fn()=>x),controlFromFinite rest))
 fun finiteFromControl values=F.defer(fn()=>case BenchNeed.force values of C.Nil=>F.empty()
   |C.Cons(x,rest)=>F.cons(L.force x,finiteFromControl rest))
 fun controlFlatMap f values=C.defer(fn()=>
   let fun seek values=case BenchNeed.force values of C.Nil=>C.empty()
     |C.Cons(x,rest)=>(case BenchNeed.force(f(L.force x))of C.Nil=>seek rest
       |C.Cons(y,ys)=>C.cons(y,C.append ys(controlFlatMap f rest)))
   in seek values end)
 fun range a b=C.defer(fn()=>if a>b then C.empty()
   else C.cons(L.delay(fn()=>a),range(a+1)b))
 fun vrange(a,b)=C.defer(fn()=>case(force a,force b)of
   (NumVal(IntType,n),NumVal(IntType,m))=>C.map(intVal)(range(force n)(force m))
  |(NumVal(IntegerType,n),NumVal(IntegerType,m))=>C.map(numeric IntegerType)(range(force n)(force m))
  |(BoolVal n,BoolVal m)=>C.map(fn x=>scalar(BoolVal(scalar(x=1))))
      (range(if force n then 1 else 0)(if force m then 1 else 0))
  |(CharVal n,CharVal m)=>C.map(fn x=>scalar(CharVal(scalar(Char.chr x))))
      (range(Char.ord(force n))(Char.ord(force m)))
  |(TupleVal ns,TupleVal ms)=>let
      fun product xs=C.defer(fn()=>case BenchNeed.force xs of C.Nil=>C.fromList[C.empty()]
       |C.Cons(x,rest)=>controlFlatMap(fn v=>C.map(fn vs=>C.cons(L.delay(fn()=>v),vs))
          (product rest))(L.force x))
      val choices=C.map(fn p=>let val(n,m)=force p in vrange(n,m)end)
        (controlFromFinite(zip ns ms))
     in C.map(fn xs=>scalar(TupleVal(finiteFromControl xs)))(product choices)end
  |_=>raise Fail"Error: vrange called on non-index values")
