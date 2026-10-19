(* Direct portable representation of Anna 0.400's source datatypes.
   Machine Int computations retain the pinned GHC 64-bit arithmetic. *)
functor BenchAnnaFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure C=BenchIdaFiniteFn(BenchNeed)
 structure W=Word64
 structure S=BenchSigned64
 type integer=W.word D.t
 type nameNode=char F.node
 type name=char F.seq
 datatype ('a,'b)treeNode=ALeaf
   |ABranch of ('a,'b)treeNode D.t*'a D.t*'b D.t*('a,'b)treeNode D.t*integer
 datatype ('a,'b)replyNode=Ok of 'a D.t|Failed of 'b D.t
 datatype 'a setNode=MkSet of 'a F.seq
 datatype 'a maybeNode=Nothing|Just of 'a D.t
 datatype flagNode=Typecheck|Simp|NoCaseOpt|ShowHExpr|NoPretty|NoFormat|NoBaraki|SimpleInv
   |PolyLim of integer|MonoLim of integer|ForceAll|DryRun|LowerLim of integer
   |UpperLim of integer|ScaleUp of integer
 type flags=flagNode F.seq
 datatype tdefNode=TDefVar of name|TDefCons of name*tdefNode F.seq
 type typeDef=name*nameNode F.seq*(name*tdefNode F.seq)F.seq
 datatype 'a coreNode=EVar of name|ENum of integer|EConstr of name
   |EAp of 'a coreNode D.t*'a coreNode D.t
   |ELet of bool D.t*('a D.t*'a coreNode D.t)F.seq*'a coreNode D.t
   |ECase of 'a coreNode D.t*(name*('a F.seq*'a coreNode D.t)D.t)F.seq
   |ELam of 'a F.seq*'a coreNode D.t
 datatype eqnNode=EqnNVC of name*nameNode setNode D.t*nameNode setNode D.t
 type core=nameNode coreNode D.t
 type coreProgram=typeDef F.seq*(name*(nameNode F.seq*core)D.t)F.seq
 type atomicProgram=typeDef F.seq*core
 datatype ('a,'b)annNode=AVar of name|ANum of integer|AConstr of name
   |AAp of ('a,'b)ann*('a,'b)ann
   |ALet of bool D.t*('a D.t*('a,'b)ann)F.seq*('a,'b)ann
   |ACase of ('a,'b)ann*(name*('a F.seq*('a,'b)ann)D.t)F.seq
   |ALam of 'a F.seq*('a,'b)ann
 withtype ('a,'b)ann=('b D.t*('a,'b)annNode D.t)D.t
 type tvname=W.word F.seq*W.word F.seq
 datatype typeNode=TVar of tvname D.t|TArr of typeNode D.t*typeNode D.t
   |TCons of name*typeNode F.seq
 type texpr=typeNode D.t
 datatype schemeNode=Scheme of tvname F.seq*texpr
 type typeEnv=(name*schemeNode D.t)F.seq
 type subst=(tvname D.t*texpr)F.seq
 type fullTypeEnv=(name*texpr)F.seq
 datatype domainNode=Two|Lift1 of domainNode F.seq|Lift2 of domainNode F.seq
   |Func of domainNode F.seq*domainNode D.t
 type domain=domainNode D.t
 datatype routeNode=Zero|One|Stop1|Up1 of routeNode F.seq|Stop2|Up2
   |UpUp2 of routeNode F.seq|Rep of repNode D.t
 and repNode=RepTwo of frontierNode D.t|Rep1 of frontierNode D.t*repNode F.seq
   |Rep2 of frontierNode D.t*frontierNode D.t*repNode F.seq
 and frontierNode=Min1Max0 of integer*frontierElemNode F.seq*frontierElemNode F.seq
 and frontierElemNode=MkFrel of routeNode F.seq
 type route=routeNode D.t
 type representation=repNode D.t
 type frontier=frontierNode D.t
 type frontierElem=frontierElemNode D.t
 type point=domain*route
 datatype dexprNode=DXTwo|DXLift1 of dexprNode F.seq|DXLift2 of dexprNode F.seq
   |DXFunc of dexprNode F.seq*dexprNode D.t|DXVar of name
 type dexpr=dexprNode D.t
 datatype constructorNode=ConstrRec|ConstrVar of integer
 datatype acMode=Safe|Live
 datatype appInfoNode=A2|ALo1|AHi1 of integer*integer*domain
   |ALo2|AMid2|AHi2 of integer*integer*domain
 datatype 'a hexprNode=HApp of 'a hexprNode D.t*'a hexprNode D.t
   |HVAp of 'a hexprNode D.t*'a hexprNode F.seq
   |HLam of 'a F.seq*'a hexprNode D.t|HVar of 'a D.t
   |HMeet of 'a hexprNode F.seq|HPoint of route
   |HTable of(route*'a hexprNode D.t)F.seq
 type hexpr=nameNode hexprNode D.t
 datatype 'a exceptionIntNode=MkExInt of integer*'a F.seq
 type domainInt=domainNode exceptionIntNode D.t
 type oneFuncSize=integer*domainNode F.seq
 datatype infoNode=SAResult of name*domain*route
   |SASearch of acMode*name*integer*integer
   |SASizes of name*oneFuncSize F.seq*oneFuncSize F.seq
   |SAHExpr of name*hexpr|SASL of routeNode F.seq*routeNode F.seq
   |SAGiveUp of nameNode F.seq
 type token=integer*name
 datatype 'a parseNode=PFail of token C.seq|POk of 'a D.t*token C.seq
 type 'a parser=token C.seq->'a parseNode L.delay
 datatype partialNode=NoOp|FoundOp of name*core
 type limits=integer*integer*integer*integer*integer
 type static=(name*dexpr)F.seq*(name*domain)F.seq*(name*constructorNode F.seq)F.seq*
    (name*nameNode F.seq)F.seq*flags*limits*(domain*integer)F.seq
 fun force value=D.force value
 fun cell value=D.delay(fn()=>value)
 fun int n=cell(W.fromInt n)
 fun add a b=D.delay(fn()=>W.+(force a,force b))
 fun subtract a b=D.delay(fn()=>W.-(force a,force b))
 fun multiply a b=D.delay(fn()=>W.*(force a,force b))
 fun divide a b=D.delay(fn()=>S.divide(force a,force b))
 fun quotient a b=D.delay(fn()=>S.quotient(force a,force b))
 fun modulo a b=D.delay(fn()=>S.modulo(force a,force b))
 fun negative a=D.delay(fn()=>S.negate(force a))
 fun less a b=S.less(force a,force b)
 fun leq a b=S.leq(force a,force b)
 fun equalInt a b=force a=force b
 fun signed n=let val word=force n val magnitude=W.toLargeInt word
       val value=if S.negative word then magnitude-18446744073709551616 else magnitude
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value)end
 fun small n=let val word=force n
   in if S.negative word then ~(W.toInt(S.magnitude word))else W.toInt word end
 fun name s=F.fromList(String.explode s)
 fun string s=String.implode(F.toList s)
 fun empty()=F.empty()
 fun head xs=case force xs of F.Nil=>raise Empty|F.Cons(x,_)=>x
 fun tail xs=F.defer(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(_,rest)=>rest)
 fun null xs=case force xs of F.Nil=>true|_=>false
 fun singleton value=F.cons(value,F.empty())
 fun map f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.cons(D.delay(fn()=>force(f x)),map f rest))
 fun flatMap f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.append(f x)(flatMap f rest))
 fun pair a b=cell(a,b)
 fun triple a b c=cell(a,b,c)
 fun length xs=D.delay(fn()=>let
       fun loop n xs=case force xs of F.Nil=>n|F.Cons(_,rest)=>loop(W.+(n,0w1))rest
   in loop 0w0 xs end)
 fun compareLists compare xs ys=case(force xs,force ys)of
    (F.Nil,F.Nil)=>EQUAL|(F.Nil,_)=>LESS|(_,F.Nil)=>GREATER
   |(F.Cons(x,xt),F.Cons(y,yt))=>(case compare x y of EQUAL=>compareLists compare xt yt|answer=>answer)
 fun equalLists equal xs ys=case force xs of F.Nil=>null ys|F.Cons(x,xt)=>
   case force ys of F.Nil=>false|F.Cons(y,yt)=>equal x y andalso equalLists equal xt yt
 fun compareInt a b=if equalInt a b then EQUAL else if less a b then LESS else GREATER
 fun compareName xs ys=compareLists(fn a=>fn b=>Char.compare(force a,force b))xs ys
 fun equalName xs ys=equalLists(fn a=>fn b=>force a=force b)xs ys
 fun myFail message=raise Fail("\n"^message^"\n")
 fun panic message=raise Fail("\nPanic! (the "^String.str(Char.chr 96)^"impossible' happened):\n"^message^"\n")
