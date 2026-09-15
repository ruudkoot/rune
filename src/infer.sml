signature INFER = sig val program : Syntax.decl list -> (Core.pattern * Core.expr) list end
structure Infer :> INFER =
struct
  open Types
  datatype location = Local of int | Builtin of int
  type environment = (string * (ty * location)) list
  fun program declarations =
    let
      val () = Types.reset ()
      val next = ref 0
      fun identity p = if !next >= Source.maxCount then Source.fail p "limit" "too many bindings"
        else let val n = !next in next := n+1; n end
      fun lookup p env name = case List.find (fn (s,_) => s = name) env of
          SOME (_,value) => value
        | NONE => Source.fail p (if String.isSubstring "." name then "unsupported" else "scope")
            ("unbound name '" ^ name ^ "'")
      fun patterns level ps =
        let val names = ref ([] : (string * (ty * location)) list)
            fun pat (Syntax.P (p,node)) =
              let fun make t n = Core.P (p,t,n)
              in case node of
                  Syntax.Variable name =>
                    if List.exists (fn (s,_) => s = name) (!names) then
                      Source.fail p "type" ("duplicate pattern name '" ^ name ^ "'")
                    else let val t = fresh p level val id = identity p
                         in names := (name,(t,Local id)):: !names; make t (Core.Bind id) end
                | Syntax.Wildcard => make (fresh p level) Core.Wildcard
                | Syntax.UnitPattern => make TUnit Core.UnitPattern
                | Syntax.TuplePattern ps =>
                    let val pats = List.map pat ps
                    in make (TTuple (List.map Core.patternType pats)) (Core.TuplePattern pats) end
              end
            val pats = List.map pat ps
        in (pats,!names) end
      fun nonexpansive (Syntax.E (_,node)) = case node of
          Syntax.Integer _ => true | Syntax.Boolean _ => true | Syntax.String _ => true
        | Syntax.Unit => true | Syntax.Name _ => true | Syntax.Fn _ => true
        | Syntax.Tuple es => List.all nonexpansive es | _ => false
      fun expression env level depth (Syntax.E (p,node)) =
        if depth > 256 then Source.fail p "limit" "expression tree exceeds depth 256"
        else let fun sub e = expression env level (depth+1) e
                 fun make t n = Core.E (p,t,n)
        in case node of
            Syntax.Integer n => make TInt (Core.Integer n)
          | Syntax.Boolean b => make TBool (Core.Boolean b)
          | Syntax.String s => make TString (Core.String s)
          | Syntax.Unit => make TUnit Core.Unit
          | Syntax.Name name =>
              let val (scheme,loc) = lookup p env name
              in make (instantiate p level scheme)
                 (case loc of Local id => Core.Variable id | Builtin id => Core.Builtin id) end
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
          | Syntax.Fn (pat,body) =>
              let val (ps,names) = patterns level [pat] val param = hd ps
                  val body' = expression (names @ env) level (depth+1) body
              in make (TFunction (Core.patternType param,Core.typeOf body'))
                   (Core.Function {self=NONE,param=param,body=body'}) end
          | Syntax.Let (ds,body) =>
              let val (ds',env') = bindings env level (depth+1) ds
                  val body' = expression env' level (depth+1) body
              in make (Core.typeOf body') (Core.Let (ds',body')) end
          | Syntax.Sequence es =>
              let val es' = List.map sub es
              in make (Core.typeOf (List.last es')) (Core.Sequence es') end
        end
      and bindings env level depth ds =
        let fun loop env [] acc = (List.rev acc,env)
              | loop env (d::rest) acc =
                let val (pat,e,env') = case d of
                    Syntax.Val (p,pat,e) =>
                      let val e' = expression env (level+1) depth e
                          val (ps,names) = patterns (level+1) [pat] val pat' = hd ps
                          val () = unify p (Core.patternType pat') (Core.typeOf e')
                          val () = generalize p level (nonexpansive e) (Core.typeOf e')
                      in (pat',e',names @ env) end
                  | Syntax.Fun (p,name,ps,body) =>
                      let val id = identity p val ft = fresh p (level+1)
                          val (params,names) = patterns (level+1) ps
                          val recursive = (name,(ft,Local id))::env
                          val body' = expression (names @ recursive) (level+1) (depth+1) body
                          fun curry [] = body'
                            | curry (param::rest) =
                                let val inner = curry rest
                                in Core.E (p,TFunction (Core.patternType param,Core.typeOf inner),
                                     Core.Function {self=NONE,param=param,body=inner}) end
                          val (param,body,t) = case curry params of
                              Core.E (_,t,Core.Function {param,body,...}) => (param,body,t)
                            | _ => Source.fail p "internal" "recursive function without parameters"
                          val () = unify p ft t
                          val () = generalize p level true ft
                          val e' = Core.E (p,ft,Core.Function {self=SOME id,param=param,body=body})
                      in (Core.P (p,ft,Core.Bind id),e',(name,(ft,Local id))::env) end
                in loop env' rest ((pat,e)::acc) end
        in loop env ds [] end
      val basis = [("print", (TFunction (TString,TUnit), Builtin 0)),
                   ("Int.toString", (TFunction (TInt,TString), Builtin 1)),
                   ("not", (TFunction (TBool,TBool), Builtin 2)),
                   ("~", (TFunction (TInt,TInt), Builtin 3))]
    in #1 (bindings basis 0 0 declarations) end
end
