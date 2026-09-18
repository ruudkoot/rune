(* Translation from the elaborated AST to the Lambda IR. *)
structure Translate =
struct
  open Ast Lambda

  fun bug (sp, msg) = Error.bug (msg ^ " at " ^ Source.describe sp)

  fun sconConst sc = MatchComp.sconConst sc

  (* Domain type constructor of an operator: that of the first component for
     binary operators. *)
  fun operandTycon (t : Types.ty) : Types.tycon =
    let
      val opnd =
        case Types.resolve t of
          Types.TArrow (Types.TRecord ((_, a) :: _), _) => a
        | Types.TArrow (a, _) => a
        | _ => Error.bug "builtin operator without arrow type"
    in
      case Types.resolve opnd of
        Types.TCon (c, _) => c
      | _ => Types.intTycon    (* unconstrained: defaulted *)
    end

  (* Resolve a builtin operator at its instantiated type to a primitive. *)
  fun builtinPrim (name : string, ty : Types.ty) : string =
    case name of
      "=" => "poly_eq"
    | "<>" => "poly_eq"
    | ":=" => "ref_set"
    | "!" => "ref_get"
    | _ =>
        let val tc = operandTycon ty
        in
          case Overload.implOf (tc, name) of
            SOME (Overload.Prim prim) => prim
          | _ => Error.bug ("operator " ^ name ^ " at type " ^ #name tc)
        end

  (* The top-level variable that implements an overloaded operator at a type
     registered with _overload, if that is where the operator resolved to. *)
  fun builtinGlobal (name : string, ty : Types.ty) : int option =
    case name of
      "=" => NONE | "<>" => NONE | ":=" => NONE | "!" => NONE
    | _ => (case Overload.implOf (operandTycon ty, name) of
              SOME (Overload.Global g) => SOME g
            | _ => NONE)

  (* Variables bound to a primitive, `val op + = _prim "int_add" : int * int -> int`,
     or to such a variable, `val size = String.size`, by stamp. An application
     of one is translated like an application of the primitive itself; the
     variable still gets its closure, for the uses that are not applications. *)
  val primAliases : string IntMap.map ref = ref IntMap.empty

  fun primAliasOf (e : exp) : string option =
    case e of
      ETyped (e, _, _) => primAliasOf e
    | EPrim (name, _, _) => SOME name
    | EVar (_, ref (SOME (VGlobal s)), _) => IntMap.find (!primAliases, s)
    | EVar (_, ref (SOME (VLocal s)), _) => IntMap.find (!primAliases, s)
    | _ => NONE

  fun primArity name =
    case Prims.find name of
      SOME (_, a) => a
    | NONE => Error.bug ("unknown primitive " ^ name)

  (* Apply a primitive to an (already translated) argument expression. *)
  fun applyPrim (prim : string, arg : exp) : lexp =
    let
      val arity = primArity prim
    in
      case (arity, arg) of
        (1, _) => Prim (prim, [transExp arg])
      | (n, ETuple (es, _)) =>
          if List.length es = n then Prim (prim, List.map transExp es)
          else Error.bug "primitive applied to tuple of wrong size"
      | (n, _) =>
          let val t = MatchComp.freshVar ()
          in Let (t, transExp arg, Prim (prim, List.tabulate (n, fn i => Select (i, Var t)))) end
    end

  (* Eta-expand a primitive of the given arity. *)
  and etaPrim (prim : string) : lexp =
    let
      val arity = primArity prim
      val x = MatchComp.freshVar ()
    in
      if arity = 1 then Fn (x, Prim (prim, [Var x]))
      else Fn (x, Prim (prim, List.tabulate (arity, fn i => Select (i, Var x))))
    end

  and notExp e = If (e, falseExp, trueExp)

  (* A constructor as a value: a closure for constructors with arguments. *)
  and conExp (info : coninfo) : lexp =
    if #hasArg info then
      let val x = MatchComp.freshVar ()
      in if #isRef info then Fn (x, Prim ("ref_new", [Var x])) else Fn (x, Con (#tag info, Var x)) end
    else Con0 (#tag info)

  and exnExp (info : exninfo) : lexp =
    if #hasArg info then
      let val x = MatchComp.freshVar () in Fn (x, MkExn (exnConExp info, Var x)) end
    else MkExn (exnConExp info, Unit)

  and exnConExp info = MatchComp.exnConExp info

  and varinfo (slot : varinfo option ref, sp) =
    case !slot of
      SOME i => i
    | NONE => bug (sp, "variable not annotated")

  and recordIndex (slot : Types.ty option ref, lab, sp) : int =
    case !slot of
      SOME t =>
        (case Types.resolve t of
           Types.TRecord fields =>
             (case Types.labelIndex (fields, lab) of
                SOME i => i
              | NONE => bug (sp, "record selector label missing"))
         | _ => bug (sp, "record selector did not resolve to a record type"))
    | NONE => bug (sp, "record selector not annotated")

  and transExp (e : exp) : lexp =
    case e of
      EScon (sc, slot, _) => MatchComp.sconExp (sc, slot)
    | EVar (_, slot, sp) =>
        (case varinfo (slot, sp) of
           VLocal s => Var s
         | VGlobal s => Global s
         | VCon info => conExp info
         | VConVal info => conExp info
         | VExn info => exnExp info
         | VExnVal info => exnExp info
         | VBuiltin (name, ty) =>
             (case builtinGlobal (name, ty) of
                SOME g => Global g
              | NONE =>
                  let val prim = builtinPrim (name, ty)
                  in
                    if name = "<>" then
                      let val x = MatchComp.freshVar ()
                      in Fn (x, notExp (Prim (prim, [Select (0, Var x), Select (1, Var x)]))) end
                    else etaPrim prim
                  end))
    | ERecord (fields, _) =>
        let
          val sorted = Types.sortFields fields
          val inOrder = ListPair.all (fn ((l1, _), (l2, _)) => l1 = l2) (fields, sorted)
        in
          if inOrder then Tuple (List.map (fn (_, e) => transExp e) fields)
          else
            (* fields are evaluated in source order but stored in label order *)
            let
              val temps = List.map (fn (l, e) => (l, MatchComp.freshVar (), transExp e)) fields
              val tuple = Tuple (List.map (fn (l, _) =>
                                              case List.find (fn (l2, _, _) => l2 = l) temps of
                                                SOME (_, v, _) => Var v
                                              | NONE => Error.bug "record label") sorted)
            in List.foldr (fn ((_, v, e), body) => Let (v, e, body)) tuple temps end
        end
    | ETuple ([], _) => Unit
    | ETuple (es, _) => Tuple (List.map transExp es)
    | ESelect (lab, slot, sp) =>
        let val x = MatchComp.freshVar ()
        in Fn (x, Select (recordIndex (slot, lab, sp), Var x)) end
    | EList (es, _) => List.foldr (fn (e, acc) => Con (1, Tuple [transExp e, acc])) (Con0 0) es
    | ESeq (es, _) =>
        let
          fun go [] = Unit
            | go [e] = transExp e
            | go (e :: rest) = Seq (transExp e, go rest)
        in go es end
    | ELet (decs, body, _) => transDecs (decs, fn () => transExp body)
    | EApp (f, a, sp) => transApp (f, a, sp)
    | ETyped (e, _, _) => transExp e
    | EAndalso (a, b, _) => If (transExp a, transExp b, falseExp)
    | EOrelse (a, b, _) => If (transExp a, trueExp, transExp b)
    | EHandle (e, rules, _) =>
        let val x = MatchComp.freshVar ()
        in Handle (transExp e, x, MatchComp.compileMatch (x, transRules rules, Raise (Var x))) end
    | ERaise (e, _) => Raise (transExp e)
    | EIf (c, t, e, _) => If (transExp c, transExp t, transExp e)
    | EWhile (c, b, _) =>
        let
          val loop = MatchComp.freshVar ()
          val u = MatchComp.freshVar ()
        in
          LetRec ([(loop, Fn (u, If (transExp c, Seq (transExp b, App (Var loop, Unit)), Unit)))],
                  App (Var loop, Unit))
        end
    | ECase (e, rules, _) =>
        let val x = MatchComp.freshVar ()
        in Let (x, transExp e, MatchComp.compileMatch (x, transRules rules, raiseBuiltin exnMatch)) end
    | EFn (rules, _) =>
        let val x = MatchComp.freshVar ()
        in Fn (x, MatchComp.compileMatch (x, transRules rules, raiseBuiltin exnMatch)) end
    | EPrim (name, _, _) => etaPrim name

  and transRules rules = List.map (fn (p, e) => (p, transExp e)) rules

  and stripTyped (ETyped (e, _, _)) = stripTyped e
    | stripTyped e = e

  and transApp (f, a, sp) =
    case stripTyped f of
      EVar (_, slot, vsp) =>
        (case varinfo (slot, vsp) of
           VCon info => conApp (info, f, a)
         | VConVal info => conApp (info, f, a)
         | VExn info => exnApp (info, f, a)
         | VExnVal info => exnApp (info, f, a)
         | VBuiltin (name, ty) =>
             (case builtinGlobal (name, ty) of
                SOME g =>
                  (case IntMap.find (!primAliases, g) of
                     SOME prim => applyPrim (prim, a)
                   | NONE => App (Global g, transExp a))
              | NONE =>
                  let
                    val prim = builtinPrim (name, ty)
                    val call = applyPrim (prim, a)
                  in if name = "<>" then notExp call else call end)
         | _ =>
             (case primAliasOf f of
                SOME prim => applyPrim (prim, a)
              | NONE => App (transExp f, transExp a)))
    | EPrim (name, _, _) => applyPrim (name, a)
    | ESelect (lab, slot, ssp) => Select (recordIndex (slot, lab, ssp), transExp a)
    | _ => App (transExp f, transExp a)

  and conApp (info : coninfo, f, a) =
    if #hasArg info then
      (if #isRef info then Prim ("ref_new", [transExp a]) else Con (#tag info, transExp a))
    else App (transExp f, transExp a)

  and exnApp (info : exninfo, f, a) =
    if #hasArg info then MkExn (exnConExp info, transExp a) else App (transExp f, transExp a)

  (* ------------------------------------------------------------------ *)
  (* Declarations: k builds the continuation (the rest of the scope).     *)
  and transDecs (decs : dec list, k : unit -> lexp) : lexp =
    case decs of
      [] => k ()
    | d :: rest => transDec (d, fn () => transDecs (rest, k))

  and patInfo (slot : patinfo option ref, sp) =
    case !slot of
      SOME i => i
    | NONE => bug (sp, "binding not annotated")

  and transDec (d : dec, k : unit -> lexp) : lexp =
    case d of
      DVal (_, binds, _) =>
        let
          fun one ((p, e), k) =
            case p of
              PVar (_, slot, sp) =>
                (case patInfo (slot, sp) of
                   PIVar (stamp, g) =>
                     (case primAliasOf e of
                        SOME prim => primAliases := IntMap.insert (!primAliases, stamp, prim)
                      | NONE => ();
                      MatchComp.bindVar (stamp, g, transExp e, k ()))
                 | _ => general (p, e, k))
            | PWild _ => Seq (transExp e, k ())
            | _ => general (p, e, k)
          and general (p, e, k) =
            let val t = MatchComp.freshVar ()
            in Let (t, transExp e, MatchComp.compileMatch (t, [(p, k ())], raiseBuiltin exnBind)) end
          fun go [] = k ()
            | go (b :: rest) = one (b, fn () => go rest)
        in go binds end
    | DValRec (_, binds, _) =>
        let
          (* the first variable of each pattern carries the closure; the
             others are bound to it afterwards *)
          fun vars p =
            case recBindVars p of
              SOME (vs, _) => List.map (fn (_, slot, sp) => patInfo (slot, sp)) vs
            | NONE => bug (spanOfPat p, "val rec pattern")
          val groups = List.map (fn (p, e) => (vars p, transExp e)) binds
          val primaries =
            List.map (fn ([], e) => (PIVar (MatchComp.freshVar (), false), e)
                       | (v :: _, e) => (v, e)) groups
          fun aliases [] = k ()
            | aliases ((PIVar (s0, g0) :: rest, _) :: more) =
                List.foldr (fn (PIVar (s, g), body) =>
                                MatchComp.bindVar (s, g, if g0 then Global s0 else Var s0, body)
                             | (_, body) => body)
                           (aliases more) rest
            | aliases (_ :: more) = aliases more
        in transRecBindings (primaries, fn () => aliases groups) end
    | DFun (_, fundefs, _) =>
        let
          fun transFundef (f : fundef) =
            let
              val arity = case #clauses f of c :: _ => List.length (#pats c) | [] => 0
              val params = List.tabulate (arity, fn _ => MatchComp.freshVar ())
              val clauses = List.map (fn {pats, body, ...} => (pats, transExp body)) (#clauses f)
              val body = MatchComp.compileClauses (params, clauses, raiseBuiltin exnMatch)
            in
              (patInfo (#info f, #span f), List.foldr Fn body params)
            end
        in transRecBindings (List.map transFundef fundefs, k) end
    | DType _ => k ()
    | DDatatype _ => k ()
    | DDatatypeRepl _ => k ()
    | DAbstype (_, _, decs, _) => transDecs (decs, k)     (* dynamically local datatype ... in decs end *)
    | DException (exbinds, _) =>
        let
          fun go [] = k ()
            | go (ExnDecl (name, _, slot, sp) :: rest) =
              (case patInfo (slot, sp) of
                 PIExn info => MatchComp.bindVar (#stamp info, #isGlobal info, NewExn name, go rest)
               | _ => bug (sp, "exception declaration"))
            | go (ExnRepl _ :: rest) = go rest
        in go exbinds end
    | DLocal (d1, d2, _) => transDecs (d1, fn () => transDecs (d2, k))
    | DOpen _ => k ()
    | DInfix _ => k ()
    | DInfixr _ => k ()
    | DNonfix _ => k ()
    | DOverload _ => k ()
    | DStructure (binds, _) =>
        let
          fun go [] = k ()
            | go ((b : strbind) :: rest) = transStrexp (#strexp b, fn () => go rest)
        in go binds end
    | DSignature _ => k ()
    | DFunctor _ => k ()

  (* Structure expressions have no runtime representation of their own: a
     functor application evaluates its argument's declarations and then the
     elaborated copy of the functor body. *)
  and transStrexp (se : strexp, k : unit -> lexp) : lexp =
    case se of
      StrStruct (decs, _) => transDecs (decs, k)
    | StrId _ => k ()
    | StrAscribe (e, _, _, _) => transStrexp (e, k)
    | StrApp (_, arg, slot, sp) =>
        transStrexp (arg, fn () =>
          case !slot of
            SOME body => transStrexp (body, k)
          | NONE => bug (sp, "functor application not elaborated"))
    | StrLet (decs, e, _) => transDecs (decs, fn () => transStrexp (e, k))

  (* Recursive bindings: globals are assigned in sequence (closures refer to
     them through the global table); locals use LetRec. *)
  and transRecBindings (bs : (patinfo * lexp) list, k : unit -> lexp) : lexp =
    let
      fun isGlobal (PIVar (_, g), _) = g
        | isGlobal _ = Error.bug "recursive binding is not a variable"
      fun stampOf (PIVar (s, _), _) = s
        | stampOf _ = Error.bug "recursive binding is not a variable"
    in
      case bs of
        [] => k ()
      | _ =>
        if List.all isGlobal bs then
          List.foldr (fn ((pi, e), rest) => Seq (SetGlobal (stampOf (pi, e), e), rest)) (k ()) bs
        else LetRec (List.map (fn (pi, e) => (stampOf (pi, e), e)) bs, k ())
    end

  fun transProgram (decs : dec list) : lexp = transDecs (decs, fn () => Unit)
end
