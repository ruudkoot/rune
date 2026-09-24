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

  (* The name a function was given in the source, by the stamp of its
     parameter, which belongs to that function alone. The code generator puts
     it in the bytecode, where it is what a disassembly and a stack trace show
     (docs/bytecode.md, the function table); a function that no binding names
     keeps `fn`.
     `structPath` is the structures being translated, innermost first, so that
     the name is the one a reader would write. *)
  val funNames : string IntMap.map ref = ref IntMap.empty
  val structPath : string list ref = ref []

  fun qualified name = String.concatWith "." (List.rev (name :: !structPath))

  (* Name e and, where it is curried, the functions inside it: they are all
     the one function of the source. *)
  fun nameFun (name : string, e : lexp) : unit =
    let
      val q = qualified name
      fun go e =
        case unmark e of
          Fn (x, _, b) => (funNames := IntMap.insert (!funNames, x, q); go b)
        | _ => ()
    in go e end

  (* ---- types (docs/ir.md) ---- *)

  fun ty (slot : Types.ty option ref, sp) : Ty.ty =
    case !slot of
      SOME t => Ty.fromTypes t
    | NONE => bug (sp, "expression without a type")

  fun codomain (Ty.Arrow (_, b)) = b
    | codomain _ = Error.bug "a function type that is no arrow"

  (* Each variable's scheme, by its stamp, where it has a generic variable:
     a use of one says at which instance (Inst), unless it is the scheme
     itself, as a recursive call's is. *)
  datatype scheme = Mono | Poly of Ty.ty | Unknown
  val schemes : scheme IntMap.map ref = ref IntMap.empty
  fun schemeOf (stamp : int) : scheme =
    case IntMap.find (!schemes, stamp) of
      SOME s => s
    | NONE =>
        let
          fun has t =
            case t of
              Ty.Gen _ => true
            | Ty.Con (_, _, ts) => List.exists has ts
            | Ty.Tuple ts => List.exists has ts
            | Ty.Arrow (a, b) => has a orelse has b
            | _ => false
          val s = case IntMap.find (!Ty.binders, stamp) of
                    SOME t => let val t = Ty.fromTypes t in if has t then Poly t else Mono end
                  | NONE => Unknown
        in schemes := IntMap.insert (!schemes, stamp, s); s end

  (* A use of a variable at the type elaboration found for this use. *)
  fun useOf (e : lexp, stamp : int, t : Types.ty) : lexp =
    case schemeOf stamp of
      Mono => e
    | Poly s => let val i = Ty.fromTypes t in if Ty.equal (s, i) then e else Inst (e, i) end
    | Unknown => Inst (e, Ty.fromTypes t)

  (* A primitive an expression names, with its type at this use. *)
  fun primAliasOf (e : exp) : (string * Ty.ty) option =
    case e of
      ETyped (e, _, _) => primAliasOf e
    | EPrim (name, _, slot, sp) => SOME (name, ty (slot, sp))
    | EVar (_, ref (SOME (VGlobal (s, t))), _) => Option.map (fn p => (p, Ty.fromTypes t)) (IntMap.find (!primAliases, s))
    | EVar (_, ref (SOME (VLocal (s, t))), _) => Option.map (fn p => (p, Ty.fromTypes t)) (IntMap.find (!primAliases, s))
    | _ => NONE

  fun primArity name =
    case Prims.find name of
      SOME (_, a) => a
    | NONE => Error.bug ("unknown primitive " ^ name)

  (* Apply a primitive, of type pty at this use, to an (already translated)
     argument expression. *)
  fun applyPrim (prim : string, pty : Ty.ty, arg : exp) : lexp =
    let
      val arity = primArity prim
    in
      case (arity, arg) of
        (1, _) => Prim (prim, SOME pty, [transExp arg])
      | (n, ETuple (es, _)) =>
          if List.length es = n then Prim (prim, SOME pty, List.map transExp es)
          else Error.bug "primitive applied to tuple of wrong size"
      | (n, _) =>
          let val t = MatchComp.freshVar ()
          in Let (t, transExp arg, Prim (prim, SOME pty, List.tabulate (n, fn i => Select (i, Var t)))) end
    end

  (* Eta-expand a primitive of the given arity. *)
  and etaPrim (prim : string, pty : Ty.ty) : lexp =
    let
      val arity = primArity prim
      val x = MatchComp.freshVar ()
    in
      if arity = 1 then Fn (x, pty, Prim (prim, SOME pty, [Var x]))
      else Fn (x, pty, Prim (prim, SOME pty, List.tabulate (arity, fn i => Select (i, Var x))))
    end

  and notExp e = If (e, falseExp, trueExp)

  (* A constructor as a value, of type t at this use: a closure for
     constructors with arguments. *)
  and conExp (info : coninfo, t : Ty.ty) : lexp =
    if #hasArg info then
      let val x = MatchComp.freshVar ()
      in
        if #isRef info then Fn (x, t, Prim ("ref_new", SOME t, [Var x]))
        else Fn (x, t, Con (#tag info, codomain t, Var x))
      end
    else Con0 (#tag info, t)

  and exnExp (info : exninfo, t : Ty.ty) : lexp =
    if #hasArg info then
      let val x = MatchComp.freshVar () in Fn (x, t, MkExn (exnConExp info, Var x)) end
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

  (* An expression is translated under its own position, so that the code
     generator can say where each instruction came from. A mark that repeats
     the position already in force costs nothing in the bytecode.

     A variable, a constant, a selector and a `_prim` are left unmarked: none
     of them can fail or call, so the position of whatever contains them is
     the one worth having, and they are much the commonest expressions there
     are -- marking them cost 4% of the time it takes to compile. A type
     annotation covers the same ground as what it annotates. *)
  and transExp (e : exp) : lexp =
    case e of
      EScon _ => transExp' e
    | EVar _ => transExp' e
    | ESelect _ => transExp' e
    | EPrim _ => transExp' e
    | ETyped _ => transExp' e
    | _ => Mark (spanOfExp e, transExp' e)

  and transExp' (e : exp) : lexp =
    case e of
      EScon (sc, slot, _) => MatchComp.sconExp (sc, slot)
    | EVar (_, slot, sp) =>
        (case varinfo (slot, sp) of
           VLocal (s, t) => useOf (Var s, s, t)
         | VGlobal (s, t) => useOf (Global s, s, t)
         | VCon (info, t) => conExp (info, Ty.fromTypes t)
         | VConVal (info, t) => conExp (info, Ty.fromTypes t)
         | VExn (info, t) => exnExp (info, Ty.fromTypes t)
         | VExnVal (info, t) => exnExp (info, Ty.fromTypes t)
         | VBuiltin (name, ty) =>
             (case builtinGlobal (name, ty) of
                SOME g => useOf (Global g, g, ty)
              | NONE =>
                  let
                    val prim = builtinPrim (name, ty)
                    val t = Ty.fromTypes ty
                  in
                    if name = "<>" then
                      let val x = MatchComp.freshVar ()
                      in Fn (x, t, notExp (Prim (prim, SOME t, [Select (0, Var x), Select (1, Var x)]))) end
                    else etaPrim (prim, t)
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
        let
          val x = MatchComp.freshVar ()
          val i = recordIndex (slot, lab, sp)
          val r = ty (slot, sp)
          val field = case r of Ty.Tuple ts => List.nth (ts, i) | _ => bug (sp, "record selector of no record")
        in Fn (x, Ty.Arrow (r, field), Select (i, Var x)) end
    | EList (es, slot, sp) =>
        let val t = ty (slot, sp)
        in List.foldr (fn (e, acc) => Con (1, t, Tuple [transExp e, acc])) (Con0 (0, t)) es end
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
          (* the loop is a function of the translation, not of the source, so
             a trace calls it `while` rather than giving it a stamp *)
          val () = funNames := IntMap.insert (!funNames, u, "while")
          val t = Ty.Arrow (Ty.unit, Ty.unit)
        in
          LetRec ([(loop, t, Fn (u, t, If (transExp c, Seq (transExp b, App (Var loop, Unit)), Unit)))],
                  App (Var loop, Unit))
        end
    | ECase (e, rules, _) =>
        let val x = MatchComp.freshVar ()
        in Let (x, transExp e, MatchComp.compileMatch (x, transRules rules, raiseBuiltin exnMatch)) end
    | EFn (rules, slot, sp) =>
        let val x = MatchComp.freshVar ()
        in Fn (x, ty (slot, sp), MatchComp.compileMatch (x, transRules rules, raiseBuiltin exnMatch)) end
    | EPrim (name, _, slot, sp) => etaPrim (name, ty (slot, sp))

  and transRules rules = List.map (fn (p, e) => (p, transExp e)) rules

  and stripTyped (ETyped (e, _, _)) = stripTyped e
    | stripTyped e = e

  and transApp (f, a, sp) =
    case stripTyped f of
      EVar (_, slot, vsp) =>
        (case varinfo (slot, vsp) of
           VCon (info, t) => conApp (info, Ty.fromTypes t, f, a)
         | VConVal (info, t) => conApp (info, Ty.fromTypes t, f, a)
         | VExn (info, _) => exnApp (info, f, a)
         | VExnVal (info, _) => exnApp (info, f, a)
         | VBuiltin (name, ty) =>
             (case builtinGlobal (name, ty) of
                SOME g =>
                  (case IntMap.find (!primAliases, g) of
                     SOME prim => applyPrim (prim, Ty.fromTypes ty, a)
                   | NONE => App (useOf (Global g, g, ty), transExp a))
              | NONE =>
                  let
                    val prim = builtinPrim (name, ty)
                    val call = applyPrim (prim, Ty.fromTypes ty, a)
                  in if name = "<>" then notExp call else call end)
         | _ =>
             (case primAliasOf f of
                SOME (prim, t) => applyPrim (prim, t, a)
              | NONE => App (transExp f, transExp a)))
    | EPrim (name, _, slot, psp) => applyPrim (name, ty (slot, psp), a)
    | ESelect (lab, slot, ssp) => Select (recordIndex (slot, lab, ssp), transExp a)
    | _ => App (transExp f, transExp a)

  and conApp (info : coninfo, t : Ty.ty, f, a) =
    if #hasArg info then
      (if #isRef info then Prim ("ref_new", SOME t, [transExp a]) else Con (#tag info, codomain t, transExp a))
    else App (transExp f, transExp a)

  and exnApp (info : exninfo, f, a) =
    if #hasArg info then MkExn (exnConExp info, transExp a) else App (transExp f, transExp a)

  (* ------------------------------------------------------------------ *)
  (* Declarations: k builds the continuation (the rest of the scope).     *)
  and transDecs (decs : dec list, k : unit -> lexp) : lexp =
    case decs of
      [] => k ()
    | d :: rest => transDec (d, fn () => transDecs (rest, k))

  (* The same at the top level of the program and of its structures, where
     the continuation of each declaration is marked as the rest of the
     program: that is where Mid's top level splits it into definitions
     (ToMid), rather than nest the whole program once per declaration. *)
  and transTopDecs (decs : dec list, k : unit -> lexp) : lexp =
    case decs of
      [] => k ()
    | d :: rest => transTopDec (d, fn () => Rest (transTopDecs (rest, k)))

  and transTopDec (d : dec, k : unit -> lexp) : lexp =
    case d of
      DLocal (d1, d2, _) => transTopDecs (d1, fn () => transTopDecs (d2, k))
    | DAbstype (_, _, decs, _) => transTopDecs (decs, k)
    | _ => transDec (d, k)

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
              PVar ((_, vname), slot, sp) =>
                (case patInfo (slot, sp) of
                   PIVar (stamp, g) =>
                     (case primAliasOf e of
                        SOME (prim, _) => primAliases := IntMap.insert (!primAliases, stamp, prim)
                      | NONE => ();
                      let val e' = transExp e
                      in nameFun (vname, e'); MatchComp.bindVar (stamp, g, e', k ()) end)
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
          fun nameOf p = case recBindVars p of SOME ((n, _, _) :: _, _) => SOME n | _ => NONE
          val groups =
            List.map (fn (p, e) =>
                        let val e' = transExp e
                        in case nameOf p of SOME n => nameFun (n, e') | NONE => (); (vars p, e') end)
                     binds
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
              (* under the position of the declaration, so that the closure
                 is made where the function is written *)
              val fty =
                case patInfo (#info f, #span f) of
                  PIVar (stamp, _) =>
                    (case IntMap.find (!Ty.binders, stamp) of
                       SOME t => Ty.fromTypes t
                     | NONE => bug (#span f, "function without a type"))
                | _ => bug (#span f, "function declared as no variable")
              fun fns ([], _) = body
                | fns (x :: xs, t) = Fn (x, t, fns (xs, codomain t))
              val fn' = Mark (#span f, fns (params, fty))
              val () = nameFun (#name f, fn')
            in
              (patInfo (#info f, #span f), fn')
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
            | go ((b : strbind) :: rest) =
                let
                  val saved = !structPath
                  val () = structPath := #name b :: saved
                in
                  transStrexp (#strexp b, fn () => (structPath := saved; go rest))
                end
        in go binds end
    | DSignature _ => k ()
    | DFunctor _ => k ()

  (* Structure expressions have no runtime representation of their own: a
     functor application evaluates its argument's declarations and then the
     elaborated copy of the functor body. *)
  and transStrexp (se : strexp, k : unit -> lexp) : lexp =
    case se of
      StrStruct (decs, _) => transTopDecs (decs, k)
    | StrId _ => k ()
    | StrAscribe (e, _, _, _) => transStrexp (e, k)
    | StrApp (_, arg, slot, sp) =>
        transStrexp (arg, fn () =>
          case !slot of
            SOME body => transStrexp (body, k)
          | NONE => bug (sp, "functor application not elaborated"))
    | StrLet (decs, e, _) => transTopDecs (decs, fn () => transStrexp (e, k))

  (* Recursive bindings: globals are assigned in sequence (closures refer to
     them through the global table); locals use LetRec. *)
  and transRecBindings (bs : (patinfo * lexp) list, k : unit -> lexp) : lexp =
    let
      fun isGlobal (PIVar (_, g), _) = g
        | isGlobal _ = Error.bug "recursive binding is not a variable"
      fun stampOf (PIVar (s, _), _) = s
        | stampOf _ = Error.bug "recursive binding is not a variable"
      fun fnType e =
        case unmark e of
          Fn (_, t, _) => t
        | _ => Error.bug "recursive binding of what is no function"
    in
      case bs of
        [] => k ()
      | _ =>
        if List.all isGlobal bs then
          List.foldr (fn ((pi, e), rest) => Seq (SetGlobal (stampOf (pi, e), e), rest)) (k ()) bs
        else LetRec (List.map (fn (pi, e) => (stampOf (pi, e), fnType e, e)) bs, k ())
    end

  fun transProgram (decs : dec list) : lexp =
    (funNames := IntMap.empty; structPath := []; schemes := IntMap.empty; transTopDecs (decs, fn () => Unit))
end
