(* Static environments for elaboration. *)
structure Env =
struct
  open Types

  datatype valstatus =
      Val of {scheme : scheme, stamp : int, global : bool}
    | Con of {scheme : scheme, info : Ast.coninfo}
    | Exn of {ty : ty, info : Ast.exninfo}
    | Prim of {scheme : scheme, name : string}          (* builtin (overloaded) operator *)
    | ConAsVal of {scheme : scheme, info : Ast.coninfo} (* constructor matched by a val specification: a plain value *)
    | ExnAsVal of {ty : ty, info : Ast.exninfo}         (* likewise for an exception constructor *)

  (* A type structure (Section 4.9): a type function and, for a datatype,
     its constructors (in declaration order). *)
  datatype tystatus = TyStr of {fcn : tyfcn, cons : (string * valstatus) list}

  datatype origin = Unknown | Named of {unit:string,kind:string,name:string,span:Source.span}
    | Constrained of origin * origin
  fun primary (Constrained (actual,_))=primary actual | primary origin=origin
  fun declaration (Constrained (_,spec))=declaration spec | declaration origin=origin
  fun constrain (actual,Unknown)=actual
    | constrain (actual,spec)=if actual=spec then actual else Constrained (actual,spec)
  val tracking=ref false
  val ()=CompilerState.cellRoot ("Env.tracking",tracking)
  val currentUnit=ref ""
  val ()=CompilerState.cellRoot ("Env.currentUnit",currentUnit)
  val applicationDepth=ref 0
  val ()=CompilerState.cellRoot ("Env.applicationDepth",applicationDepth)
  val observe : (string * (string list * string) * Source.span * origin * bool -> unit) ref = ref (fn _ => ())
  val ()=CompilerState.cellRoot ("Env.observe",observe)
  fun emit (kind,id,span,origin)=(!observe) (kind,id,span,origin,!applicationDepth>0)
  val stampOrigins : origin IntTable.table=IntTable.table 256
  val ()=CompilerState.tableRoot ("Env.stampOrigins",stampOrigins)
  val typeOrigins : origin IntMap.map ref=ref IntMap.empty
  val ()=CompilerState.cellRoot ("Env.typeOrigins",typeOrigins)
  fun noteType (constructor:Types.tycon,origin)=if !tracking then
    typeOrigins:=IntMap.insert (!typeOrigins,#stamp constructor,origin) else ()
  fun copyTypeOrigin (old:Types.tycon,fresh:Types.tycon)=if !tracking then
    Option.app (fn origin => noteType (fresh,origin)) (IntMap.find (!typeOrigins,#stamp old)) else ()
  fun originAt (kind,name,span)=if !tracking then Named {unit= !currentUnit,kind=kind,name=name,span=span} else Unknown
  fun noteStamp (stamp,name,span)=if !tracking then
    let val origin=originAt ("value",name,span)
    in IntTable.insert (stampOrigins,stamp,origin);emit ("def-v",([],name),span,origin) end else ()
  fun noteFunction (stamp,function:Ast.fundef) = if not (!tracking) then () else
    case Source.findFile (#file (#span function)) of NONE => () | SOME source =>
    let val {next,...}=Lexer.lexerOf (#mode source,#name source,#text source)
        fun matches (start,stop) =
          let fun loop offset=let val (token,span,after)=next offset
                in if #start span>=stop orelse token=Token.EOF then [] else
                     (case token of Token.ID name => if name= #name function andalso #stop span<=stop then [span] else [] | _ => []) @ loop after end
          in if stop<=start then [] else loop start end
        fun head (from,{pats,body,...}:Ast.clause) =
          let val found=case pats of [] => [] | first::_ =>
                (case matches (from,#start (Ast.spanOfPat first)) of [] =>
                   (case first of Ast.PTuple ([left,right],_, _) => matches (#stop (Ast.spanOfPat left),#start (Ast.spanOfPat right)) | _ => [])
                 | found => found)
          in (case found of span::_ => SOME span | [] => NONE,#stop (Ast.spanOfExp body)) end
        fun clauses (_,[])=[] | clauses (from,clause::rest)=
          let val (span,next)=head (from,clause) in (case span of NONE => [] | SOME span => [span]) @ clauses (next,rest) end
        val spans=clauses (#start (#span function),#clauses function)
    in case spans of [] => () | first::_ =>
      let val origin=originAt ("value",#name function,first)
      in IntTable.insert (stampOrigins,stamp,origin);List.app (fn span => emit ("def-v",([],#name function),span,origin)) spans end end

  datatype env = Env of {vals : valstatus StringMap.map, tys : tystatus StringMap.map, strs : env StringMap.map,
                        origins:origin StringMap.map}
  val observeScope : (Source.span * env -> unit) ref=ref (fn _ => ())
  val ()=CompilerState.cellRoot ("Env.observeScope",observeScope)
  fun noteScope (span,env)=if !tracking andalso !applicationDepth=0 then (!observeScope) (span,env) else ()
  val observeExpression : (Ast.exp * env -> unit) ref=ref (fn _ => ())
  val ()=CompilerState.cellRoot ("Env.observeExpression",observeExpression)
  fun noteExpression (expression,env)=if !tracking andalso !applicationDepth=0 then
    (noteScope (Ast.spanOfExp expression,env);(!observeExpression) (expression,env)) else ()

  val empty = Env {vals = StringMap.empty, tys = StringMap.empty, strs = StringMap.empty,origins=StringMap.empty}

  fun vals (Env e) = #vals e
  fun tys (Env e) = #tys e
  fun strs (Env e) = #strs e

  fun noEscape (first, sp, env : env) : unit =
    let
      fun value v =
        Types.noEscape (first, sp,
          case v of Val {scheme, ...} => scheme | Con {scheme, ...} => scheme
                  | Prim {scheme, ...} => scheme | ConAsVal {scheme, ...} => scheme
                  | Exn {ty, ...} => ty | ExnAsVal {ty, ...} => ty)
      fun tystr (TyStr {fcn, ...}) =
        case fcn of TName _ => () | TAbbrev (_, t) => Types.noEscape (first, sp, t)
    in
      StringMap.app value (vals env);
      StringMap.app tystr (tys env);
      StringMap.app (fn e => noEscape (first, sp, e)) (strs env)
    end

  fun origins (Env e)= #origins e
  fun clearOrigin (origins,key)=if StringMap.isEmpty origins then origins else StringMap.remove (origins,key)
  fun putOrigin (Env {vals,tys,strs,origins},kind,name,origin)=
    Env {vals=vals,tys=tys,strs=strs,origins=case origin of Unknown => clearOrigin (origins,kind ^ " " ^ name)
      | _ => StringMap.insert (origins,kind ^ " " ^ name,origin)}
  fun make {vals,tys,strs,origins} =
    Env {vals=vals,tys=tys,strs=strs,origins=if StringMap.isEmpty origins then origins else
      StringMap.filteri (fn (key,_) => case String.fields (fn c => c= #" ") key of
        ["v",name] => StringMap.member (vals,name) | ["t",name] => StringMap.member (tys,name)
      | ["s",name] => StringMap.member (strs,name) | _ => false) origins}
  fun bindVal (Env {vals,tys,strs,origins},name,value)=
    let val origin=if not (!tracking) then Unknown else
          case value of Val {stamp,...} => getOpt (IntTable.find (stampOrigins,stamp),Unknown) | _ => Unknown
    in putOrigin (Env {vals=StringMap.insert (vals,name,value),tys=tys,strs=strs,origins=origins},"v",name,origin) end
  fun bindTy (Env {vals,tys,strs,origins},name,value)=
    Env {vals=vals,tys=StringMap.insert (tys,name,value),strs=strs,origins=clearOrigin (origins,"t " ^ name)}
  fun bindStr (Env {vals,tys,strs,origins},name,value)=
    Env {vals=vals,tys=tys,strs=StringMap.insert (strs,name,value),origins=clearOrigin (origins,"s " ^ name)}
  fun bindValAt (env,name,value,span)=
    let val origin=originAt ("value",name,span)
        val ()=if !tracking then emit ("def-v",([],name),span,origin) else ()
    in putOrigin (bindVal (env,name,value),"v",name,origin) end
  fun bindTyAt (env,name,value,span)=
    let val origin=originAt ("type",name,span)
        val ()=if !tracking then emit ("def-t",([],name),span,origin) else ()
        val ()=if !tracking then (case value of TyStr {fcn=Types.TName constructor,...} =>
          if IntMap.member (!typeOrigins,#stamp constructor) then () else noteType (constructor,origin)
          | _ => ()) else ()
    in putOrigin (bindTy (env,name,value),"t",name,origin) end
  fun bindStrAt (env,name,value,span)=
    let val origin=originAt ("structure",name,span)
        val ()=if !tracking then emit ("def-s",([],name),span,origin) else ()
    in putOrigin (bindStr (env,name,value),"s",name,origin) end
  fun plus (Env e1,Env e2)=
    let val origins=if StringMap.isEmpty (#origins e1) andalso StringMap.isEmpty (#origins e2) then StringMap.empty else
          StringMap.unionWith #2 (StringMap.filteri (fn (key,_) => case String.fields (fn c => c= #" ") key of
            ["v",name] => not (StringMap.member (#vals e2,name))
          | ["t",name] => not (StringMap.member (#tys e2,name))
          | ["s",name] => not (StringMap.member (#strs e2,name)) | _ => true) (#origins e1),#origins e2)
    in Env {vals=StringMap.unionWith #2 (#vals e1,#vals e2),tys=StringMap.unionWith #2 (#tys e1,#tys e2),
      strs=StringMap.unionWith #2 (#strs e1,#strs e2),origins=origins} end

  (* Union of environments that must not overlap (rule 77: specifications). *)
  fun plusDisjoint (Env e1, Env e2, sp) =
    let
      fun check (what, m1, m2) =
        StringMap.appi (fn (n, _) =>
                           if StringMap.member (m1, n) then
                             Error.error (sp, "duplicate specification of " ^ what ^ " '" ^ n ^ "'")
                           else ()) m2
    in
      check ("value", #vals e1, #vals e2);
      check ("type", #tys e1, #tys e2);
      check ("structure", #strs e1, #strs e2);
      plus (Env e1, Env e2)
    end

  (* The usages of the cache (Usage; docs/units.md, The cache): a name
     looked up is recorded where what was found for it is the binding the
     environment a unit began in has for it (session), not one of the unit's
     own or of a scope within it, which shadowed it: a functor's parameter
     named Array does not use the Array of the units before. A structure is
     the session's where one of its bindings, a witness, is the session
     structure's: cheap, and wrong only towards recording. *)
  val session : env option ref = ref NONE
  val () = CompilerState.cellRoot ("Env.session", session)

  fun sameTy' (a : ty, b : ty) : bool =
    case (prune a, prune b) of
      (TVar r1, TVar r2) => r1 = r2
    | (TCon (c1, a1), TCon (c2, a2)) => #stamp c1 = #stamp c2 andalso ListPair.allEq sameTy' (a1, a2)
    | (TRecord f1, TRecord f2) => ListPair.allEq (fn ((l1, t1), (l2, t2)) => l1 = l2 andalso sameTy' (t1, t2)) (f1, f2)
    | (TArrow (a1, b1), TArrow (a2, b2)) => sameTy' (a1, a2) andalso sameTy' (b1, b2)
    | _ => false

  fun resultStamp (t : ty) : int =
    case prune t of TArrow (_, r) => resultStamp r | TCon (c, _) => #stamp c | _ => ~1

  fun sameBinding (a : valstatus, b : valstatus) : bool =
    case (a, b) of
      (Val x, Val y) => #stamp x = #stamp y
    | (Con x, Con y) => #tag (#info x) = #tag (#info y) andalso resultStamp (#scheme x) = resultStamp (#scheme y)
    | (ConAsVal x, ConAsVal y) => #tag (#info x) = #tag (#info y) andalso resultStamp (#scheme x) = resultStamp (#scheme y)
    | (Exn x, Exn y) => #stamp (#info x) = #stamp (#info y)
    | (ExnAsVal x, ExnAsVal y) => #stamp (#info x) = #stamp (#info y)
    | (Prim x, Prim y) => #name x = #name y
    | _ => false

  fun sameTyStr (TyStr a, TyStr b) : bool =
    case (#fcn a, #fcn b) of
      (TName c1, TName c2) => #stamp c1 = #stamp c2
    | (TAbbrev (i1, t1), TAbbrev (i2, t2)) => i1 = i2 andalso sameTy' (t1, t2)
    | _ => false

  (* a structure found is the session's s, by a witness of s's *)
  fun sameStr (found : env, s : env) : bool =
    case StringMap.firsti (vals s) of
      SOME (n, b) => (case StringMap.find (vals found, n) of SOME a => sameBinding (a, b) | NONE => false)
    | NONE =>
        case StringMap.firsti (tys s) of
          SOME (n, b) => (case StringMap.find (tys found, n) of SOME a => sameTyStr (a, b) | NONE => false)
        | NONE =>
            case StringMap.firsti (strs s) of
              SOME (n, b) => (case StringMap.find (strs found, n) of SOME a => sameStr (a, b) | NONE => false)
            | NONE => true

  (* name, of kind, found as found: recorded where that is the session's
     binding (ofSession), or where nothing was found (the compile then
     fails), or where there is no session *)
  fun useIf (kind : string, name : string, same : 'a * 'a -> bool, found : 'a option, ofSession : env -> 'a option) =
    if not (!Usage.recording) then ()
    else
      case (!session, found) of
        (NONE, _) => Usage.use (kind, name)
      | (_, NONE) => Usage.use (kind, name)
      | (SOME s, SOME a) => (case ofSession s of
                               SOME b => if same (a, b) then Usage.use (kind, name) else ()
                             | NONE => ())

  fun headStr (env, s) =
    useIf ("s", s, sameStr, StringMap.find (strs env, s), fn se => StringMap.find (strs se, s))

  fun findStr' (env, []) = SOME env
    | findStr' (env, s :: rest) =
      case StringMap.find (strs env, s) of
        SOME e => findStr' (e, rest)
      | NONE => NONE

  fun findStr (env, path) = (case path of s :: _ => headStr (env, s) | [] => (); findStr' (env, path))

  (* A long name is recorded whole (`v A.area`), where its first structure
     is the session's: a unit that used A.area used that entry, and not the
     rest of A (the incremental roadmap's M6, the third part) *)
  fun longUse (kind, env, s, path, name) =
    if not (!Usage.recording) then ()
    else useIf (kind, String.concatWith "." (path @ [name]), sameStr, StringMap.find (strs env, s),
                fn se => StringMap.find (strs se, s))

  fun originOf (env,kind,(path,name))=case findStr' (env,path) of NONE => Unknown
    | SOME env => getOpt (StringMap.find (origins env,kind ^ " " ^ name),Unknown)
  fun noteUse (env,kind,id as (path,_),span)=if not (!tracking) then () else
    let fun prefixes (_,[])=() | prefixes (prefix,name::rest)=
          (emit ("s",(prefix,name),span,originOf (env,"s",(prefix,name)));prefixes (prefix @ [name],rest))
    in emit (kind,id,span,originOf (env,kind,id));prefixes ([],path) end

  fun findVal (env, (path, name)) =
    case path of
      [] =>
        let val r = StringMap.find (vals env, name)
        in useIf ("v", name, sameBinding, r, fn s => StringMap.find (vals s, name)); r end
    | s :: _ => (longUse ("v", env, s, path, name); case findStr' (env, path) of
                                                    SOME e => StringMap.find (vals e, name)
                                                  | NONE => NONE)

  fun findTy (env, (path, name)) =
    case path of
      [] =>
        let val r = StringMap.find (tys env, name)
        in useIf ("t", name, sameTyStr, r, fn s => StringMap.find (tys s, name)); r end
    | s :: _ => (longUse ("t", env, s, path, name); case findStr' (env, path) of
                                                    SOME e => StringMap.find (tys e, name)
                                                  | NONE => NONE)

  (* The type name a type structure denotes: its own, or the one an
     abbreviation of no arguments stands for (`where type t = u` leaves an
     abbreviation behind). *)
  fun tyStrName (TyStr {fcn = TName c, ...}) = SOME c
    | tyStrName (TyStr {fcn = TAbbrev ([], t), ...}) =
        (case Types.resolve t of Types.TCon (c, []) => SOME c | _ => NONE)
    | tyStrName _ = NONE

  (* --- realisation of environments --- *)
  (* Each gives back what it is given where the realisation changes
     nothing in it, as Types.realize does (Types.changes). *)
  fun realizeVal (phi : realisation, v : valstatus) : valstatus =
    let val n = !changes
    in
      case v of
        Val {scheme, stamp, global} =>
          let val s = realize (phi, scheme) in if !changes = n then v else Val {scheme = s, stamp = stamp, global = global} end
      | Con {scheme, info} =>
          let val s = realize (phi, scheme) in if !changes = n then v else Con {scheme = s, info = info} end
      | Exn {ty, info} =>
          let val t = realize (phi, ty) in if !changes = n then v else Exn {ty = t, info = info} end
      | Prim {scheme, name} =>
          let val s = realize (phi, scheme) in if !changes = n then v else Prim {scheme = s, name = name} end
      | ConAsVal {scheme, info} =>
          let val s = realize (phi, scheme) in if !changes = n then v else ConAsVal {scheme = s, info = info} end
      | ExnAsVal {ty, info} =>
          let val t = realize (phi, ty) in if !changes = n then v else ExnAsVal {ty = t, info = info} end
    end

  fun realizeCons (phi : realisation, l : (string * valstatus) list) : (string * valstatus) list =
    case l of
      [] => l
    | (c, v) :: rest =>
        let
          val n = !changes
          val v' = realizeVal (phi, v)
          val rest' = realizeCons (phi, rest)
        in if !changes = n then l else (c, v') :: rest' end

  fun realizeTyStr (phi : realisation, ts as TyStr {fcn, cons}) : tystatus =
    let
      val n = !changes
      val fcn' = realizeFcn (phi, fcn)
      val cons' = realizeCons (phi, cons)
    in if !changes = n then ts else TyStr {fcn = fcn', cons = cons'} end

  fun changeCount () = !changes

  fun realizeEnv' (phi : realisation, e as Env {vals, tys, strs,origins}) : env =
    let
      val n = !changes
      val vals' = StringMap.mapKeep changeCount (fn v => realizeVal (phi, v)) vals
      val tys' = StringMap.mapKeep changeCount (fn t => realizeTyStr (phi, t)) tys
      val strs' = StringMap.mapKeep changeCount (fn s => realizeEnv' (phi, s)) strs
    in if !changes = n then e else Env {vals = vals', tys = tys', strs = strs',origins=origins} end

  (* with --pass-stats=elab, counted, and the nodes visited by the steps of
     type work taken, one for each (a prune) *)
  fun realizeEnv (phi : realisation, env : env) : env =
    if IntMap.isEmpty phi then (if !ElabStats.on then ElabStats.count ElabStats.Realize else (); env)
    else if not (!ElabStats.on) then realizeEnv' (phi, env)
    else
      let
        val left = !workLeft
        val r = realizeEnv' (phi, env)
      in
        ElabStats.count ElabStats.Realize; ElabStats.add (ElabStats.Nodes, left - !workLeft); r
      end

  (* --- initial environment --- *)
  fun generic (id, eq) = TVar (ref (Unbound {id = id, level = genericLevel, kind = KPlain, eq = eq}))
  fun overloaded (id, names) = TVar (ref (Unbound {id = id, level = genericLevel, kind = KOverload names, eq = false}))

  val a = generic (~1, false)
  val b = generic (~2, false)
  val eqa = generic (~3, true)          (* ''a: the type of = and <> (Appendix C) *)

  fun conInfo (name, tag, hasArg, siblings) : Ast.coninfo =
    {name = name, tag = tag, hasArg = hasArg, ncons = List.length siblings, isRef = false, siblings = siblings}

  val boolSiblings = [("false", false), ("true", false)]
  (* the list's constructors, their tags as Types.tagNames numbers them *)
  fun listSiblings () = List.map (fn n => (n, n = "::")) (listTagNames ())
  val boolCons =
    [("false", Con {scheme = boolTy, info = conInfo ("false", 0, false, boolSiblings)}),
     ("true", Con {scheme = boolTy, info = conInfo ("true", 1, false, boolSiblings)})]
  fun listConsNow () =
    [("nil", Con {scheme = listTy a, info = conInfo ("nil", nilTag (), false, listSiblings ())}),
     ("::", Con {scheme = TArrow (tupleTy [a, listTy a], listTy a), info = conInfo ("::", consTag (), true, listSiblings ())})]
  val refCons =
    [("ref", Con {scheme = TArrow (a, refTy a),
                  info = {name = "ref", tag = 0, hasArg = true, ncons = 1, isRef = true, siblings = [("ref", true)]}})]

  val builtinExns = ["Match", "Bind", "Overflow", "Div", "Subscript", "Size", "Chr", "Domain"]

  fun builtinExn (name, k) =
    (name, Exn {ty = exnTy, info = {name = name, stamp = ~1, isGlobal = true, hasArg = false, builtin = SOME k}})

  val numeric = ["int", "word", "real"]
  val ordered = ["int", "word", "real", "char", "string"]

  fun binop (name, class, id) =
    let val o' = overloaded (id, class)
    in (name, Prim {scheme = TArrow (tupleTy [o', o'], o'), name = name}) end
  fun unop (name, class, id) =
    let val o' = overloaded (id, class)
    in (name, Prim {scheme = TArrow (o', o'), name = name}) end
  fun strop (name, scheme, id) =
    let val s = overloaded (id, ["string"])
    in (name, Prim {scheme = scheme s, name = name}) end
  fun cmpop (name, class, id) =
    let val o' = overloaded (id, class)
    in (name, Prim {scheme = TArrow (tupleTy [o', o'], boolTy), name = name}) end

  fun builtinValsNow listCons =
    boolCons @ listCons @ refCons @
    List.rev (#1 (List.foldl (fn (n, (acc, k)) => (builtinExn (n, k) :: acc, k + 1)) ([], 0) builtinExns)) @
    [binop ("+", numeric, ~10), binop ("-", numeric, ~11), binop ("*", numeric, ~12),
     binop ("div", ["int", "word"], ~13), binop ("mod", ["int", "word"], ~14),
     binop ("/", ["real"], ~15),
     unop ("~", numeric, ~16), unop ("abs", ["int", "real"], ~17),
     cmpop ("<", ordered, ~18), cmpop ("<=", ordered, ~19), cmpop (">", ordered, ~20), cmpop (">=", ordered, ~21),
     ("=", Prim {scheme = TArrow (tupleTy [eqa, eqa], boolTy), name = "="}),
     ("<>", Prim {scheme = TArrow (tupleTy [eqa, eqa], boolTy), name = "<>"}),
     (":=", Prim {scheme = TArrow (tupleTy [refTy a, a], unitTy), name = ":="}),
     ("!", Prim {scheme = TArrow (refTy a, a), name = "!"}),
     (* the operations of the top level on strings, overloaded on the class
        String as the comparisons are: one type of the class throughout,
        resolved by the operands, `string` by default (docs/language.md,
        Deviations, Overloading) *)
     strop ("^", fn s => TArrow (tupleTy [s, s], s), ~22),
     strop ("size", fn s => TArrow (s, intTy), ~23),
     strop ("concat", fn s => TArrow (listTy s, s), ~24),
     strop ("substring", fn s => TArrow (tupleTy [s, intTy, intTy], s), ~25)]

  fun nameStr (c, cons) = TyStr {fcn = TName c, cons = cons}

  fun builtinTysNow listCons =
    [("int", nameStr (intTycon, [])),
     ("word", nameStr (wordTycon, [])),
     ("real", nameStr (realTycon, [])),
     ("char", nameStr (charTycon, [])),
     ("string", nameStr (stringTycon, [])),
     ("bool", nameStr (boolTycon, boolCons)),
     ("list", nameStr (listTycon, listCons)),
     ("ref", nameStr (refTycon, refCons)),
     ("exn", nameStr (exnTycon, [])),
     ("array", nameStr (arrayTycon, [])),
     ("vector", nameStr (vectorTycon, [])),
     (* `_prim "int64"` and `_prim "word64"` as types (the parser gives them
        these names, which no identifier of a program is) *)
     ("_int64", nameStr (int64Tycon, [])),
     ("_word64", nameStr (word64Tycon, [])),
     ("_bytearray", nameStr (bytearrayTycon, [])),
     ("_realarray", nameStr (realarrayTycon, [])),
     ("unit", TyStr {fcn = TAbbrev ([], unitTy), cons = []})]

  (* the initial basis, with the list's tags as Types.tagNames numbers
     them: what a compile begins with once its options are read *)
  fun initialNow () =
    let val listCons = listConsNow ()
    in
      Env {origins=StringMap.empty,vals = StringMap.fromList (builtinValsNow listCons),
           tys = StringMap.fromList (builtinTysNow listCons),
           strs = StringMap.empty}
    end
  val initial = initialNow ()

  (* ---- the names of types ---- *)

  (* the type constructor a type structure is, or abbreviates with its
     parameters in order *)
  fun tyconOf (TyStr {fcn, ...}) = Option.map #stamp (fcnIsName fcn)

  (* the shortest path that names the type constructor in env: its own name
     at the top where that is it, else the structures breadth first, a path
     that ends in its own name before one that does not, then the first in
     order; only names satisfying accepts are considered, and never a name of
     the initial basis that no program can write (`_int64`, which the
     library names Int64.int by) *)
  fun pathOfWhen (env : env, c : tycon, accepts : string -> bool) : string option =
    let
      val stamp = #stamp c
      fun named e n = case StringMap.find (tys e, n) of SOME ts => tyconOf ts = SOME stamp | NONE => false
      fun search ([], _) = NONE
        | search (_, 0) = NONE
        | search (level : (string * env) list, depth : int) =
            let
              fun own (p, e) = if named e (#name c) andalso accepts (p ^ #name c) then SOME (p ^ #name c) else NONE
              fun other (p, e) =
                StringMap.foldli (fn (n, ts, found) => case found of
                                                         SOME _ => found
                                                       | NONE => if tyconOf ts = SOME stamp andalso not (String.isPrefix "_" n)
                                                                    andalso accepts (p ^ n)
                                                                 then SOME (p ^ n) else NONE)
                                 NONE (tys e)
              (* the library's own structures (Rune...) after the others,
                 and the type's own long name (Int64.int, which FixedInt.int
                 is too) and then a structure named for the type (WideString
                 for its string, which WideChar's string is too) before the
                 rest *)
              fun private p = String.isPrefix "Rune" p orelse String.isPrefix "RUNE" p
              fun lower s = String.map Char.toLower s
              fun namedFor p =
                let val parts = String.tokens (fn ch => ch = #".") p
                in List.length parts >= 2
                   andalso String.isSubstring (lower (#name c)) (lower (List.nth (parts, List.length parts - 2)))
                end
              fun firstOf f =
                case List.mapPartial f level of
                  [] => NONE
                | found =>
                    let val public = List.filter (not o private) found
                        val pick = case (List.filter (fn p => p = #name c) public, List.filter namedFor public) of
                                     (p :: _, _) => [p]
                                   | ([], p :: _) => [p]
                                   | ([], []) => public
                    in SOME (case pick of p :: _ => p | [] => hd found) end
            in
              case firstOf own of
                SOME p => SOME p
              | NONE =>
                  case firstOf other of
                    SOME p => SOME p
                  | NONE =>
                      search (List.concat (List.map (fn (p, e) => StringMap.foldri (fn (n, s, acc) => (p ^ n ^ ".", s) :: acc)
                                                                                    [] (strs e)) level),
                              depth - 1)
            end
    in
      if named env (#name c) andalso accepts (#name c) then SOME (#name c) else search ([("", env)], 5)
    end

  fun pathOf (env : env, c : tycon) = pathOfWhen (env, c, fn _ => true)

  (* The name a message gives a type constructor, where the name it was
     declared under would not do: the path that reaches it from env, the top
     level, when that does not name it by its own name (`WideString.string`,
     where `string` is `String.string`). NONE where the top level names it so,
     and where no path reaches it (a type of a structure being elaborated):
     the declared name is printed then (Types.qualifier). *)
  fun qualifiedName (env : env, c : tycon) : string option =
    case pathOf (env, c) of
      SOME p => if p = #name c then NONE else SOME p
    | NONE => NONE
end
