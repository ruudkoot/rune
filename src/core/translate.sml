(* Translation from the elaborated AST to the Lambda IR. *)
structure Translate =
struct
  open Ast Lambda

  fun bug (sp, msg) = Error.bug (msg ^ " at " ^ Source.describe sp)

  fun sconConst sc = MatchComp.sconConst sc

  fun tyconName (t : Types.ty) : string option =
    case Types.resolve t of
      Types.TCon (c, _) => SOME (#name c)
    | _ => NONE

  (* Domain type of an operator: first component for binary operators. *)
  fun operandTycon (t : Types.ty) : string =
    let
      val opnd =
        case Types.resolve t of
          Types.TArrow (Types.TRecord ((_, a) :: _), _) => a
        | Types.TArrow (a, _) => a
        | _ => Error.bug "builtin operator without arrow type"
    in
      case tyconName opnd of
        SOME n => n
      | NONE => "int"    (* unconstrained: defaulted *)
    end

  (* Resolve a builtin operator at its instantiated type to a primitive. *)
  fun builtinPrim (name : string, ty : Types.ty) : string =
    let
      val tc = operandTycon ty
      fun arith (i, w, r) =
        case tc of "int" => i | "word" => w | "real" => r
                 | _ => Error.bug ("operator " ^ name ^ " at type " ^ tc)
      fun cmp base =
        case tc of
          "int" => "int_" ^ base | "word" => "word_" ^ base | "real" => "real_" ^ base
        | "char" => "char_" ^ base | "string" => "string_" ^ base
        | _ => Error.bug ("comparison " ^ name ^ " at type " ^ tc)
    in
      case name of
        "+" => arith ("int_add", "word_add", "real_add")
      | "-" => arith ("int_sub", "word_sub", "real_sub")
      | "*" => arith ("int_mul", "word_mul", "real_mul")
      | "div" => arith ("int_div", "word_div", "")
      | "mod" => arith ("int_mod", "word_mod", "")
      | "/" => "real_div"
      | "~" => arith ("int_neg", "", "real_neg")
      | "abs" => arith ("int_abs", "", "real_abs")
      | "<" => cmp "lt" | "<=" => cmp "le" | ">" => cmp "gt" | ">=" => cmp "ge"
      | "=" => "poly_eq"
      | "<>" => "poly_eq"
      | ":=" => "ref_set"
      | "!" => "ref_get"
      | _ => Error.bug ("unknown builtin operator " ^ name)
    end

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
      EScon (sc, _) => Const (sconConst sc)
    | EVar (_, slot, sp) =>
        (case varinfo (slot, sp) of
           VLocal s => Var s
         | VGlobal s => Global s
         | VCon info =>
             if #hasArg info then
               let val x = MatchComp.freshVar ()
               in if #isRef info then Fn (x, Prim ("ref_new", [Var x])) else Fn (x, Con (#tag info, Var x)) end
             else Con0 (#tag info)
         | VExn info =>
             if #hasArg info then
               let val x = MatchComp.freshVar () in Fn (x, MkExn (exnConExp info, Var x)) end
             else MkExn (exnConExp info, Unit)
         | VBuiltin (name, ty) =>
             let val prim = builtinPrim (name, ty)
             in
               if name = "<>" then
                 let val x = MatchComp.freshVar ()
                 in Fn (x, notExp (Prim (prim, [Select (0, Var x), Select (1, Var x)]))) end
               else etaPrim prim
             end)
    | ERecord (fields, _) =>
        Tuple (List.map (fn (_, e) => transExp e) (Types.sortFields fields))
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
           VCon info =>
             if #hasArg info then
               (if #isRef info then Prim ("ref_new", [transExp a]) else Con (#tag info, transExp a))
             else App (transExp f, transExp a)
         | VExn info =>
             if #hasArg info then MkExn (exnConExp info, transExp a) else App (transExp f, transExp a)
         | VBuiltin (name, ty) =>
             let
               val prim = builtinPrim (name, ty)
               val call = applyPrim (prim, a)
             in if name = "<>" then notExp call else call end
         | _ => App (transExp f, transExp a))
    | EPrim (name, _, _) => applyPrim (name, a)
    | ESelect (lab, slot, ssp) => Select (recordIndex (slot, lab, ssp), transExp a)
    | _ => App (transExp f, transExp a)

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
                   PIVar (stamp, g) => MatchComp.bindVar (stamp, g, transExp e, k ())
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
          fun stamp (PVar (_, slot, sp)) = patInfo (slot, sp)
            | stamp (PTyped (p, _, _)) = stamp p
            | stamp p = bug (spanOfPat p, "val rec pattern")
          val bs = List.map (fn (p, e) => (stamp p, transExp e)) binds
        in transRecBindings (bs, k) end
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
    | DStructure (_, StrStruct (decs, _), _) => transDecs (decs, k)
    | DStructure (_, StrId _, _) => k ()

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
