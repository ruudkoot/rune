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
        (* concat: the operand is a list of strings *)
        Types.TCon (c, [a]) =>
          if #stamp c = #stamp Types.listTycon
          then (case Types.resolve a of Types.TCon (c', _) => c' | _ => Types.stringTycon)
          else c
      | Types.TCon (c, _) => c
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
  val () = CompilerState.cellRoot ("Translate.primAliases", primAliases)

  (* Compiler.addPrettyPrinter (docs/repl.md, Printers of one's own): where
     the REPL compiles, the global of RuneShow.addPrinterAt, which an
     application of it becomes, given the name of the type its printer
     prints; and that name of a type name's stamp, the same from session to
     session (UnitBasis.stableName). Elsewhere it does nothing. *)
  val printerTarget : int option ref = ref NONE
  val () = CompilerState.cellRoot ("Translate.printerTarget", printerTarget)
  val printerKey : (int -> string option) ref = ref (fn _ => NONE)
  val () = CompilerState.cellRoot ("Translate.printerKey", printerKey)

  (* the stamp of the type a printer of addPrettyPrinter's type prints *)
  fun printedTycon (t : Types.ty) : int option =
    let
      fun arrow t = case Types.prune t of Types.TArrow (a, b) => SOME (a, b) | _ => NONE
    in
      case arrow t of
        SOME (pp, _) =>
          (case Option.mapPartial (arrow o #2) (arrow pp) of
             SOME (_, rest) =>
               (case arrow rest of
                  SOME (b, _) => (case Types.prune b of Types.TCon (c, _) => SOME (#stamp c) | _ => NONE)
                | NONE => NONE)
           | NONE => NONE)
      | NONE => NONE
    end

  (* The name a function was given in the source, by the stamp of its
     parameter, which belongs to that function alone. The code generator puts
     it in the bytecode, where it is what a disassembly and a stack trace show
     (docs/bytecode.md, the function table); a function that no binding names
     keeps `fn`.
     `structPath` is the structures being translated, innermost first, so that
     the name is the one a reader would write. *)
  val funNames : string IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Translate.funNames", funNames)
  val structPath : string list ref = ref []
  val () = CompilerState.cellRoot ("Translate.structPath", structPath)

  (* --functors=functions: whether what is translated is a functor's body,
     whose declarations are its function's, no rest of the program in them *)
  val inBody = ref false
  val () = CompilerState.cellRoot ("Translate.inBody", inBody)
  (* the local variables read so far: a record's slot a body sets is one of
     them (bindUsed), the rest of the body having been made first *)
  val read : unit IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Translate.read", read, IntTable.copy)
  fun noteRead (x : int) = IntTable.insert (!read, x, ())
  val () = MatchComp.noteLocal := noteRead
  fun wasRead (x : int) = isSome (IntTable.find (!read, x))

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

  fun codomain t = case Ty.view t of Ty.Arrow (_, b) => b | _ => Error.bug "a function type that is no arrow"

  (* Each variable's scheme, by its stamp, where it has a generic variable:
     a use of one says at which instance (Inst), unless it is the scheme
     itself, as a recursive call's is. *)
  datatype scheme = Mono | Poly of Ty.ty | Unknown
  val schemes : scheme IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Translate.schemes", schemes, IntTable.copy)
  fun schemeOf (stamp : int) : scheme =
    case IntTable.find (!schemes, stamp) of
      SOME s => s
    | NONE =>
        let
          fun has t = not (List.null (Ty.gens t))
          val s = case IntTable.find (Ty.binders, stamp) of
                    SOME t => let val t = Ty.fromTypes t in if has t then Poly t else Mono end
                  | NONE => Unknown
        in IntTable.insert (!schemes, stamp, s); s end

  (* A use of a variable at the type elaboration found for this use. *)
  (* a type with its generic variables made unit: an instance of a scheme
     that changes nothing of a value of it (a dynamic module's slots) *)
  fun monoOf (t : Types.ty) : Types.ty =
    case Types.prune t of
      t' as Types.TVar (ref (Types.Unbound {level, ...})) => if level = Types.genericLevel then Types.unitTy else t'
    | Types.TCon (c, args) => Types.TCon (c, List.map monoOf args)
    | Types.TRecord fs => Types.TRecord (List.map (fn (l, a) => (l, monoOf a)) fs)
    | Types.TArrow (a, b) => Types.TArrow (monoOf a, monoOf b)
    | t' => t'

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
    (* `val size = size`, and the like, of an operation of the top level on
       strings (`^`, `size`, `concat`, `substring`) that resolved to a
       primitive, the 8-bit one's *)
    | EVar (_, ref (SOME (VBuiltin (name, t))), _) =>
        if List.exists (fn n => n = name) ["^", "size", "concat", "substring"]
           andalso not (isSome (builtinGlobal (name, t)))
        then SOME (builtinPrim (name, t), Ty.fromTypes t)
        else NONE
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
           VLocal (s, t) => (noteRead s; useOf (Var s, s, t))
         | VGlobal (s, t) => useOf (Global s, s, t)
         | VCon (info, t) => conExp (info, Ty.fromTypes t)
         | VConVal (info, t) => conExp (info, Ty.fromTypes t)
         | VExn (info, t) => exnExp (info, Ty.fromTypes t)
         | VExnVal (info, t) => exnExp (info, Ty.fromTypes t)
         | VBuiltin (name, ty) => builtinValue (name, ty))
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
          val field = case Ty.view r of Ty.Tuple ts => List.nth (ts, i) | _ => bug (sp, "record selector of no record")
        in Fn (x, Ty.arrow (r, field), Select (i, Var x)) end
    | EList (es, slot, sp) =>
        let val t = ty (slot, sp)
        in List.foldr (fn (e, acc) => Con (Types.consTag (), t, Tuple [transExp e, acc])) (Con0 (Types.nilTag (), t)) es end
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
          val t = Ty.arrow (Ty.unit, Ty.unit)
        in
          LetRec ([(loop, t, Fn (u, t, If (transExp c, Seq (transExp b, App (Var loop, Unit)), Unit)))],
                  App (Var loop, Unit))
        end
    | ECase (e, rules, sp) =>
        let val x = MatchComp.freshVar ()
        in Let (x, transExp e, MatchComp.compileMatch (x, transRules rules, Mark (sp, raiseBuiltin exnMatch))) end
    | EFn (rules, slot, sp) =>
        let val x = MatchComp.freshVar ()
        in Fn (x, ty (slot, sp), MatchComp.compileMatch (x, transRules rules, Mark (sp, raiseBuiltin exnMatch))) end
    | EPrim (name, _, slot, sp) => etaPrim (name, ty (slot, sp))

  (* a built-in operator, at its type here, as a value *)
  and builtinValue (name : string, ty : Types.ty) : lexp =
    case builtinGlobal (name, ty) of
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
        end

  and transRules rules = List.map (fn (p, e) => (p, transExp e)) rules

  and stripTyped (ETyped (e, _, _)) = stripTyped e
    | stripTyped e = e

  (* an application of a variable: of a primitive it names, or of a function *)
  and varApp (f, t : Types.ty, a) =
    case primAliasOf f of
      SOME ("repl_printer_add", _) => printerAdd (t, a)
    | SOME (prim, pt) => applyPrim (prim, pt, a)
    | NONE => App (transExp f, transExp a)

  (* Compiler.addPrettyPrinter, of type t here, applied to a: where the REPL
     compiles and the type printed is known and named, RuneShow.addPrinterAt
     (name, a); otherwise a, for its effects, and nothing installed *)
  and printerAdd (t : Types.ty, a) =
    case (!printerTarget, Option.mapPartial (fn s => !printerKey s) (printedTycon t)) of
      (SOME g, SOME key) =>
        let
          val pp = case Types.prune t of Types.TArrow (pp, _) => pp | _ => Error.bug "addPrettyPrinter's type"
          val targetTy = Types.TArrow (Types.TRecord [("1", Types.stringTy), ("2", pp)], Types.unitTy)
        in
          App (useOf (Global g, g, targetTy),
               Tuple [Const (CString key, Ty.fromTypes Types.stringTy), transExp a])
        end
    | _ => Seq (transExp a, Unit)

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
         | VGlobal (_, t) => varApp (f, t, a)
         | VLocal (_, t) => varApp (f, t, a))
    | EPrim ("repl_printer_add", _, slot, psp) =>
        (case !slot of SOME t => printerAdd (t, a) | NONE => bug (psp, "expression without a type"))
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
    if !inBody then transDecs (decs, k) else
    case decs of
      [] => k ()
    | d :: rest =>
        (Types.startWorkOn ("type translation", spanOfDec d);
         transTopDec (d, fn () => Rest (transTopDecs (rest, k))))

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
            in Let (t, transExp e, MatchComp.compileMatch (t, [(p, k ())], Mark (spanOfPat p, raiseBuiltin exnBind))) end
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
              val body = MatchComp.compileClauses (params, clauses, Mark (#span f, raiseBuiltin exnMatch))
              (* under the position of the declaration, so that the closure
                 is made where the function is written *)
              val fty =
                case patInfo (#info f, #span f) of
                  PIVar (stamp, _) =>
                    (case IntTable.find (Ty.binders, stamp) of
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
    | DFunctor (binds, _) =>
        if not (!Elaborate.functorFunctions) then k ()
        else
          let fun go [] = k () | go (b :: rest) = functorFun (b, go rest)
          in go binds end

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
          case if !Elaborate.functorFunctions then Elaborate.callAt sp else NONE of
            SOME call => callExp (call, sp, k)
          | NONE =>
          case !slot of
            SOME body => transStrexp (body, k)
          | NONE => bug (sp, "functor application not elaborated"))
    | StrLet (decs, e, _) => transTopDecs (decs, fn () => transStrexp (e, k))
    (* a dynamic module (D17, D18): what RuneDynamic.load gives -- or
       RuneDynamic.take, for a virtual module -- a tuple of the slots as
       units, and each slot's global set from it *)
    | StrDynamic (from, _, slot, sp) =>
        (case !slot of
           NONE => bug (sp, "a dynamic structure not elaborated")
         | SOME {fingerprint, slots, via, temp, reloadable} =>
             let
               val n = Int.max (List.length slots, 2)
               val tupleTy = Types.tupleTy (List.tabulate (n, fn _ => Types.unitTy))
               val str = Ty.fromTypes Types.stringTy
               fun slotTy (t, isExn) = if isExn then Ty.exnCon else Ty.fromTypes t
               fun set (_, [], _, k) = k ()
                 | set (from, (s, t, isExn) :: rest, i, k) =
                     Seq (SetGlobal (s, Prim ("unsafe_cast", SOME (Ty.arrow (Ty.unit, slotTy (t, isExn))),
                                              [Select (i, from)])),
                          set (from, rest, i + 1, k))
             in
               case from of
                 DynamicVirtual name =>
                   let
                     val takeTy = Types.TArrow (Types.tupleTy [Types.stringTy, Types.stringTy], tupleTy)
                     val call = App (useOf (Global via, via, takeTy),
                                     Tuple [Const (CString name, str), Const (CString fingerprint, str)])
                   in Mark (sp, Seq (SetGlobal (temp, call), set (Global temp, slots, 0, k))) end
               | DynamicFile path =>
                   (* the slots set by a function of the tuple, which load
                      calls, and calls again for each Dynamic.reload of the
                      file: what calls through the structure reach is the
                      new module's, what a closure holds stays the old *)
                   let
                     val setterTy = Types.TArrow (tupleTy, Types.unitTy)
                     val loadTy = Types.TArrow (Types.tupleTy [Types.stringTy, Types.stringTy, Types.boolTy, setterTy],
                                                Types.unitTy)
                     val x = MatchComp.freshVar ()
                     val setter = Fn (x, Ty.fromTypes setterTy, set (Var x, slots, 0, fn () => Unit))
                     val call = App (useOf (Global via, via, loadTy),
                                     Tuple [Const (CString path, str), Const (CString fingerprint, str),
                                            if reloadable then trueExp else falseExp,
                                            setter])
                   in Mark (sp, Seq (call, k ())) end
             end)
    (* its implementation: the body, then its slots, each cast to unit -- a
       polymorphic one at unit, which changes nothing of its value -- given
       to RuneDynamic.export with the fingerprint *)
    | StrExport (name, _, body, slot, sp) =>
        transStrexp (body, fn () =>
          case !slot of
            NONE => bug (sp, "an exported structure not elaborated")
          | SOME {fingerprint, slots, via, ...} =>
              let
                val n = Int.max (List.length slots, 2)
                val tupleTy = Types.tupleTy (List.tabulate (n, fn _ => Types.unitTy))
                val exportTy = Types.TArrow (Types.tupleTy [Types.stringTy, Types.stringTy, tupleTy], Types.unitTy)
                fun cast (s, t, isExn) =
                  if isExn then Prim ("unsafe_cast", SOME (Ty.arrow (Ty.exnCon, Ty.unit)), [Global s])
                  else
                    let val m = monoOf t
                    in Prim ("unsafe_cast", SOME (Ty.arrow (Ty.fromTypes m, Ty.unit)), [useOf (Global s, s, m)]) end
                val elems = List.map cast slots @ List.tabulate (n - List.length slots, fn _ => Unit)
              in
                Seq (App (useOf (Global via, via, exportTy),
                          Tuple [Const (CString name, Ty.fromTypes Types.stringTy),
                                 Const (CString fingerprint, Ty.fromTypes Types.stringTy), Tuple elems]),
                     k ())
              end)

  (* ---- functors compiled once (--functors=functions; functors-units.md,
     M5) ---- *)

  (* a record of n slots, as Elaborate.recordTy *)
  and recordTyN (n : int) : Ty.ty = Ty.tuple (List.tabulate (Int.max (n, 2), fn _ => Ty.unit))
  (* a record's slot cast to and from unit: functor_cast, an unsafe_cast
     (Lower) that only these make, which the expansion folds and MidLint
     checks (D3) *)
  and toUnit (e : lexp, t : Ty.ty) : lexp = Prim ("functor_cast", SOME (Ty.arrow (t, Ty.unit)), [e])
  and fromUnit (e : lexp, t : Ty.ty) : lexp = Prim ("functor_cast", SOME (Ty.arrow (Ty.unit, t)), [e])

  (* the record a reach reaches *)
  and reachExp ({var, global, path} : Elaborate.reach, n : int) : lexp =
    #1 (List.foldl (fn ((i, k), (e, _)) => (fromUnit (Select (i, e), recordTyN k), k))
                   (if global then Global var else Var var, n) path)

  (* what a slot of a record holds, cast to unit: a polymorphic value at
     unit for its type variables, which changes nothing of it *)
  and slotValue (v : Env.valstatus) : lexp =
    case v of
      Env.Val {stamp, global, scheme} =>
        let val m = monoOf scheme
        in if global then () else noteRead stamp;
           toUnit (useOf (if global then Global stamp else Var stamp, stamp, m), Ty.fromTypes m)
        end
    | Env.Exn {info, ...} => toUnit (exnConExp info, Ty.exnCon)
    | Env.ExnAsVal {ty, info} => let val t = Ty.fromTypes (monoOf ty) in toUnit (exnExp (info, t), t) end
    | Env.ConAsVal {scheme, info} => let val t = Ty.fromTypes (monoOf scheme) in toUnit (conExp (info, t), t) end
    | Env.Prim {scheme, name} => let val m = monoOf scheme in toUnit (builtinValue (name, m), Ty.fromTypes m) end
    | Env.Con _ => Error.bug "a constructor as a slot of a record"

  (* a record made, or the one in reach *)
  and recordExp (r as Elaborate.Record {vals, descs, strs, shared, ...}) : lexp =
    case shared of
      SOME h => reachExp (h, Elaborate.slotsOf r)
    | NONE =>
        let
          fun desc (Elaborate.DescLayout {stamp, name, arity, tag}) =
                let val dt = Ty.con (stamp, name, List.tabulate (arity, fn _ => Ty.unit))
                in toUnit (Prim ("open_layout", SOME (Ty.arrow (dt, Ty.int)), [Const (CInt (IntInf.fromInt tag), dt)]), Ty.int) end
            | desc (Elaborate.DescVar d) = (noteRead d; toUnit (Var d, Ty.int))
          val elems = List.map (fn (_, v) => slotValue v) vals @ List.map desc descs
                      @ List.map (fn (_, s) => toUnit (recordExp s, recordTyN (Elaborate.slotsOf s))) strs
        in Tuple (elems @ List.tabulate (Int.max (2 - List.length elems, 0), fn _ => Unit)) end

  (* the variables of a record's values and exceptions set from what src
     holds, then k: globals where they are, a temporary local for each
     substructure's record where they are not *)
  and bindRecord (Elaborate.Record {vals, descs, strs, ...}, src : lexp, k : unit -> lexp) : lexp =
    let
      fun go ([], i) = ds (descs, i)
        | go ((_, v) :: rest, i) =
            case v of
              Env.Val {stamp, global, scheme} =>
                MatchComp.bindVar (stamp, global, fromUnit (Select (i, src), Ty.fromTypes scheme), go (rest, i + 1))
            | Env.Exn {info, ...} =>
                if isSome (#builtin info) then go (rest, i + 1)
                else MatchComp.bindVar (#stamp info, #isGlobal info, fromUnit (Select (i, src), Ty.exnCon), go (rest, i + 1))
            | _ => go (rest, i + 1)
      and ds ([], i) = subs (strs, i)
        | ds (Elaborate.DescVar d :: rest, i) = Let (d, fromUnit (Select (i, src), Ty.int), ds (rest, i + 1))
        | ds (Elaborate.DescLayout _ :: rest, i) = ds (rest, i + 1)
      and subs ([], _) = k ()
        | subs ((_, s) :: rest, i) =
            let
              val n = Elaborate.slotsOf s
              val e = fromUnit (Select (i, src), recordTyN n)
              fun global (Elaborate.Record {vals, strs, ...}) =
                List.exists (fn (_, Env.Val {global, ...}) => global | (_, Env.Exn {info, ...}) => #isGlobal info | _ => false) vals
                orelse List.exists (fn (_, s) => global s) strs
              val t = MatchComp.freshVar ()
            in
              (* a global of its own for a substructure's record of globals,
                 which the top level's definitions read and a whole
                 program's shake takes away with them where none is read *)
              if global s then (Ty.bindVar (t, Elaborate.recordTyOf n);
                                MatchComp.bindVar (t, true, e, bindRecord (s, Global t, fn () => subs (rest, i + 1))))
              else Let (t, e, bindRecord (s, Var t, fn () => subs (rest, i + 1)))
            end
    in go (vals, 0) end

  (* What bindRecord binds, of a record of local variables, that the code
     made (rest) reads, around it: a body's parameter and the results of its
     applications, most of whose slots the body reads none of *)
  and bindUsed (r : Elaborate.record, src : lexp, rest : lexp) : lexp =
    let
      fun used (Elaborate.Record {vals, descs, strs, ...}) =
        List.exists (fn (_, Env.Val {stamp, ...}) => wasRead stamp
                      | (_, Env.Exn {info, ...}) => wasRead (#stamp info)
                      | _ => false) vals
        orelse List.exists (fn Elaborate.DescVar d => wasRead d | _ => false) descs
        orelse List.exists (fn (_, s) => used s) strs
      fun go (Elaborate.Record {vals, descs, strs, ...}, src, rest) =
        let
          fun slots ([], i, rest) = (i, rest)
            | slots ((_, v) :: more, i, rest) =
                let
                  val rest =
                    case v of
                      Env.Val {stamp, scheme, ...} =>
                        if wasRead stamp then Let (stamp, fromUnit (Select (i, src), Ty.fromTypes scheme), rest) else rest
                    | Env.Exn {info, ...} =>
                        if isSome (#builtin info) orelse not (wasRead (#stamp info)) then rest
                        else Let (#stamp info, fromUnit (Select (i, src), Ty.exnCon), rest)
                    | _ => rest
                in slots (more, i + 1, rest) end
          val (i, rest) = slots (vals, 0, rest)
          val (i, rest) =
            List.foldl (fn (d, (i, rest)) =>
                          (i + 1, case d of
                                    Elaborate.DescVar d => if wasRead d then Let (d, fromUnit (Select (i, src), Ty.int), rest) else rest
                                  | Elaborate.DescLayout _ => rest))
                       (i, rest) descs
          val (_, rest) =
            List.foldl (fn ((_, s), (i, rest)) =>
                          (i + 1,
                           if not (used s) then rest
                           else
                             let val t = MatchComp.freshVar ()
                             in Let (t, fromUnit (Select (i, src), recordTyN (Elaborate.slotsOf s)), go (s, Var t, rest)) end))
                       (i, rest) strs
        in rest end
    in go (r, src, rest) end

  (* a functor's declaration: its function, of its argument's record to its
     result's *)
  and functorFun (b : funbind, rest : lexp) : lexp =
    case Elaborate.bodyAt (#span b) of
      NONE => bug (#span b, "a functor without its code")
    | SOME {func, param, paramRecord, result, opens} =>
        let
          val saved = (!structPath, !inBody)
          val () = (structPath := [#name b]; inBody := true)
          val () = read := IntTable.table 1024
          val body = bindUsed (paramRecord, Var param, openFuns (opens, fn () => transStrexp (#body b, fn () => recordExp result)))
                     handle x => (structPath := #1 saved; inBody := #2 saved; raise x)
          val () = (structPath := #1 saved; inBody := #2 saved)
          val fty = Ty.arrow (recordTyN (Elaborate.slotsOf paramRecord), recordTyN (Elaborate.slotsOf result))
          val f = Mark (#span b, Fn (param, fty, body))
        in nameFun ("functor " ^ #name b, f); Seq (SetGlobal (func, f), rest) end

  (* The functions that make and take apart each constructor whose layout
     the parameter leaves open, by its descriptor d (D4): a constructor
     object of one field holding the argument where d is 0, as the
     specification reads it, or of the d fields of the argument, a tuple
     (Ty.flat); what the body's code does with such a constructor, which
     ToMid makes a call of one of them where d is not 0 *)
  and openFuns (opens : Elaborate.openCon list, k : unit -> lexp) : lexp =
    case opens of
      [] => k ()
    | {used = ref false, ...} :: rest => openFuns (rest, k)
    | {desc, con, decon, tag, dataTy, argTy, ...} :: rest =>
        let
          val t = Ty.fromTypes dataTy
          val a = Ty.fromTypes argTy
          fun cast (e, from, to) = Prim ("unsafe_cast", SOME (Ty.arrow (from, to)), [e])
          val () = noteRead desc
          fun isD n = Prim ("poly_eq", SOME (Ty.arrow (Ty.tuple [Ty.int, Ty.int], Ty.bool)),
                            [Var desc, Const (CInt (IntInf.fromInt n), Ty.int)])
          fun chain f = List.foldr (fn (n, rest) => If (isD n, f n, rest)) (raiseBuiltin exnMatch)
                                   (0 :: List.tabulate (Ty.maxFlat - 1, fn i => i + 2))
          val x = MatchComp.freshVar ()
          val y = MatchComp.freshVar ()
          fun units n = Ty.flatArg n
          fun make n =
            if n = 0 then cast (Con (tag, Ty.flat 1, cast (Var x, a, Ty.unit)), Ty.flat 1, t)
            else
              let val p = MatchComp.freshVar ()
              in Let (p, cast (Var x, a, units n),
                      cast (Con (tag, Ty.flat n, Tuple (List.tabulate (n, fn i => Select (i, Var p)))), Ty.flat n, t))
              end
          fun take n =
            if n = 0 then cast (Decon (tag, cast (Var y, t, Ty.flat 1)), Ty.unit, a)
            else cast (Decon (tag, cast (Var y, t, Ty.flat n)), units n, a)
          val () = funNames := IntMap.insert (!funNames, x, qualified "con")
          val () = funNames := IntMap.insert (!funNames, y, qualified "decon")
        in
          LetRec ([(con, Ty.arrow (a, t), Fn (x, Ty.arrow (a, t), chain make)),
                   (decon, Ty.arrow (t, a), Fn (y, Ty.arrow (t, a), chain take))],
                  openFuns (rest, k))
        end

  (* What the expansion (Expand, M6) substitutes in a copy of a functor's
     body for an application, as a type: a pair of tuples, the parameter's
     type names realised and the body's datatypes made the application's
     instances, each an arrow from the name applied to variables (Ty.Var)
     to what it becomes at them *)
  and functorTypes ({bound, made, ...} : Elaborate.callCode) : Ty.ty =
    let
      fun entry (c : Types.tycon, f : Types.tyfcn) =
        let
          val vs = List.tabulate (#arity c, fn _ => Types.fresh 0)
          val from = Ty.con (#stamp c, #name c, List.map Ty.fromTypes vs)
        in Ty.arrow (from, Ty.fromTypes (Types.applyFcn (f, vs))) end
    in
      Ty.tuple [Ty.tuple (List.map entry bound), Ty.tuple (List.map (fn (c, c') => entry (c, Types.TName c')) made)]
    end

  (* an application: the call, and the variables of its result set from
     what it returns *)
  and callExp (code as {func, arg, argVar, result, global, record, ...} : Elaborate.callCode, sp, k : unit -> lexp) : lexp =
    let
      (* the call under the application's place, after its marker -- a cast
         of () to what the expansion substitutes, which nothing reads; at the
         top level each variable a definition of its own (ToMid), which a
         mark around them would make one *)
      fun call a = MatchComp.bindVar (result, global,
                                      Mark (sp, Let (MatchComp.freshVar (),
                                                     Prim ("functor_marker", SOME (Ty.arrow (Ty.unit, functorTypes code)), [Unit]),
                                                     App (Global func, a))),
                                      if global then bindRecord (record, Global result, k)
                                      else bindUsed (record, Var result, k ()))
    in
      case argVar of
        SOME v => Let (v, recordExp arg, call (Var v))
      | NONE => call (recordExp arg)
    end

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

  (* The program's top-level declarations, as transTopDecs makes them, each
     with the wide constants it makes set first (MatchComp.hoisted): those
     made before its continuation is asked for, and those after *)
  fun transTopLevel (decs : dec list) : lexp =
    case decs of
      [] => Unit
    | d :: rest =>
        let
          val () = Types.startWorkOn ("type translation", spanOfDec d)
          val () = MatchComp.hoisted := []
          val first = ref []
          val code = transTopDec (d, fn () => (first := !MatchComp.hoisted; MatchComp.hoisted := [];
                                                 Rest (transTopLevel rest)))
          val made = !MatchComp.hoisted @ !first
        in
          MatchComp.hoisted := [];
          List.foldl (fn ((g, e), acc) => Seq (SetGlobal (g, e), acc)) code made
        end

  fun transProgram (decs : dec list) : lexp =
    (funNames := IntMap.empty; structPath := []; schemes := IntTable.table 4096; MatchComp.hoisted := [];
     let val e = transTopLevel decs handle x => (Types.stopWork (); raise x)
     in Types.stopWork (); e end)
end
