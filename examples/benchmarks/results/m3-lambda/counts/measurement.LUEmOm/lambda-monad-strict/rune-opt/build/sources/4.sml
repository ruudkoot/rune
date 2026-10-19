(* Mark, marku@cs.waikato.ac.nz, November 2001: direct and state-monadic
   call-by-name interpreters. Source attribution and original terms retained. *)
functor BenchLambdaFn(D:BENCH_SUSPEND) =
struct
  datatype term =
      Var of string | Con of int D.t | Incr
    | Add of term D.t * term D.t | Lam of string * term D.t
    | App of term D.t * term D.t
    | IfZero of term D.t * term D.t * term D.t
    | Thunk of term D.t * environment D.t
  and environment = Empty | Binding of string * term D.t * environment D.t
  type 'a action = environment D.t -> 'a * environment D.t
  fun delay f=D.delay f
  fun node value=delay(fn()=>value)
  fun con n=node(Con(delay(fn()=>n)))
  fun variable name=node(Var name)
  fun add(a,b)=node(Add(a,b))
  fun lam(name,body)=node(Lam(name,body))
  fun app(a,b)=node(App(a,b))
  fun zero(c,a,b)=node(IfZero(c,a,b))
  val empty=delay(fn()=>Empty)
  fun lookup name env=case D.force env of
      Empty=>raise Fail("undefined lambda variable: "^name)
    | Binding(key,value,rest)=>if key=name then value else lookup name rest
  fun integer value=case D.force value of Con n=>D.force n
    |_=>raise Fail "lambda expected integer constant"
  (* Structural equality with Con 0 examines no fields of other constructors. *)
  fun isZero value=case D.force value of Con n=>D.force n=0|_=>false
  fun simple env value=delay(fn()=>D.force(case D.force value of
      Var name=>simple env(lookup name env)
    | Con _=>value
    | Incr=>con 0
    | Add(a,b)=>node(Con(delay(fn()=>integer(simple env a)+integer(simple env b))))
    | Lam _=>node(Thunk(value,env))
    | App(a,b)=>simpleApply env(simple env a)b
    | IfZero(c,a,b)=>simple env(if isZero(simple env c)then a else b)
    | Thunk(t,saved)=>simple saved t))
  and simpleApply original fnValue argument=delay(fn()=>
    case D.force fnValue of
      Thunk(f,saved)=>(case D.force f of
        Lam(name,body)=>D.force(simple(delay(fn()=>Binding(name,node(Thunk(argument,original)),saved)))body)
        |_=>raise Fail "bad direct lambda application")
    |_=>raise Fail "bad direct lambda application")
  fun return value env=(value,env)
  fun bind computation next env=
    let val(value,newEnv)=computation env in next value newEnv end
  fun current env=(env,env)
  fun lookupAction name env=(lookup name env,env)
  (* Strict State's withEnv returns evalState m tmp, restoring the caller's
     state; its result remains lazy until consumed in the lazy policy. *)
  fun withEnv tmp (computation:term D.t action) env=(delay(fn()=>D.force(#1(computation tmp))),env)
  fun push name value computation=
    bind current(fn env=>withEnv(delay(fn()=>Binding(name,value,env)))computation)
  fun traverse value env=
    case D.force value of
      Var name=>bind current(fn _=>bind(lookupAction name)traverse)env
    | Add(a,b)=>bind(traverseCon a)(fn x=>bind(traverseCon b)(fn y=>
        return(node(Con(delay(fn()=>D.force x+D.force y))))))env
    | Thunk(t,saved)=>withEnv saved(traverse t)env
    | Lam _=>bind current(fn saved=>return(node(Thunk(value,saved))))env
    | App(a,b)=>bind(traverse a)(fn f=>apply f b)env
    | IfZero(c,a,b)=>bind(traverse c)(fn v=>traverse(if isZero v then a else b))env
    | Con _=>return value env
    | Incr=>bind(return())(fn()=>return(con 0))env
  and traverseCon t env=
    let val(value,after)=traverse t env
    in (delay(fn()=>integer value),after)end
  and apply fnValue argument env=case D.force fnValue of
      Thunk(f,saved)=>(case D.force f of
        Lam(name,body)=>bind current(fn original=>
          withEnv saved(push name(node(Thunk(argument,original)))(traverse body)))env
        |_=>raise Fail "bad monadic lambda application")
    |_=>raise Fail "bad monadic lambda application"
  fun bracket outer this text=if this<=outer then "("^text^")"else text
  fun showInt n=if n<0 then "-"^Int.toString(~n)else Int.toString n
  fun pretty precedence value=case D.force value of
      Var name=>name
    | Con n=>showInt(D.force n)
    | Incr=>"INCR"
    | Lam(name,body)=>bracket precedence 0("@"^name^". "^pretty(~1)body)
    | Add(a,b)=>bracket precedence 1(pretty 1 a^" + "^pretty 1 b)
    | App(a,b)=>bracket precedence 2(pretty 2 a^" "^pretty 2 b)
    | IfZero(c,a,b)=>bracket precedence 0("IF "^pretty 0 c^" THEN "^pretty 0 a^" ELSE "^pretty 0 b)
    | Thunk(t,env)=>bracket precedence 0(pretty 3 t^"::"^prettyEnv env)
  and prettyEnv env=
    let fun entries e=case D.force e of Empty=>""|Binding(name,value,rest)=>
          name^"="^pretty 0 value^", "^entries rest
    in "["^entries env^"]"end
  fun simpleShow value=case D.force value of
      Con n=>"Con "^showInt(D.force n)
    |_=>raise Fail "source derived Show observation expects Con in selected profiles"
  val minusOne=add(variable"n",con ~1)
  val partialSum=lam("sum",lam("n",zero(variable"n",con 0,
    add(variable"n",app(variable"sum",minusOne)))))
  val lfxx=lam("x",app(variable"F",app(variable"x",variable"x")))
  val fix=lam("F",app(lfxx,lfxx))
  val sum0=app(fix,partialSum)
  fun evaluate style n=
    let val input=app(sum0,con n)
    in case style of "simple"=>simpleShow(simple empty input)^"\n"
      |"monad"=>let val(value,env)=traverse input empty
                in pretty 0 value^"  "^prettyEnv env^"\n"end
      |_=>raise Fail "lambda expects simple or monad interpreter"end
end
