signature INFER = sig val program : Syntax.decl list -> (Core.pattern * Core.expr) list end
structure Infer :> INFER =
struct
  open Types
  datatype location = Local of int | Builtin of int | Constructor of int
  type environment = (string * (ty * location)) list
  datatype typeBinding = Primitive of ty | Nominal of tycon
  fun program declarations =
    let
      val () = Types.reset ()
      val () = Source.warnings := []
      val next = ref 0 val nextType = ref 0 val nextConstructor = ref 0
      fun allocate counter p what = if !counter >= Source.maxCount then
          Source.fail p "limit" ("too many " ^ what)
        else let val n = !counter in counter := n+1; n end
      fun identity p = allocate next p "bindings"
      fun find env name = List.find (fn (s,_) => s = name) env
      fun lookup p env name = case find env name of
          SOME (_,value) => value
        | NONE => Source.fail p (if String.isSubstring "." name then "unsupported" else "scope")
            ("unbound name '" ^ name ^ "'")
      fun patterns env level ps =
        let val names = ref ([] : environment)
            fun constructor p name arg =
              case lookup p env name of
                (scheme,Constructor id) =>
                  let val t = instantiate p level scheme
                  in case (arg,root p t) of
                      (NONE,TData _) => Core.P (p,t,Core.ConstructorPattern (id,NONE))
                    | (SOME pat,TFunction (a,b)) =>
                        (unify p a (Core.patternType pat); Core.P (p,b,Core.ConstructorPattern (id,SOME pat)))
                    | _ => Source.fail p "type" "constructor pattern arity mismatch"
                  end
              | _ => Source.fail p "type" ("'" ^ name ^ "' is not a pattern constructor")
            fun pat depth (Syntax.P (p,node)) =
              let fun make t n = Core.P (p,t,n)
                  val () = if depth > 256 then Source.fail p "limit" "pattern tree exceeds depth 256" else ()
                  fun variable name =
                    if List.exists (fn (s,_) => s = name) (!names) then
                      Source.fail p "type" ("duplicate pattern name '" ^ name ^ "'")
                    else let val t = fresh p level val id = identity p
                         in names := (name,(t,Local id)):: !names; make t (Core.Bind id) end
              in case node of
                  Syntax.Variable name => (case find env name of
                      SOME (_,(_,Constructor _)) => constructor p name NONE
                    | _ => variable name)
                | Syntax.ConstructorPattern (name,arg) => constructor p name (SOME (pat (depth+1) arg))
                | Syntax.IntegerPattern n => make TInt (Core.IntegerPattern n)
                | Syntax.BooleanPattern b => make TBool (Core.BooleanPattern b)
                | Syntax.StringPattern s => make TString (Core.StringPattern s)
                | Syntax.Wildcard => make (fresh p level) Core.Wildcard
                | Syntax.UnitPattern => make TUnit Core.UnitPattern
                | Syntax.TuplePattern elements =>
                    let val pats = List.map (pat (depth+1)) elements
                    in make (TTuple (List.map Core.patternType pats)) (Core.TuplePattern pats) end
              end
            val pats = List.map (pat 0) ps
        in (pats,!names) end
      fun nonexpansive (Core.E (_,_,node)) = case node of
          Core.Integer _ => true | Core.Boolean _ => true | Core.String _ => true
        | Core.Unit => true | Core.Variable _ => true | Core.Builtin _ => true
        | Core.Constructor _ => true | Core.Function _ => true
        | Core.Tuple es => List.all nonexpansive es
        | Core.Apply (Core.E (_,_,Core.Constructor _),arg) => nonexpansive arg
        | _ => false
      fun irrefutable (Core.P (_,_,node)) = case node of
          Core.Bind _ => true | Core.Wildcard => true | Core.UnitPattern => true
        | Core.TuplePattern ps => List.all irrefutable ps | _ => false
      (* Function clauses are rows, not independent matches on each parameter. *)
      fun rowPattern _ [pat] = pat
        | rowPattern p pats = Core.P (p,TTuple (List.map Core.patternType pats),Core.TuplePattern pats)
      fun rawParameter (Core.P (p,t,_)) = Core.P (p,t,Core.Bind (identity p))
      fun argument (Core.P (p,t,Core.Bind id)) = Core.E (p,t,Core.Variable id)
        | argument _ = Source.fail Source.start "internal" "invalid raw parameter"
      fun datatypeBinding tenv level declarationPos variables datatypeName constructors =
        let
          fun distinct what names =
            let fun loop _ [] = () | loop seen (s::rest) =
                  if List.exists (fn x => x = s) seen then Source.fail declarationPos "type" ("duplicate " ^ what ^ " '" ^ s ^ "'")
                  else loop (s::seen) rest
            in loop [] names end
          val () = distinct "type parameter" variables
          val () = distinct "constructor" (List.map (fn (_,s,_) => s) constructors)
          val id = allocate nextType declarationPos "datatype identities"
          val eq = ref true val ids = ref ([] : int list)
          val declaredType = TypeConstructor {id=id,name=datatypeName,arity=List.length variables,
                                             equality=eq,constructors=ids}
          val tenv' = (datatypeName,Nominal declaredType)::tenv
          val params = List.map (fn s => let val t = fresh declarationPos (level+1)
                            val () = if String.isPrefix "''" s then equality declarationPos t else ()
                        in (s,t) end) variables
          fun translate depth (Syntax.Ty (p,node)) =
            if depth > 256 then Source.fail p "limit" "type expression exceeds depth 256"
            else case node of
                Syntax.TypeVariable s => (case find params s of SOME (_,t) => t
                  | NONE => Source.fail p "type" ("unbound type parameter '" ^ s ^ "'"))
              | Syntax.Arrow (a,b) => TFunction (translate (depth+1) a,translate (depth+1) b)
              | Syntax.Product ts => TTuple (List.map (translate (depth+1)) ts)
              | Syntax.TypeName (name,args) =>
                  let val ts = List.map (translate (depth+1)) args
                  in case find tenv' name of
                      SOME (_,Primitive t) => if null ts then t
                        else Source.fail p "type" "type constructor arity mismatch"
                    | SOME (_,Nominal (tc as TypeConstructor {arity,...})) =>
                        if List.length ts = arity then TData (tc,ts)
                        else Source.fail p "type" "type constructor arity mismatch"
                    | NONE => Source.fail p "type" ("unknown type constructor '" ^ name ^ "'")
                  end
          val result = TData (declaredType,List.map #2 params)
          val payloads = List.map (fn (p,s,arg) => (p,s,Option.map (translate 0) arg)) constructors
          val () = eq := List.all (fn (_,_,arg) => case arg of NONE => true
                      | SOME t => admits declarationPos t) payloads
          fun bind (p,s,arg) =
            let val id = 2 * allocate nextConstructor p "constructors" + (if Option.isSome arg then 1 else 0)
                val t = case arg of NONE => result | SOME a => TFunction (a,result)
                val () = generalize p level true t
            in ids := id :: !ids; (s,(t,Constructor id)) end
          val names = List.map bind payloads
          val () = ids := List.rev (!ids)
        in (names,tenv') end
      fun expression env tenv level depth (Syntax.E (p,node)) =
        if depth > 256 then Source.fail p "limit" "expression tree exceeds depth 256"
        else let fun sub e = expression env tenv level (depth+1) e
                 fun make t n = Core.E (p,t,n)
        in case node of
            Syntax.Integer n => make TInt (Core.Integer n)
          | Syntax.Boolean b => make TBool (Core.Boolean b)
          | Syntax.String s => make TString (Core.String s)
          | Syntax.Unit => make TUnit Core.Unit
          | Syntax.Name name =>
              let val (scheme,loc) = lookup p env name
              in make (instantiate p level scheme)
                 (case loc of Local id => Core.Variable id | Builtin id => Core.Builtin id
                   | Constructor id => Core.Constructor id) end
          | Syntax.Apply (f,a) =>
              let val f' = sub f val a' = sub a val result = fresh p level
                  val () = unify p (Core.typeOf f') (TFunction (Core.typeOf a',result))
              in make result (Core.Apply (f',a')) end
          | Syntax.Binary (oper,a,b) =>
              let val a' = sub a val b' = sub b
                  val at = Core.typeOf a' val bt = Core.typeOf b'
                  fun both t result = (unify p t at; unify p t bt; result)
                  val t = case oper of
                      "^" => both TString TString
                    | "=" => (unify p at bt; equality p at; TBool)
                    | "<>" => (unify p at bt; equality p at; TBool)
                    | "<" => both TInt TBool | "<=" => both TInt TBool
                    | ">" => both TInt TBool | ">=" => both TInt TBool
                    | _ => both TInt TInt
              in make t (Core.Binary (oper,a',b')) end
          | Syntax.If (c,a,b) =>
              let val c' = sub c val () = unify (Core.position c') TBool (Core.typeOf c')
                  val a' = sub a val b' = sub b
                  val () = unify p (Core.typeOf a') (Core.typeOf b')
              in make (Core.typeOf a') (Core.If (c',a',b')) end
          | Syntax.Tuple es =>
              let val es' = List.map sub es
              in make (TTuple (List.map Core.typeOf es')) (Core.Tuple es') end
          | Syntax.Case (subject,clauses) =>
              let val subject' = sub subject val result = fresh p level
                  fun clause (pat,body) =
                    let val (ps,names) = patterns env level [pat] val pat' = hd ps
                        val () = unify p (Core.typeOf subject') (Core.patternType pat')
                        val body' = expression (names @ env) tenv level (depth+1) body
                        val () = unify p result (Core.typeOf body')
                    in (pat',body') end
                  val clauses' = List.map clause clauses
                  val () = Match.check p true (List.map #1 clauses')
              in make result (Core.Case (subject',clauses')) end
          | Syntax.Fn [(pat,body)] =>
              let val (ps,names) = patterns env level [pat] val param = hd ps
                  val body' = expression (names @ env) tenv level (depth+1) body
                  val () = Match.check p true ps
              in make (TFunction (Core.patternType param,Core.typeOf body'))
                   (Core.Function {self=NONE,param=param,body=body'}) end
          | Syntax.Fn clauses =>
              let val input = fresh p level val result = fresh p level
                  fun clause (pat,body) =
                    let val (ps,names) = patterns env level [pat] val pat' = hd ps
                        val () = unify p input (Core.patternType pat')
                        val body' = expression (names @ env) tenv level (depth+1) body
                        val () = unify (Core.position body') result (Core.typeOf body')
                    in (pat',body') end
                  val clauses' = List.map clause clauses
                  val () = Match.check p true (List.map #1 clauses')
                  val param = rawParameter (#1 (hd clauses'))
                  val Core.P (matchPos,_,_) = param
                  val body = Core.E (matchPos,result,Core.Case (argument param,clauses'))
              in make (TFunction (input,result))
                   (Core.Function {self=NONE,param=param,body=body}) end
          | Syntax.Let (ds,body) =>
              let val first = !nextType
                  val (ds',env',tenv') = bindings false env tenv level (depth+1) ds
                  val body' = expression env' tenv' level (depth+1) body
                  val () = noEscape p first (Core.typeOf body')
                  val () = List.app (fn (_,(t,_)) => noEscape p first t) env
              in make (Core.typeOf body') (Core.Let (ds',body')) end
          | Syntax.Sequence es =>
              let val es' = List.map sub es
              in make (Core.typeOf (List.last es')) (Core.Sequence es') end
        end
      and bindings top initialEnv initialTypes level depth ds =
        let fun loop env tenv [] acc = (List.rev acc,env,tenv)
              | loop env tenv (Syntax.Datatype (p,vs,name,cs)::rest) acc =
                  let val () = List.app (fn (cp,c,_) => if c = "nil" then
                          Source.fail cp "type" "cannot rebind nil" else ()) cs
                      val (names,tenv') = datatypeBinding tenv level p vs name cs
                  in loop (names @ env) tenv' rest acc end
              | loop env tenv (d::rest) acc =
                let val (pat,e,env') = case d of
                    Syntax.Val (p,pat,e) =>
                      let val e' = expression env tenv (level+1) depth e
                          val (ps,names) = patterns env (level+1) [pat] val pat' = hd ps
                          val () = unify p (Core.patternType pat') (Core.typeOf e')
                          val () = Match.check p (not top) ps
                          val () = generalize p level (nonexpansive e') (Core.typeOf e')
                      in (pat',e',names @ env) end
                  | Syntax.Fun (p,name,clauses) =>
                      let val () = if name = "nil" then Source.fail p "type" "cannot rebind nil" else ()
                          val id = identity p val ft = fresh p (level+1)
                          val recursive = (name,(ft,Local id))::env
                          fun clause (cp,ps,body) =
                            let val (params,names) = patterns recursive (level+1) ps
                                val body' = expression (names @ recursive) tenv (level+1) (depth+1) body
                                val t = List.foldr (fn (param,t) => TFunction (Core.patternType param,t))
                                          (Core.typeOf body') params
                                val () = unify cp ft t
                            in (cp,params,body') end
                          val clauses' = List.map clause clauses
                          val () = Match.check p true (List.map (fn (cp,ps,_) => rowPattern cp ps) clauses')
                          val (_,params,body') = hd clauses'
                          (* Derived fun gathers every curried argument before testing patterns. *)
                          val single = List.length clauses' = 1
                          val direct = single andalso List.all irrefutable params
                          val raw = if direct then params else List.map rawParameter params
                          fun deferred ([],[],body) = body
                            | deferred (param::ps,(Core.P (rp,t,Core.Bind argumentId))::rs,body) =
                                Core.E (p,Core.typeOf body,Core.Case (Core.E (rp,t,Core.Variable argumentId),
                                  [(param,deferred (ps,rs,body))]))
                            | deferred _ = Source.fail p "internal" "invalid deferred parameter"
                          val matched = if direct then body'
                            else if single then deferred (params,raw,body')
                            else let val args = List.map argument raw
                                     val subject = case args of [arg] => arg
                                       | _ => Core.E (p,TTuple (List.map Core.typeOf args),Core.Tuple args)
                                     val matches = List.map (fn (cp,ps,e) => (rowPattern cp ps,e)) clauses'
                                 in Core.E (p,Core.typeOf body',Core.Case (subject,matches)) end
                          fun curry [] = matched
                            | curry (param::rest) =
                                let val inner = curry rest
                                in Core.E (p,TFunction (Core.patternType param,Core.typeOf inner),
                                     Core.Function {self=NONE,param=param,body=inner}) end
                          val (param,curriedBody,t) = case curry raw of
                              Core.E (_,t,Core.Function {param,body=curriedBody,...}) => (param,curriedBody,t)
                            | _ => Source.fail p "internal" "recursive function without parameters"
                          val () = unify p ft t
                          val () = generalize p level true ft
                          val e' = Core.E (p,ft,Core.Function {self=SOME id,param=param,body=curriedBody})
                      in (Core.P (p,ft,Core.Bind id),e',(name,(ft,Local id))::env) end
                  | Syntax.Datatype _ => Source.fail Source.start "internal" "misplaced datatype"
                in loop env' tenv rest ((pat,e)::acc) end
        in loop initialEnv initialTypes ds [] end
      val basisTypes = [("int",Primitive TInt),("bool",Primitive TBool),
                        ("string",Primitive TString),("unit",Primitive TUnit)]
      (* Lists use exactly the same nominal types and constructor descriptors as
         user datatypes. Install them before user declarations to reserve IDs. *)
      val p = Source.start
      val a = Syntax.Ty (p,Syntax.TypeVariable "'a")
      val list = Syntax.Ty (p,Syntax.TypeName ("list",[a]))
      val (listValues,initialTypes) = datatypeBinding basisTypes 0 p ["'a"] "list"
        [(p,"nil",NONE),(p,"::",SOME (Syntax.Ty (p,Syntax.Product [a,list])))]
      val basis = listValues @ [("print", (TFunction (TString,TUnit), Builtin 0)),
                   ("Int.toString", (TFunction (TInt,TString), Builtin 1)),
                   ("not", (TFunction (TBool,TBool), Builtin 2)),
                   ("~", (TFunction (TInt,TInt), Builtin 3))]
      val (program,_,_) = bindings true basis initialTypes 0 0 declarations
    in program end
end
