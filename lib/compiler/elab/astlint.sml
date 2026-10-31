(* AstLint: the derivation the elaborator found for the Core, checked
   against the Definition of Standard ML (Revised), chapter 4 (the linting
   roadmap, docs/plans/correctness/linting.md, M12: D3 A, D4 A, D5 B).

   A checker, not an inferencer. After Elaborate.finish, and before
   Translate or UnitBasis.undo, it reads the syntax, the witnesses the
   elaborator recorded of its nodes (Witness: the choices the Definition
   leaves open, as the roadmap's What the Definition says lists them),
   the slots Translate reads,
   the binders' types (Ty.binders) and the elaborator's records of each
   declaration at top level (Elaborate.tops), all as SourceTy. It builds an
   environment of its own and works every node's type out bottom-up, with
   equality of SourceTy and one-way matching of a scheme against an
   instance, and computes Clos (4.8, rule 15), non-expansiveness (4.7, with
   Appendix A's derived forms) and the scope of explicit type variables
   (4.6) itself. It never unifies, and calls nothing of Unify, SigMatch or
   Types' operations: only SourceTy's zonk of what it reads.

   The module language is taken as given (D5 B), its results axioms: the
   environment a declaration at top level was elaborated in (the Basis and
   the units before), and the results of ascriptions (rules 52, 53),
   functor applications (rule 54), dynamic modules and exports, and a
   functor's parameter as its body sees it (rule 86). But a transparent
   ascription's structure must enrich its result (5.5), and a functor's
   argument its parameter's signature, realised by paths (5.6): M13's first
   step, matching schemes one way. Signatures are not read; nor is
   _overload (its classes, Overload.table, are an axiom), and _prim's
   annotation is trusted.

   Where Rune reads the book otherwise, it is read as Rune reads it, by
   runespec's names of the readings (spec/notes/M10-deviations.md on branch
   runespec; docs/language.md): E.classes, the overloading classes the
   Basis extends; E.topdec and --overloading's other contexts, checked by
   their result only, the default each node got being one of its class
   (D3: a default where both type-check is a choice only its record
   holds); 4.11.program and --flex-records' other modes, by the record the
   row became after finish; 87.free and --free-tyvars, by the closure of
   what is left at the end; 4.4.scoped; the abstype's names, the same
   stamps, without equality outside (rule 19 as Rune reads it); ref and
   array admitting equality whatever their argument; and a local datatype's
   escape, checked where Rune checks it, at a let (its result and the
   context, the enclosing functions' variables among it).

   An alarm is a bug of the compiler: check raises Error.Bug, which
   Pass.checkAt (key "astlint", level 2) reports. RUNE_ASTLINT_FAULT=KIND,
   for the tests only, corrupts the first datum of a kind as AstLint reads
   it, so that each rule has a negative test (tests/runner/tools.sml,
   astlint-faults). *)
structure AstLint =
struct
  structure S = SourceTy
  open Ast

  type scheme = {bound : int list, ty : S.ty}
  datatype vstat =
      LVal of {stamp : int, scheme : scheme, global : bool}
    | LCon of {scheme : scheme, info : coninfo}
    | LExn of {ty : S.ty, info : exninfo}
    | LPrim of {scheme : scheme, name : string}
    | LConAsVal of {scheme : scheme, info : coninfo}
    | LExnAsVal of {ty : S.ty, info : exninfo}
  datatype tyfcn = FName of {stamp : int, name : string, arity : int, eq : bool} | FAbbrev of int list * S.ty
  datatype tystr = TS of {fcn : tyfcn, cons : (string * vstat) list}
  (* AstLint's layers of environment, over the elaborator's (axioms) *)
  datatype layer =
      Own of {vals : vstat StringMap.map, tys : tystr StringMap.map, strs : str StringMap.map}
    | Base of Env.env
  and str = SOwn of layer list | SBase of Env.env
  type env = layer list
  (* the context of rule 2 and the others: the environment, tyvars C (the
     free type variables of AstLint's own bindings and the explicit ones in
     scope), and the explicit type variables in scope by name (4.6) *)
  type ctx = {env : env, ftv : unit IntMap.map, scope : S.ty StringMap.map}
  (* the variables a pattern binds: name, stamp, type, global *)
  type binding = string * int * S.ty * bool * Source.span

  (* What a check or a typer reads of the elaborator's records, by node id
     (the witnesses) and by stamp (the binders): AstLint's of the tables as
     they are after Elaborate.finish (global), the editor's of the copies it
     keeps of a unit's (CompilerNodeTypes) *)
  type reader = {instance : int -> Types.ty option, nodeType : int -> Types.ty option,
                 created : int -> Types.tycon list option, scoped : int -> (string * Types.ty) list option,
                 generalised : int -> Types.tvar ref list option, binder : int -> Types.ty option,
                 moduleResult : int -> Env.env option, functorParam : int -> Env.env option}
  fun entryOf (t : 'a Witness.entry IntTable.table) (n : int) : 'a option =
    if n < 0 then NONE else Option.map #value (IntTable.find (t, n))
  val global : reader =
    {instance = entryOf Witness.instances, nodeType = entryOf Witness.types, created = entryOf Witness.created,
     scoped = entryOf Witness.scoped, generalised = entryOf Witness.generalised,
     binder = fn stamp => IntTable.find (Ty.binders, stamp),
     moduleResult = fn n => IntTable.find (Elaborate.moduleResults, n),
     functorParam = fn n => IntTable.find (Elaborate.functorParams, n)}

  (* a node's type as the typer worked it out (an expression's, a
     pattern's, or a binder's with the variables its own binding
     generalised): what the editor shows (CompilerNodeTypes) *)
  type node = {kind : string, span : Source.span, ty : S.ty, own : int list}
  fun kindOfExp e =
    case e of
      EScon _ => "EScon" | EVar _ => "EVar" | ERecord _ => "ERecord" | ETuple _ => "ETuple" | ESelect _ => "ESelect"
    | EList _ => "EList" | ESeq _ => "ESeq" | ELet _ => "ELet" | EApp _ => "EApp" | ETyped _ => "ETyped"
    | EAndalso _ => "EAndalso" | EOrelse _ => "EOrelse" | EHandle _ => "EHandle" | ERaise _ => "ERaise" | EIf _ => "EIf"
    | EWhile _ => "EWhile" | ECase _ => "ECase" | EFn _ => "EFn" | EPrim _ => "EPrim"
  fun kindOfPat p =
    case p of
      PWild _ => "PWild" | PScon _ => "PScon" | PVar _ => "PVar" | PRecord _ => "PRecord" | PTuple _ => "PTuple"
    | PList _ => "PList" | PApp _ => "PApp" | PTyped _ => "PTyped" | PLayered _ => "PLayered" | POr _ => "POr"

  exception Stop

  (* the stamps of the initial basis's type names, read as data *)
  val refStamp = #stamp Types.refTycon
  val arrayStamp = #stamp Types.arrayTycon
  val listStamp = #stamp Types.listTycon
  val exnStamp = #stamp Types.exnTycon
  val boolStamp = #stamp Types.boolTycon

  (* labels in the order Types keeps a record's (numeric labels first, by
     length, then by text), AstLint's own *)
  fun numeric s = String.size s > 0 andalso String.sub (s, 0) <> #"0" andalso List.all Char.isDigit (String.explode s)
  fun labelAfter (a, b) =
    case (numeric a, numeric b) of
      (true, true) => if String.size a <> String.size b then String.size a > String.size b else String.> (a, b)
    | (true, false) => false
    | (false, true) => true
    | (false, false) => String.> (a, b)
  fun sortLabels (fs : (string * 'a) list) : (string * 'a) list =
    let
      fun ins (f, []) = [f]
        | ins (f as (l, _), (g as (l', _)) :: rest) = if labelAfter (l, l') then g :: ins (f, rest) else f :: g :: rest
    in List.foldl ins [] fs end

  fun member (x : int, xs) = List.exists (fn y => y = x) xs
  fun sameSet (a : int list, b : int list) = List.all (fn x => member (x, b)) a andalso List.all (fn x => member (x, a)) b
  fun show t = S.toString t

  (* the explicit type variables of a type, in order of occurrence *)
  fun tyvarsOfTy (t : Ast.ty, acc : string list) : string list =
    case t of
      TyVar (v, _, _) => if List.exists (fn w => w = v) acc then acc else acc @ [v]
    | TyRecord (fs, _, _) => List.foldl (fn ((_, t, _), a) => tyvarsOfTy (t, a)) acc fs
    | TyTuple (ts, _, _) => List.foldl tyvarsOfTy acc ts
    | TyCon (ts, _, _, _) => List.foldl tyvarsOfTy acc ts
    | TyArrow (a, b, _, _) => tyvarsOfTy (b, tyvarsOfTy (a, acc))

  (* 4.6: the explicit type variables a value declaration scopes are those
     occurring in it unguarded, in no smaller value declaration (and not
     the parameters of a type or datatype binding, which bind their own) *)
  fun minus (vs, bound : string list) = List.filter (fn v => not (List.exists (fn w => w = v) bound)) vs
  fun ungExp (e, acc) =
    case e of
      ERecord (fs, _, _) => List.foldl (fn ((_, e, _), a) => ungExp (e, a)) acc fs
    | ETuple (es, _, _) => List.foldl ungExp acc es
    | EList (es, _, _, _) => List.foldl ungExp acc es
    | ESeq (es, _, _) => List.foldl ungExp acc es
    | ELet (ds, e, _, _) => ungExp (e, List.foldl ungDec acc ds)
    | EApp (a, b, _, _) => ungExp (b, ungExp (a, acc))
    | ETyped (e, t, _, _) => tyvarsOfTy (t, ungExp (e, acc))
    | EAndalso (a, b, _, _) => ungExp (b, ungExp (a, acc))
    | EOrelse (a, b, _, _) => ungExp (b, ungExp (a, acc))
    | EHandle (e, rs, _, _) => ungRules (rs, ungExp (e, acc))
    | ERaise (e, _, _) => ungExp (e, acc)
    | EIf (a, b, c, _, _) => ungExp (c, ungExp (b, ungExp (a, acc)))
    | EWhile (a, b, _, _) => ungExp (b, ungExp (a, acc))
    | ECase (e, rs, _, _) => ungRules (rs, ungExp (e, acc))
    | EFn (rs, _, _, _) => ungRules (rs, acc)
    | EPrim (_, t, _, _, _) => tyvarsOfTy (t, acc)
    | _ => acc
  and ungRules (rs, acc) = List.foldl (fn ((p, e), a) => ungExp (e, ungPat (p, a))) acc rs
  and ungPat (p, acc) =
    case p of
      PRecord (fs, _, _, _, _) => List.foldl (fn ((_, p, _), a) => ungPat (p, a)) acc fs
    | PTuple (ps, _, _) => List.foldl ungPat acc ps
    | PList (ps, _, _) => List.foldl ungPat acc ps
    | PApp (_, _, p, _, _) => ungPat (p, acc)
    | PTyped (p, t, _, _) => tyvarsOfTy (t, ungPat (p, acc))
    | PLayered (_, t, p, _, _, _) => ungPat (p, case t of SOME t => tyvarsOfTy (t, acc) | NONE => acc)
    | POr (ps, _, _) => List.foldl ungPat acc ps
    | _ => acc
  and ungDec (d, acc) =
    case d of
      DType (tbs, _, _) => List.foldl (fn (tb : typbind, a) => a @ minus (tyvarsOfTy (#ty tb, []), List.map #1 (#tyvars tb))) acc tbs
    | DDatatype (dbs, tbs, _, _) =>
        List.foldl (fn (db : datbind, a) =>
                       a @ minus (List.foldl (fn ((_, SOME t, _), x) => tyvarsOfTy (t, x) | (_, x) => x) [] (#cons db),
                                  List.map #1 (#tyvars db)))
                   (ungDec (DType (tbs, Source.noSpan, noId), acc)) dbs
    | DException (ebs, _, _) => List.foldl (fn (ExnDecl (_, SOME t, _, _, _), a) => tyvarsOfTy (t, a) | (_, a) => a) acc ebs
    | DLocal (a, b, _, _) => List.foldl ungDec (List.foldl ungDec acc a) b
    | DAbstype (dbs, tbs, ds, _, _) => List.foldl ungDec (ungDec (DDatatype (dbs, tbs, Source.noSpan, noId), acc)) ds
    | _ => acc
  fun ungValDec d =
    case d of
      DVal (_, bs, _, _) => List.foldl (fn ((p, e), a) => ungExp (e, ungPat (p, a))) [] bs
    | DValRec (_, bs, _, _) => List.foldl (fn ((p, e), a) => ungExp (e, ungPat (p, a))) [] bs
    | DFun (_, fs, _, _) =>
        List.foldl (fn (f : fundef, a) =>
                       List.foldl (fn ({pats, resty, body, ...} : clause, a) =>
                                      ungExp (body, List.foldl ungPat (case resty of SOME t => tyvarsOfTy (t, a) | NONE => a) pats))
                                  a (#clauses f)) [] fs
    | _ => []

  (* the class of a special constant (rules 1 and 33, Appendix E) *)
  fun sconClass sc =
    case sc of
      SInt _ => "int" | SWord _ => "word" | SReal _ => "real" | SString _ => "string" | SWideString _ => "string"
    | SChar _ => "char"

  fun sameCon (a : coninfo, b : coninfo) = #name a = #name b andalso #hasArg a = #hasArg b
  (* the built-in exceptions share one stamp: compared by their index too *)
  fun sameExn (a : exninfo, b : exninfo) = #stamp a = #stamp b andalso #builtin a = #builtin b
  fun infoTy (v : varinfo) =
    case v of
      VLocal (_, t) => t | VGlobal (_, t) => t | VCon (_, t) => t | VExn (_, t) => t | VBuiltin (_, t) => t
    | VConVal (_, t) => t | VExnVal (_, t) => t

  (* A check of what the elaborator recorded of the declarations at top
     level since its records were last dropped (Elaborate.tops), in the
     order they were elaborated: each in a batch of SourceTy's of its own,
     under SourceTy's budget, a declaration whose types are past it not
     checked (and counted). The alarms, at most the first 20 of them shown,
     make an Error.Bug. *)
  fun runWith ({reader, observe, fatal} : {reader : reader, observe : (node -> unit) option, fatal : bool})
              (tops : {dec : dec, env : Env.env, delta : Env.env} list) : {checked : int, skipped : int, alarms : int} =
    let
      fun note (n : node) = case observe of SOME f => f n | NONE => ()
      (* the functors the run declares, how many times each (total) and
         how many of them the check has met (seen): Elaborate.funs holds a
         functor's last binding, which an application refers to only where
         the run declares it never, or once and before the application *)
      fun functorsOfDec (d, m) =
        case d of
          DFunctor (binds, _, _) =>
            List.foldl (fn (b : funbind, m) => functorsOfStr (#body b, StringMap.insert (m, #name b, 1 + getOpt (StringMap.find (m, #name b), 0))))
                       m binds
        | DLocal (a, b, _, _) => List.foldl functorsOfDec (List.foldl functorsOfDec m a) b
        | DStructure (binds, _, _) => List.foldl (fn (b : strbind, m) => functorsOfStr (#strexp b, m)) m binds
        | _ => m
      and functorsOfStr (se, m) =
        case se of
          StrStruct (decs, _, _) => List.foldl functorsOfDec m decs
        | StrAscribe (se, _, _, _, _) => functorsOfStr (se, m)
        | StrApp (_, arg, _, _) => functorsOfStr (arg, m)
        | StrLet (decs, body, _, _) => functorsOfStr (body, List.foldl functorsOfDec m decs)
        | StrExport (_, _, body, _, _, _) => functorsOfStr (body, m)
        | _ => m
      val functorsTotal = List.foldl (fn ({dec, ...}, m) => functorsOfDec (dec, m)) StringMap.empty tops
      val functorsSeen : int StringMap.map ref = ref StringMap.empty
      fun lastBinding funid =
        case (StringMap.find (functorsTotal, funid), StringMap.find (!functorsSeen, funid)) of
          (NONE, _) => true
        | (SOME 1, SOME 1) => true
        | _ => false
      val alarms : (string * Source.span * string) list ref = ref []
      val nalarms = ref 0
      fun alarm (rule, sp, msg) = (nalarms := !nalarms + 1; if !nalarms <= 20 then alarms := (rule, sp, msg) :: !alarms else ())
      fun stop (rule, sp, msg) = (alarm (rule, sp, msg); raise Stop)

      (* RUNE_ASTLINT_FAULT=KIND: the first datum of KIND read corrupted *)
      val fault = ref (case OS.Process.getEnv "RUNE_ASTLINT_FAULT" of SOME k => k | NONE => "")
      fun faulty (kind : string) : bool = if !fault = kind then (fault := ""; true) else false

      val exnTy = S.con (exnStamp, "exn", [])
      val boolTy = S.con (boolStamp, "bool", [])
      val unitTy = S.record []
      fun listTy t = S.con (listStamp, "list", [t])
      (* a type other than t, for a fault *)
      fun other t = if S.same (t, exnTy) then unitTy else exnTy

      (* the variables of a type, by node *)
      val tvMemo : int list IntTable.table = IntTable.table 1024
      fun tyvars (t : S.ty) : int list =
        case IntTable.find (tvMemo, S.id t) of
          SOME l => l
        | NONE =>
            let
              fun union (a, b) = List.foldl (fn (x, acc) => if member (x, acc) then acc else x :: acc) b a
              val l = case S.node t of
                        S.Var {tv, ...} => [tv]
                      | S.Con {args, ...} => List.foldl (fn (a, acc) => union (tyvars a, acc)) [] args
                      | S.Record fs => List.foldl (fn ((_, a), acc) => union (tyvars a, acc)) [] fs
                      | S.Arrow (a, b) => union (tyvars a, tyvars b)
                      | S.Flex {tv, fields, ...} => List.foldl (fn ((_, a), acc) => union (tyvars a, acc)) [tv] fields
            in IntTable.insert (tvMemo, S.id t, l); l end
      (* the generic variables of a type: those its scheme binds *)
      fun genericVars (t : S.ty) : int list =
        let
          val seen = IntTable.table 16
          val acc = ref []
          fun go t =
            if isSome (IntTable.find (seen, S.id t)) then ()
            else
              (IntTable.insert (seen, S.id t, ());
               case S.node t of
                 S.Var {tv, generic, ...} => if generic andalso not (member (tv, !acc)) then acc := tv :: !acc else ()
               | S.Con {args, ...} => List.app go args
               | S.Record fs => List.app (go o #2) fs
               | S.Arrow (a, b) => (go a; go b)
               | S.Flex {tv, generic, fields, ...} =>
                   ((if generic andalso not (member (tv, !acc)) then acc := tv :: !acc else ()); List.app (go o #2) fields))
        in go t; !acc end
      (* the type names a type mentions *)
      val namesMemo : int list IntTable.table = IntTable.table 256
      fun names (t : S.ty) : int list =
        case IntTable.find (namesMemo, S.id t) of
          SOME l => l
        | NONE =>
            let
              val l = case S.node t of
                        S.Var _ => []
                      | S.Con {stamp, args, ...} => stamp :: List.concat (List.map names args)
                      | S.Record fs => List.concat (List.map (names o #2) fs)
                      | S.Arrow (a, b) => names a @ names b
                      | S.Flex {fields, ...} => List.concat (List.map (names o #2) fields)
            in IntTable.insert (namesMemo, S.id t, l); l end

      (* 4.9: whether a type name admits equality -- AstLint's own answer
         for the datatypes it checked, else the table by stamp's (which
         the elaborator's datatype declarations and abstypes fill, and
         otherwise a name's own attribute: SourceTy.admitsEq) *)
      val eqOf : bool IntTable.table = IntTable.table 64
      (* the attribute of a name met in the environment and nowhere in the
         table by stamp (a functor's parameter's, never zonked before) *)
      val occEq : bool IntTable.table = IntTable.table 64
      fun noteName (stamp, eq) = if isSome (IntTable.find (occEq, stamp)) then () else IntTable.insert (occEq, stamp, eq)
      fun nameEq stamp =
        case IntTable.find (eqOf, stamp) of
          SOME b => b
        | NONE => (case S.admitsEq stamp of
                     SOME b => b
                   | NONE => (case IntTable.find (occEq, stamp) of SOME b => b | NONE => false))
      fun admitsEq (t : S.ty) : bool =
        case S.node t of
          S.Var {eq, ...} => eq
        | S.Con {stamp, args, ...} => stamp = refStamp orelse stamp = arrayStamp orelse (nameEq stamp andalso List.all admitsEq args)
        | S.Record fs => List.all (admitsEq o #2) fs
        | S.Arrow _ => false
        | S.Flex {eq, ...} => eq

      (* substitution of variables by number *)
      fun subst (m : S.ty IntMap.map, t : S.ty) : S.ty =
        if IntMap.isEmpty m then t
        else
          let
            val memo = IntTable.table 16
            fun go t =
              case IntTable.find (memo, S.id t) of
                SOME r => r
              | NONE =>
                  let val r = case S.node t of
                                S.Var {tv, ...} => getOpt (IntMap.find (m, tv), t)
                              | S.Con {stamp, name, args} => S.con (stamp, name, List.map go args)
                              | S.Record fs => S.record (List.map (fn (l, a) => (l, go a)) fs)
                              | S.Arrow (a, b) => S.arrow (go a, go b)
                              | S.Flex {tv, eq, generic, fields} =>
                                  S.mk (S.Flex {tv = tv, eq = eq, generic = generic, fields = List.map (fn (l, a) => (l, go a)) fields})
                  in IntTable.insert (memo, S.id t, r); r end
          in go t end

      (* the class of an overloading type: Overload.table, an axiom (E.classes) *)
      fun kindOfStamp stamp = Option.map #kind (IntMap.find (!Overload.table, stamp))

      (* rule 2's instance, 4.5: a one-way match of a scheme against an
         instance, giving each bound variable an image -- one admitting
         equality where the variable ranges over equality types, one of
         its class where it is overloaded; a generalised flexible record
         is matched by a record with at least its labels (4.11.program and
         the other modes of --flex-records, by the record the row became).
         The scheme's free variables stand for themselves. NONE where the
         instance is none. *)
      fun matchScheme (sp, what, {bound, ty} : scheme, inst : S.ty) : bool =
        if List.null bound then S.same (ty, inst)
        else
          let
            val m = ref IntMap.empty
            val seen = IntTable.table 16
            exception No
            fun isBound tv = member (tv, bound)
            fun bind (tv, b) =
              case IntMap.find (!m, tv) of
                SOME img => if S.same (img, b) then () else raise No
              | NONE => m := IntMap.insert (!m, tv, b)
            fun go (a, b) =
              let val k = ((S.id a mod 1048573) * 31 + S.id b mod 1048573) mod 1048573   (* within 31 bits *)
              in
                if List.exists (fn (x, y) => x = S.id a andalso y = S.id b) (getOpt (IntTable.find (seen, k), [])) then ()
                else
                  (IntTable.insert (seen, k, (S.id a, S.id b) :: getOpt (IntTable.find (seen, k), []));
                   if not (List.exists isBound (tyvars a)) then (if S.same (a, b) then () else raise No)
                   else
                     case (S.node a, S.node b) of
                       (S.Var {tv, eq, classes, ...}, _) =>
                         if not (isBound tv) then (if S.same (a, b) then () else raise No)
                         else
                           (if isSome (IntMap.find (!m, tv)) then ()
                            else
                              ((* 4.5: an equality variable's image admits equality (rule 2) *)
                               if eq andalso not (admitsEq b) then
                                 alarm ("4.5 equality", sp, what ^ ": an equality type variable instantiated to " ^ show b
                                                            ^ ", which does not admit equality")
                               else ();
                               (* Appendix E: an overloaded variable's image is of its class *)
                               case classes of
                                 [] => ()
                               | _ =>
                                   (case S.node b of
                                      S.Con {stamp, ...} =>
                                        (case kindOfStamp stamp of
                                           SOME k => if List.exists (fn c => c = k) classes then ()
                                                     else alarm ("E overloading", sp, what ^ ": " ^ show b ^ " is not of the classes "
                                                                                      ^ String.concatWith "/" classes)
                                         | NONE => alarm ("E overloading", sp, what ^ ": " ^ show b ^ " is no type of an overloading class"))
                                    | _ => alarm ("E overloading", sp, what ^ ": " ^ show b ^ " is no type of an overloading class")));
                            bind (tv, b))
                     | (S.Con {stamp = s1, args = a1, ...}, S.Con {stamp = s2, args = a2, ...}) =>
                         if s1 = s2 andalso List.length a1 = List.length a2 then ListPair.app go (a1, a2) else raise No
                     | (S.Record f1, S.Record f2) =>
                         if List.length f1 = List.length f2 andalso ListPair.all (fn ((l1, _), (l2, _)) => l1 = l2) (f1, f2)
                         then ListPair.app (fn ((_, x), (_, y)) => go (x, y)) (f1, f2) else raise No
                     | (S.Arrow (x1, y1), S.Arrow (x2, y2)) => (go (x1, x2); go (y1, y2))
                     | (S.Flex {tv, fields, ...}, S.Record f2) =>
                         (List.app (fn (l, x) => case List.find (fn (l', _) => l' = l) f2 of
                                                   SOME (_, y) => go (x, y)
                                                 | NONE => raise No) fields;
                          if isBound tv then bind (tv, b) else ())
                     | (S.Flex {tv = t1, ...}, S.Flex {tv = t2, ...}) => if isBound t1 then bind (t1, b) else if t1 = t2 then () else raise No
                     | _ => raise No)
              end
          in (go (ty, inst); true) handle No => false end

      (* ---- the environment ---- *)
      fun zonk (t : Types.ty) : S.ty = S.zonk t
      fun schemeOf (t : Types.ty) : scheme = let val z = zonk t in {bound = genericVars z, ty = z} end
      (* the elaborator's bindings, axioms: never by stamp, since after an
         ascription one variable's stamp carries other schemes (E6) *)
      fun convVal (v : Env.valstatus) : vstat =
        case v of
          Env.Val {scheme, stamp, global} => LVal {stamp = stamp, scheme = schemeOf scheme, global = global}
        | Env.Con {scheme, info} => LCon {scheme = schemeOf scheme, info = info}
        | Env.Exn {ty, info} => LExn {ty = zonk ty, info = info}
        | Env.Prim {scheme, name} => LPrim {scheme = schemeOf scheme, name = name}
        | Env.ConAsVal {scheme, info} => LConAsVal {scheme = schemeOf scheme, info = info}
        | Env.ExnAsVal {ty, info} => LExnAsVal {ty = zonk ty, info = info}
      (* a type function's parameters: AstLint's own variables, by number,
         below every variable of Types' *)
      val nextOwn = ref ~1
      fun ownVar (eq : bool) : int * S.ty =
        let val v = !nextOwn in nextOwn := v - 1; (v, S.var (v, eq, NONE, [], true)) end
      fun convTy (Env.TyStr {fcn, cons}) : tystr =
        TS {fcn = case fcn of
                    Types.TName c => FName {stamp = #stamp c, name = #name c, arity = #arity c, eq = #eq c}
                  | Types.TAbbrev (ps, body) => FAbbrev (ps, zonk body),
            cons = List.map (fn (n, v) => (n, convVal v)) cons}

      fun findValIn (layers : env, name) : vstat option =
        case layers of
          [] => NONE
        | Own {vals, ...} :: rest => (case StringMap.find (vals, name) of SOME v => SOME v | NONE => findValIn (rest, name))
        | Base e :: rest => (case StringMap.find (Env.vals e, name) of SOME v => SOME (convVal v) | NONE => findValIn (rest, name))
      fun findTyIn (layers : env, name) : tystr option =
        case layers of
          [] => NONE
        | Own {tys, ...} :: rest => (case StringMap.find (tys, name) of SOME v => SOME v | NONE => findTyIn (rest, name))
        | Base e :: rest => (case StringMap.find (Env.tys e, name) of SOME v => SOME (convTy v) | NONE => findTyIn (rest, name))
      fun findStrIn (layers : env, name) : str option =
        case layers of
          [] => NONE
        | Own {strs, ...} :: rest => (case StringMap.find (strs, name) of SOME v => SOME v | NONE => findStrIn (rest, name))
        | Base e :: rest => (case StringMap.find (Env.strs e, name) of SOME v => SOME (SBase v) | NONE => findStrIn (rest, name))
      fun layersOf (SOwn l) = l
        | layersOf (SBase e) = [Base e]
      fun findPath (env, []) = SOME env
        | findPath (env, s :: rest) = case findStrIn (env, s) of SOME st => findPath (layersOf st, rest) | NONE => NONE
      fun findVal (env, (path, name)) = Option.mapPartial (fn e => findValIn (e, name)) (findPath (env, path))
      fun findTy (env, (path, name)) = Option.mapPartial (fn e => findTyIn (e, name)) (findPath (env, path))

      fun mergeOwn ({vals = v1, tys = t1, strs = s1}, {vals = v2, tys = t2, strs = s2}) =
        {vals = StringMap.foldli (fn (k, v, m) => StringMap.insert (m, k, v)) v1 v2,
         tys = StringMap.foldli (fn (k, v, m) => StringMap.insert (m, k, v)) t1 t2,
         strs = StringMap.foldli (fn (k, v, m) => StringMap.insert (m, k, v)) s1 s2}
      fun push (Own a, Own b :: rest) = Own (mergeOwn (b, a)) :: rest
        | push (l, acc) = l :: acc
      fun plus (base : env, top : env) : env = List.foldr push base top
      fun ownVals (vs : (string * vstat) list) : env =
        [Own {vals = List.foldl (fn ((n, v), m) => StringMap.insert (m, n, v)) StringMap.empty vs,
              tys = StringMap.empty, strs = StringMap.empty}]
      fun ownTys (ts : (string * tystr) list) : env =
        [Own {vals = StringMap.empty, tys = List.foldl (fn ((n, v), m) => StringMap.insert (m, n, v)) StringMap.empty ts,
              strs = StringMap.empty}]

      fun addFtv (ftv, tvs : int list) = List.foldl (fn (v, m) => IntMap.insert (m, v, ())) ftv tvs
      fun freeOf ({bound, ty} : scheme) = List.filter (fn v => not (member (v, bound))) (tyvars ty)
      fun ownFree (layers : env) : int list =
        List.concat (List.map (fn Own {vals, strs, ...} =>
                                  StringMap.foldl (fn (LVal {scheme, ...}, acc) => freeOf scheme @ acc
                                                    | (LConAsVal {scheme, ...}, acc) => freeOf scheme @ acc
                                                    | (_, acc) => acc) [] vals
                                  @ StringMap.foldl (fn (SOwn l, acc) => ownFree l @ acc | (_, acc) => acc) [] strs
                                | Base _ => []) layers)
      fun extend ({env, ftv, scope} : ctx, delta : env) : ctx = {env = plus (env, delta), ftv = addFtv (ftv, ownFree delta), scope = scope}

      (* ---- what the elaborator recorded, read ---- *)
      fun entry (lookup : int -> 'a option, n : int) : 'a option = if n < 0 then NONE else lookup n
      (* a type witness of a node: the instance at a constructor pattern
         (rules 35, 41), the type of a wildcard (32), of a raise (11), of
         a [] pattern *)
      fun witnessed (table, n, sp, what, kind) : S.ty =
        case entry (table, n) of
          SOME t => let val z = zonk t in if faulty kind then other z else z end
        | NONE => stop ("witness", sp, "no witness of " ^ what)
      (* a slot Translate reads: its type *)
      fun slotTy (sp, what, slot : Types.ty option, kind) : S.ty =
        case slot of
          SOME t => let val z = zonk t in if faulty kind then other z else z end
        | NONE => stop ("slot", sp, what ^ ": an empty slot")
      (* a binder's type (rules 32-34's variable, a fun's, a val rec's) *)
      fun binderTy (sp, stamp) : S.ty =
        case #binder reader stamp of
          SOME t => let val z = zonk t in if faulty "binder" then other z else z end
        | NONE => stop ("witness", sp, "no type of the variable's binder")
      fun expect (rule, sp, what, want : S.ty, got : S.ty) =
        if S.same (want, got) then () else alarm (rule, sp, what ^ ": " ^ show want ^ " expected, " ^ show got ^ " found")

      (* ---- type expressions (rules 44-49) ---- *)
      fun applyFcn (sp, fcn, args : S.ty list) : S.ty =
        case fcn of
          FName {stamp, name, arity, eq} =>
            (noteName (stamp, eq);
             if List.length args <> arity then alarm ("49 type", sp, "type constructor " ^ name ^ " given "
                                                                    ^ Int.toString (List.length args) ^ " arguments") else ();
             S.con (stamp, name, args))
        | FAbbrev (ps, body) =>
            if List.length ps <> List.length args then stop ("49 type", sp, "a type abbreviation given the wrong number of arguments")
            else subst (List.foldl (fn ((p, a), m) => IntMap.insert (m, p, a)) IntMap.empty (ListPair.zip (ps, args)), body)
      fun elabTy (c : ctx, t : Ast.ty) : S.ty =
        case t of
          TyVar (v, sp, _) =>
            (case StringMap.find (#scope c, v) of SOME x => x | NONE => stop ("4.6 scope", sp, "type variable " ^ v ^ " not in scope"))
        | TyRecord (fs, _, _) => S.record (sortLabels (List.map (fn (l, a, _) => (l, elabTy (c, a))) fs))
        | TyTuple (ts, _, _) => S.tuple (List.map (fn a => elabTy (c, a)) ts)
        | TyArrow (a, b, _, _) => S.arrow (elabTy (c, a), elabTy (c, b))
        | TyCon (args, longid, sp, _) =>
            (case findTy (#env c, longid) of
               SOME (TS {fcn, ...}) => applyFcn (sp, fcn, List.map (fn a => elabTy (c, a)) args)
             | NONE => stop ("49 type", sp, "unbound type constructor " ^ longidToString longid))

      (* ---- the module language (5.5, 5.6): enrichment, one way ---- *)
      (* a type function's arity, and two equal as functions: applied to
         the same variables of AstLint's own, equal *)
      fun fcnArity (FName {arity, ...}) = arity
        | fcnArity (FAbbrev (ps, _)) = List.length ps
      fun sameFcn (sp, fa, fs) =
        fcnArity fa = fcnArity fs andalso
        (let val vs = List.tabulate (fcnArity fa, fn _ => #2 (ownVar false))
         in S.same (applyFcn (sp, fa, vs), applyFcn (sp, fs, vs)) end)
      (* a realisation (5.2) of type names by stamp, applied *)
      fun realise (phi : tyfcn IntMap.map) (t : S.ty) : S.ty =
        if IntMap.isEmpty phi then t
        else
          let
            val memo = IntTable.table 16
            fun go t =
              case IntTable.find (memo, S.id t) of
                SOME r => r
              | NONE =>
                  let val r = case S.node t of
                                S.Var _ => t
                              | S.Con {stamp, name, args} =>
                                  (case IntMap.find (phi, stamp) of
                                     SOME fcn => applyFcn (Source.noSpan, fcn, List.map go args)
                                   | NONE => S.con (stamp, name, List.map go args))
                              | S.Record fs => S.record (List.map (fn (l, a) => (l, go a)) fs)
                              | S.Arrow (a, b) => S.arrow (go a, go b)
                              | S.Flex {tv, eq, generic, fields} =>
                                  S.mk (S.Flex {tv = tv, eq = eq, generic = generic, fields = List.map (fn (l, a) => (l, go a)) fields})
                  in IntTable.insert (memo, S.id t, r); r end
          in go t end
      fun realiseFcn phi fcn =
        case fcn of
          FName {stamp, ...} => (case IntMap.find (phi, stamp) of SOME f => f | NONE => fcn)
        | FAbbrev (ps, body) => FAbbrev (ps, realise phi body)
      (* rule 2's instance of 4.5, one way: the structure's scheme at least
         as general as the specification's, whose bound variables stand for
         themselves *)
      fun asGeneral (sp, what, actual : scheme, spec : scheme) =
        if matchScheme (sp, what, actual, #ty spec) then ()
        else alarm ("5.5 enrichment", sp, what ^ ": " ^ show (#ty actual) ^ " in the structure is not as general as "
                                         ^ show (#ty spec))
      fun schemeOfV (v : vstat) : scheme =
        case v of
          LVal {scheme, ...} => scheme | LCon {scheme, ...} => scheme | LPrim {scheme, ...} => scheme
        | LConAsVal {scheme, ...} => scheme | LExn {ty, ...} => {bound = [], ty = ty} | LExnAsVal {ty, ...} => {bound = [], ty = ty}
      (* 5.5: the structure (actual, AstLint's own) enriches the
         specification (spec, the elaborator's environment, its type names
         realised by phi): every type there, with the same function and
         constructors; every value, its scheme at least as general, of its
         status, a constructor's or exception's the same; every structure,
         again. The identity of what the elaborator's result says it holds
         (its stamps, a constructor's information) is the structure's *)
      fun enrich (sp, path : string list, phi : tyfcn IntMap.map, spec : Env.env, actual : env, identity : bool) : unit =
        let
          fun name n = String.concatWith "." (path @ [n])
          val r = realise phi
          fun rs ({bound, ty} : scheme) : scheme = {bound = bound, ty = r ty}
          val () =
            StringMap.appi
              (fn (n, ts) =>
                  let val TS {fcn = fs, cons = cs} = convTy ts
                  in
                    case findTyIn (actual, n) of
                      NONE => alarm ("5.5 enrichment", sp, "type " ^ name n ^ " is not in the structure")
                    | SOME (TS {fcn = fa, cons = ca}) =>
                        (if sameFcn (sp, fa, realiseFcn phi fs) then ()
                         else alarm ("5.5 enrichment", sp, "type " ^ name n ^ " is another type in the structure");
                         if List.null cs orelse List.map #1 (sortLabels cs) = List.map #1 (sortLabels ca) then ()
                         else alarm ("5.5 enrichment", sp, "datatype " ^ name n ^ " has other constructors in the structure"))
                  end)
              (Env.tys spec)
          val () =
            StringMap.appi
              (fn (n, sv) =>
                  case findValIn (actual, n) of
                    NONE => alarm ("5.5 enrichment", sp, "value " ^ name n ^ " is not in the structure")
                  | SOME av =>
                      (case (convVal sv, av) of
                         (LVal {stamp, scheme, ...}, _) =>
                           (asGeneral (sp, name n, schemeOfV av, rs (if faulty "enrich" then {bound = [], ty = other (#ty scheme)} else scheme));
                            case av of
                              LVal {stamp = s, ...} => if not identity orelse (s = stamp andalso not (faulty "identity")) then ()
                                                        else alarm ("5.5 identity", sp, "value " ^ name n ^ ": another variable")
                            | _ => ())
                       | (LConAsVal {scheme, info}, LCon {scheme = sa, info = ia}) =>
                           (asGeneral (sp, name n, sa, rs scheme);
                            if sameCon (info, ia) then () else alarm ("5.5 identity", sp, "value " ^ name n ^ ": another constructor"))
                       | (LExnAsVal {ty, info}, LExn {ty = ta, info = ia}) =>
                           (asGeneral (sp, name n, {bound = [], ty = ta}, {bound = [], ty = r ty});
                            if sameExn (info, ia) then () else alarm ("5.5 identity", sp, "value " ^ name n ^ ": another exception"))
                       | (LPrim {scheme, name = pn}, LPrim {scheme = sa, name = pa}) =>
                           (asGeneral (sp, name n, sa, rs scheme);
                            if pn = pa then () else alarm ("5.5 identity", sp, "value " ^ name n ^ ": another primitive"))
                       | (LConAsVal {scheme, ...}, _) => asGeneral (sp, name n, schemeOfV av, rs scheme)
                       | (LExnAsVal {ty, ...}, _) => asGeneral (sp, name n, schemeOfV av, {bound = [], ty = r ty})
                       | (LPrim {scheme, ...}, _) => asGeneral (sp, name n, schemeOfV av, rs scheme)
                       | (LCon {scheme, info}, LCon {scheme = sa, info = ia}) =>
                           (asGeneral (sp, name n, sa, rs scheme); asGeneral (sp, name n, rs scheme, sa);
                            if sameCon (info, ia) then () else alarm ("5.5 identity", sp, "constructor " ^ name n ^ ": another"))
                       | (LExn {ty, info}, LExn {ty = ta, info = ia}) =>
                           (if S.same (r ty, ta) then () else alarm ("5.5 enrichment", sp, "exception " ^ name n ^ ": another type");
                            if not identity orelse sameExn (info, ia) then ()
                            else alarm ("5.5 identity", sp, "exception " ^ name n ^ ": another exception"))
                       | (LCon _, _) => alarm ("5.5 enrichment", sp, name n ^ " is a constructor in the specification, not in the structure")
                       | (LExn _, _) => alarm ("5.5 enrichment", sp, name n ^ " is an exception in the specification, not in the structure")))
              (Env.vals spec)
          val () =
            StringMap.appi
              (fn (n, se) =>
                  case findStrIn (actual, n) of
                    NONE => alarm ("5.5 enrichment", sp, "structure " ^ name n ^ " is not in the structure")
                  | SOME st => enrich (sp, path @ [n], phi, se, layersOf st, identity))
              (Env.strs spec)
        in () end
      (* 5.6: the realisation of a signature's bound names that its match
         against a structure finds, by paths: each bound name the type the
         structure has at the path the signature has it *)
      fun phiByPaths (sp, bound : Types.tycon list, sigEnv : Env.env, actual : env) : tyfcn IntMap.map =
        let
          val boundSet = List.foldl (fn (c : Types.tycon, m) => IntMap.insert (m, #stamp c, c)) IntMap.empty bound
          fun walk (path : string list, e : Env.env, layers : env, phi) =
            let
              val phi =
                StringMap.foldli
                  (fn (n, Env.TyStr {fcn = Types.TName c, ...}, phi) =>
                      (case IntMap.find (boundSet, #stamp c) of
                         SOME bc =>
                           if IntMap.member (phi, #stamp c) then phi
                           else (case findTyIn (layers, n) of
                                   SOME (TS {fcn, ...}) =>
                                     (if (#eq bc orelse faulty "match") andalso not (fcnAdmitsEq fcn)
                                      then alarm ("5.6 match", sp, "type " ^ String.concatWith "." (path @ [n])
                                                                    ^ " must admit equality")
                                      else ();
                                      IntMap.insert (phi, #stamp c, fcn))
                                 | NONE => (alarm ("5.6 match", sp, "type " ^ String.concatWith "." (path @ [n])
                                                                     ^ " is not in the structure"); phi))
                       | NONE => phi)
                    | (_, _, phi) => phi)
                  phi (Env.tys e)
            in
              StringMap.foldli (fn (n, sub, phi) =>
                                   case findStrIn (layers, n) of
                                     SOME st => walk (path @ [n], sub, layersOf st, phi)
                                   | NONE => phi) phi (Env.strs e)
            end
        in walk ([], sigEnv, actual, IntMap.empty) end
      and fcnAdmitsEq fcn =
        let val vs = List.tabulate (fcnArity fcn, fn _ => #2 (ownVar true))
        in admitsEq (applyFcn (Source.noSpan, fcn, vs)) end

      (* ---- 4.6: the scope of a value declaration ---- *)
      fun valScope (c : ctx, explicit : tyvarseq, d : dec, sp) : ctx * int list =
        let
          val explicit = List.map #1 explicit
          val implicit = List.filter (fn v => not (StringMap.member (#scope c, v)) andalso not (List.exists (fn w => w = v) explicit))
                                     (ungValDec d)
          val mine = explicit @ implicit
          val recorded = case entry (#scoped reader, idOfDec d) of
                           SOME vs => List.map (fn (v, t) => (v, zonk t)) vs
                         | NONE => []
          val recorded = case recorded of _ :: rest => if faulty "scope" then rest else recorded | [] => []
          val theirs = List.map #1 recorded
          val () = if List.all (fn v => List.exists (fn w => w = v) theirs) mine andalso List.all (fn v => List.exists (fn w => w = v) mine) theirs
                   then ()
                   else alarm ("4.6 scope", sp, "the explicit type variables scoped here: by 4.6 " ^ String.concatWith ", " mine
                                               ^ "; the elaborator's " ^ String.concatWith ", " theirs)
          val scope = List.foldl (fn ((v, t), m) => StringMap.insert (m, v, t)) (#scope c) recorded
          val us = List.concat (List.map (fn (_, t) => tyvars t) recorded)
        in ({env = #env c, ftv = addFtv (#ftv c, us), scope = scope}, us) end

      (* ---- 4.7: non-expansive expressions, with Appendix A's derived
         forms read as what they stand for: a tuple and a list are
         records and applications of constructors, #lab a fn ---- *)
      fun conexp (c : ctx, e) =
        case e of
          ETyped (e, _, _, _) => conexp (c, e)
        | EVar (longid, _, _, _) =>
            (case findVal (#env c, longid) of
               SOME (LCon {info, ...}) => not (#isRef info)
             | SOME (LExn _) => true
             | _ => false)
        | _ => false
      fun nonexpansive (c : ctx, e) =
        case e of
          EScon _ => true | EVar _ => true | EFn _ => true | ESelect _ => true | EPrim _ => true
        | ERecord (fs, _, _) => List.all (fn (_, e, _) => nonexpansive (c, e)) fs
        | ETuple (es, _, _) => List.all (fn e => nonexpansive (c, e)) es
        | EList (es, _, _, _) => List.all (fn e => nonexpansive (c, e)) es
        | ETyped (e, _, _, _) => nonexpansive (c, e)
        | EApp (f, a, _, _) => conexp (c, f) andalso nonexpansive (c, a)
        | _ => false

      (* ---- constants: of their class (rules 1, 33; Appendix E) ---- *)
      fun checkScon (sp, sc, t) =
        case S.node t of
          S.Con {stamp, ...} =>
            (case kindOfStamp stamp of
               SOME k => if k = sconClass sc then () else alarm ("E constant", sp, "a constant of class " ^ sconClass sc ^ " at " ^ show t)
             | NONE => alarm ("E constant", sp, "a constant at " ^ show t ^ ", of no overloading class"))
        | _ => alarm ("E constant", sp, "a constant at " ^ show t)

      fun slotAgrees (sp, what, slot : Types.ty option, t : S.ty) =
        case slot of
          SOME x => let val z = zonk x in if S.same (z, t) then () else alarm ("slot", sp, what ^ ": the slot holds " ^ show z ^ ", the node is " ^ show t) end
        | NONE => alarm ("slot", sp, what ^ ": an empty slot")

      (* ---- patterns (rules 32-43): the type and the variables bound ---- *)
      fun synthPat (c : ctx, p : pat) : S.ty * binding list =
        let val r = synthPat0 (c, p) in note {kind = kindOfPat p, span = spanOfPat p, ty = #1 r, own = []}; r end
      and synthPat0 (c : ctx, p : pat) : S.ty * binding list =
        case p of
          PWild (sp, n) => (witnessed (#nodeType reader, n, sp, "a wildcard", "wildcard"), [])
        | PScon (sc, slot, sp, _) => let val t = slotTy (sp, "a constant", !slot, "constant") in checkScon (sp, sc, t); (t, []) end
        | PVar (longid as (_, name), slot, sp, n) =>
            (case !slot of
               SOME (PIVar (stamp, global)) =>
                 let val t = binderTy (sp, stamp)
                 in
                   (* rule 34: a variable, not of constructor or exception status *)
                   (case findVal (#env c, longid) of
                      SOME (LCon _) => alarm ("34 status", sp, name ^ " is a constructor in the context, bound as a variable")
                    | SOME (LExn _) => alarm ("34 status", sp, name ^ " is an exception in the context, bound as a variable")
                    | _ => ());
                   (t, [(name, stamp, t, global, sp)])
                 end
             | SOME (PICon info) =>
                 let val t = witnessed (#instance reader, n, sp, "constructor " ^ name, "instance")
                 in
                   (* rule 35 *)
                   case findVal (#env c, longid) of
                     SOME (LCon {scheme, info = i}) =>
                       (if sameCon (info, i) then () else alarm ("35 identity", sp, "constructor " ^ name ^ ": another in the context");
                        if matchScheme (sp, name, scheme, t) then ()
                        else alarm ("35 instance", sp, "constructor " ^ name ^ " at " ^ show t ^ ", no instance of " ^ show (#ty scheme));
                        (t, []))
                   | _ => stop ("35 identity", sp, name ^ ": a constructor in the slot, none in the context")
                 end
             | SOME (PIExn info) =>
                 (* rule 36 *)
                 (case findVal (#env c, longid) of
                    SOME (LExn {ty, info = i}) =>
                      (if sameExn (info, i) then () else alarm ("36 identity", sp, "exception " ^ name ^ ": another in the context");
                       (ty, []))
                  | _ => stop ("36 identity", sp, name ^ ": an exception in the slot, none in the context"))
             | NONE => stop ("slot", sp, name ^ ": an empty slot"))
        | PRecord (fields, flex, slot, sp, _) =>
            let
              val rs = List.map (fn (l, p, _) => let val (t, bs) = synthPat (c, p) in ((l, t), bs) end) fields
              val fs = List.map #1 rs
              val bs = List.concat (List.map #2 rs)
            in
              if flex then
                (* rule 38: the row the context determined *)
                let val r = slotTy (sp, "a flexible record", !slot, "flex")
                in
                  (case S.node r of
                     S.Record all =>
                       List.app (fn (l, t) => case List.find (fn (l', _) => l' = l) all of
                                                SOME (_, t') => expect ("38 record", sp, "field " ^ l, t', t)
                                              | NONE => alarm ("38 record", sp, "a flexible record without its field " ^ l)) fs
                   | _ => alarm ("38 record", sp, "a flexible record left open: " ^ show r));
                  (r, bs)
                end
              else (S.record (sortLabels fs), bs)
            end
        | PTuple ([], _, _) => (unitTy, [])
        | PTuple (ps, _, _) =>
            let val rs = List.map (fn p => synthPat (c, p)) ps
            in (S.tuple (List.map #1 rs), List.concat (List.map #2 rs)) end
        | PList ([], sp, n) =>
            let val t = witnessed (#nodeType reader, n, sp, "[]", "nil")
            in
              (case S.node t of
                 S.Con {stamp, args = [_], ...} => if stamp = listStamp then () else alarm ("35 instance", sp, "[] at " ^ show t)
               | _ => alarm ("35 instance", sp, "[] at " ^ show t));
              (t, [])
            end
        | PList (ps, sp, _) =>
            let
              val rs = List.map (fn p => synthPat (c, p)) ps
              val t1 = #1 (List.hd rs)
            in
              List.app (fn (t, _) => expect ("41 list", sp, "a list pattern's element", t1, t)) (List.tl rs);
              (listTy t1, List.concat (List.map #2 rs))
            end
        | PApp (longid as (_, name), slot, arg, sp, n) =>
            let
              val (ta, bs) = synthPat (c, arg)
            in
              case !slot of
                SOME (PICon info) =>
                  (* rule 41 *)
                  let val t = witnessed (#instance reader, n, sp, "constructor " ^ name, "instance")
                  in
                    case findVal (#env c, longid) of
                      SOME (LCon {scheme, info = i}) =>
                        (if sameCon (info, i) then () else alarm ("41 identity", sp, "constructor " ^ name ^ ": another in the context");
                         if matchScheme (sp, name, scheme, t) then ()
                         else alarm ("41 instance", sp, "constructor " ^ name ^ " at " ^ show t ^ ", no instance of " ^ show (#ty scheme));
                         case S.node t of
                           S.Arrow (d, r) => (expect ("41 instance", sp, "constructor " ^ name ^ "'s argument", d, ta); (r, bs))
                         | _ => stop ("41 instance", sp, "constructor " ^ name ^ " at " ^ show t))
                    | _ => stop ("41 identity", sp, name ^ ": a constructor in the slot, none in the context")
                  end
              | SOME (PIExn info) =>
                  (* rule 42 *)
                  (case findVal (#env c, longid) of
                     SOME (LExn {ty, info = i}) =>
                       (if sameExn (info, i) then () else alarm ("42 identity", sp, "exception " ^ name ^ ": another in the context");
                        case S.node ty of
                          S.Arrow (d, r) => (expect ("42 instance", sp, "exception " ^ name ^ "'s argument", d, ta); (r, bs))
                        | _ => stop ("42 instance", sp, "exception " ^ name ^ " takes no argument"))
                   | _ => stop ("42 identity", sp, name ^ ": an exception in the slot, none in the context"))
              | _ => stop ("slot", sp, name ^ ": a constructor pattern without its constructor")
            end
        | PTyped (p, ty, sp, _) =>
            (* rule 42's typed pattern (Rune's rule 43) *)
            let val (tp, bs) = synthPat (c, p)
                val ta = elabTy (c, ty)
            in expect ("43 annotation", sp, "a pattern's annotation", ta, tp); (ta, bs) end
        | PLayered (name, tyopt, p, slot, sp, _) =>
            let
              val (tp, bs) = synthPat (c, p)
              val () = case tyopt of SOME ty => expect ("43 annotation", sp, "a layered pattern's annotation", elabTy (c, ty), tp) | NONE => ()
              val b = case !slot of
                        SOME (PIVar (stamp, global)) =>
                          (expect ("43 layered", sp, "the layered variable " ^ name, binderTy (sp, stamp), tp); (name, stamp, tp, global, sp))
                      | _ => stop ("slot", sp, "a layered pattern without its variable")
            in (tp, b :: bs) end
        | POr (p1 :: rest, sp, _) =>
            (* an extension (--or-patterns): the alternatives of one type, binding the same variables *)
            let
              val (t1, bs1) = synthPat (c, p1)
              val () = List.app (fn p =>
                                    let val (t, bs) = synthPat (c, p)
                                    in
                                      expect ("or-pattern", sp, "an alternative", t1, t);
                                      if List.length bs = List.length bs1
                                         andalso List.all (fn (n, s, _, _, _) => List.exists (fn (n', s', _, _, _) => n = n' andalso s = s') bs1) bs
                                      then () else alarm ("or-pattern", sp, "the alternatives bind other variables")
                                    end) rest
            in (t1, bs1) end
        | POr ([], sp, _) => stop ("or-pattern", sp, "an empty or-pattern")

      fun bindingsCtx (c : ctx, bs : binding list) : ctx =
        {env = plus (#env c, ownVals (List.map (fn (n, s, t, g, _) => (n, LVal {stamp = s, scheme = {bound = [], ty = t}, global = g})) bs)),
         ftv = List.foldl (fn ((_, _, t, _, _), m) => addFtv (m, tyvars t)) (#ftv c) bs,
         scope = #scope c}

      (* the names in the types of an environment's values, for a let's
         escape: AstLint's own layers, and the elaborator's as it checks
         them (Env.noEscape), every value *)
      fun envMentions (layers : env, made : int list) : bool =
        let
          fun ty t = List.exists (fn s => member (s, made)) (names t)
          fun vstat v =
            case v of
              LVal {scheme, ...} => ty (#ty scheme) | LCon {scheme, ...} => ty (#ty scheme) | LExn {ty = t, ...} => ty t
            | LPrim {scheme, ...} => ty (#ty scheme) | LConAsVal {scheme, ...} => ty (#ty scheme) | LExnAsVal {ty = t, ...} => ty t
          fun exists p m = StringMap.foldl (fn (v, b) => b orelse p v) false m
          fun base e = exists (fn v => vstat (convVal v)) (Env.vals e) orelse exists base (Env.strs e)
          fun layer l =
            case l of
              Own {vals, strs, ...} => exists vstat vals orelse exists (fn s => List.exists layer (layersOf s)) strs
            | Base e => base e
        in List.exists layer layers end

      (* ---- expressions (rules 1-14) ---- *)
      fun synthExp (c : ctx, e : exp) : S.ty =
        let val t = synthExp0 (c, e) in note {kind = kindOfExp e, span = spanOfExp e, ty = t, own = []}; t end
      and synthExp0 (c : ctx, e : exp) : S.ty =
        case e of
          EScon (sc, slot, sp, _) => let val t = slotTy (sp, "a constant", !slot, "constant") in checkScon (sp, sc, t); t end
        | EVar (longid as (_, name), slot, sp, _) =>
            let
              (* rule 2: the instance the slot holds, of the scheme the context gives *)
              val inst = slotTy (sp, name, Option.map infoTy (!slot), "instance")
              val v = case findVal (#env c, longid) of
                        SOME v => v
                      | NONE => stop ("2 unbound", sp, longidToString longid ^ " is not in the context")
              fun instance (scheme : scheme) =
                if matchScheme (sp, name, scheme, inst) then ()
                else alarm ("2 instance", sp, name ^ " at " ^ show inst ^ ", no instance of " ^ show (#ty scheme))
            in
              (case (!slot, v) of
                 (SOME (VLocal (s, _)), LVal {stamp, scheme, global}) =>
                   (if s = stamp andalso not global then () else alarm ("2 identity", sp, name ^ ": another variable in the context");
                    instance scheme)
               | (SOME (VGlobal (s, _)), LVal {stamp, scheme, global}) =>
                   (if s = stamp andalso global then () else alarm ("2 identity", sp, name ^ ": another variable in the context");
                    instance scheme)
               | (SOME (VCon (info, _)), LCon {scheme, info = i}) =>
                   (if sameCon (info, i) then () else alarm ("2 identity", sp, name ^ ": another constructor in the context"); instance scheme)
               | (SOME (VExn (info, _)), LExn {ty, info = i}) =>
                   (if sameExn (info, i) then () else alarm ("2 identity", sp, name ^ ": another exception in the context");
                    expect ("2 instance", sp, "exception " ^ name, ty, inst))
               | (SOME (VBuiltin (n, _)), LPrim {scheme, name = n'}) =>
                   (if n = n' then () else alarm ("2 identity", sp, name ^ ": another primitive in the context"); instance scheme)
               | (SOME (VConVal (info, _)), LConAsVal {scheme, info = i}) =>
                   (if sameCon (info, i) then () else alarm ("2 identity", sp, name ^ ": another constructor in the context"); instance scheme)
               | (SOME (VExnVal (info, _)), LExnAsVal {ty, info = i}) =>
                   (if sameExn (info, i) then () else alarm ("2 identity", sp, name ^ ": another exception in the context");
                    expect ("2 instance", sp, "exception " ^ name, ty, inst))
               | (NONE, _) => alarm ("slot", sp, name ^ ": an empty slot")
               | _ => alarm ("2 status", sp, name ^ ": the slot and the context give it other statuses"));
              inst
            end
        | ERecord (fields, _, _) => S.record (sortLabels (List.map (fn (l, e, _) => (l, synthExp (c, e))) fields))
        | ETuple ([], _, _) => unitTy
        | ETuple (es, _, _) => S.tuple (List.map (fn e => synthExp (c, e)) es)
        | ESelect (lab, slot, sp, _) =>
            (* Appendix A: #lab is fn {lab = x, ...} => x, at the record the slot holds *)
            let val r = slotTy (sp, "#" ^ lab, !slot, "select")
            in
              case S.node r of
                S.Record fs =>
                  (case List.find (fn (l, _) => l = lab) fs of
                     SOME (_, t) => S.arrow (r, t)
                   | NONE => stop ("38 record", sp, "#" ^ lab ^ " of " ^ show r))
              | _ => stop ("38 record", sp, "#" ^ lab ^ " of a record left open, " ^ show r)
            end
        | EList ([], slot, sp, _) =>
            let val t = slotTy (sp, "[]", !slot, "nil")
            in
              (case S.node t of
                 S.Con {stamp, args = [_], ...} => if stamp = listStamp then () else alarm ("2 instance", sp, "[] at " ^ show t)
               | _ => alarm ("2 instance", sp, "[] at " ^ show t));
              t
            end
        | EList (es, slot, sp, _) =>
            let
              val ts = List.map (fn e => synthExp (c, e)) es
              val t1 = List.hd ts
            in
              List.app (fn t => expect ("A list", sp, "a list's element", t1, t)) (List.tl ts);
              slotAgrees (sp, "a list", !slot, listTy t1);
              listTy t1
            end
        | ESeq (es, _, _) => List.foldl (fn (e, _) => synthExp (c, e)) unitTy es
        | ELet (decs, body, sp, _) =>
            (* rule 4, and the names declared in it, which may not escape
               (Rune's check, at a let: its type and its context) *)
            let
              val made = ref []
              val delta = checkDecs (c, decs, made)
              val t = synthExp (extend (c, delta), body)
              val () = if List.null (!made) then ()
                       else if List.exists (fn s => member (s, !made)) (names t)
                       then alarm ("4 escape", sp, "a type name the let declares escapes in its type, " ^ show t)
                       else if envMentions (#env c, !made)
                       then alarm ("4 escape", sp, "a type name the let declares escapes into its context")
                       else ()
            in t end
        | EApp (f, a, sp, _) =>
            (* rule 8 *)
            let
              val tf = synthExp (c, f)
              val ta = synthExp (c, a)
            in
              case S.node tf of
                S.Arrow (d, r) => (expect ("8 application", sp, "the argument", d, ta); r)
              | _ => stop ("8 application", sp, "a function of type " ^ show tf)
            end
        | ETyped (e, ty, sp, _) =>
            (* rule 9 *)
            let val te = synthExp (c, e)
                val ta = elabTy (c, ty)
            in expect ("9 annotation", sp, "the annotation", ta, te); ta end
        | EAndalso (a, b, sp, _) =>
            (expect ("A andalso", sp, "andalso's operand", boolTy, synthExp (c, a));
             expect ("A andalso", sp, "andalso's operand", boolTy, synthExp (c, b)); boolTy)
        | EOrelse (a, b, sp, _) =>
            (expect ("A orelse", sp, "orelse's operand", boolTy, synthExp (c, a));
             expect ("A orelse", sp, "orelse's operand", boolTy, synthExp (c, b)); boolTy)
        | EHandle (e, rules, sp, _) =>
            (* rule 10 *)
            let
              val te = synthExp (c, e)
              val (targ, tres) = synthMatch (c, rules, sp)
            in expect ("10 handle", sp, "a handler's pattern", exnTy, targ); expect ("10 handle", sp, "a handler's result", te, tres); te end
        | ERaise (e, sp, n) =>
            (* rule 11 *)
            (expect ("11 raise", sp, "the exception raised", exnTy, synthExp (c, e));
             witnessed (#nodeType reader, n, sp, "a raise", "raise"))
        | EIf (a, b, d, sp, _) =>
            let
              val () = expect ("A if", sp, "the condition", boolTy, synthExp (c, a))
              val tb = synthExp (c, b)
              val td = synthExp (c, d)
            in expect ("A if", sp, "the branches", tb, td); tb end
        | EWhile (a, b, sp, _) => (expect ("A while", sp, "the condition", boolTy, synthExp (c, a)); ignore (synthExp (c, b)); unitTy)
        | ECase (e, rules, sp, _) =>
            let
              val te = synthExp (c, e)
              val (targ, tres) = synthMatch (c, rules, sp)
            in expect ("A case", sp, "the patterns", te, targ); tres end
        | EFn (rules, slot, sp, _) =>
            (* rule 12 *)
            let val (targ, tres) = synthMatch (c, rules, sp)
                val t = S.arrow (targ, tres)
            in slotAgrees (sp, "fn", !slot, t); t end
        | EPrim (_, ty, slot, sp, _) =>
            (* an extension (_prim, the Basis's), its annotation trusted *)
            let val t = elabTy (c, ty) in slotAgrees (sp, "_prim", !slot, t); t end

      (* rules 13, 14 *)
      and synthMatch (c : ctx, rules : mrule list, sp) : S.ty * S.ty =
        let
          val rs = List.map (fn (p, e) => let val (tp, bs) = synthPat (c, p) in (tp, synthExp (bindingsCtx (c, bs), e)) end) rules
          val (a1, r1) = List.hd rs
        in
          List.app (fn (a, r) => (expect ("13 match", sp, "a rule's pattern", a1, a); expect ("13 match", sp, "a rule's result", r1, r)))
                   (List.tl rs);
          (a1, r1)
        end

      (* ---- declarations (rules 15-27); made collects the type names declared ---- *)
      and checkDecs (c : ctx, decs : dec list, made) : env =
        #2 (List.foldl (fn (d, (c, delta)) => let val d' = checkDec (c, d, made) in (extend (c, d'), plus (delta, d')) end) (c, []) decs)

      (* rule 15's Clos, AstLint's own: the variables of the binding's type
         not free in C, where the expression is non-expansive (4.7), none
         otherwise -- against what the elaborator generalised at the
         binding; and rule 15's side condition, that an explicit type
         variable scoped here is generalised *)
      and closure (c : ctx, us : int list, sp, t : S.ty, nonexp : bool, node : int, what) : int list =
        let
          val mine = if nonexp then List.filter (fn v => not (IntMap.member (#ftv c, v))) (tyvars t) else []
          (* each variable the elaborator generalised, as it is after
             finish: a flexible record's row settled since by its uses
             (4.11.program, --flex-records) is the variables of the record
             it became *)
          val theirs = case entry (#generalised reader, node) of
                         SOME rs => List.foldl (fn (r, acc) => List.foldl (fn (v, acc) => if member (v, acc) then acc else v :: acc)
                                                                          acc (tyvars (zonk (Types.TVar r)))) [] rs
                       | NONE => []
          val theirs = case theirs of _ :: rest => if faulty "generalise" then rest else theirs | [] => []
          val () = if sameSet (mine, theirs) then ()
                   else alarm ("15 Clos", sp, what ^ ": Clos generalises " ^ Int.toString (List.length mine) ^ " variables of "
                                              ^ show t ^ ", the elaborator " ^ Int.toString (List.length theirs)
                                              ^ (if nonexp then "" else " (the expression is expansive, 4.7)"))
          val free = List.filter (fn v => not (member (v, mine))) (tyvars t)
          val () = if List.exists (fn u => member (u, free)) us
                   then alarm ("15 scope", sp, what ^ ": an explicit type variable scoped here is not generalised") else ()
        in mine end

      and checkDec (c : ctx, d : dec, made) : env =
        case d of
          DVal (tvs, binds, sp, _) =>
            (* rule 15, its valbind by rules 25, 26 *)
            let
              val (ci, us) = valScope (c, tvs, d, sp)
              val vals =
                List.map (fn (p, e) =>
                             let
                               val te = synthExp (ci, e)
                               val (tp, bs) = synthPat (ci, p)
                               val () = expect ("25 binding", spanOfPat p, "the value bound", tp, te)
                               val g = closure (c, us, spanOfPat p, tp, nonexpansive (c, e), idOfPat p, "val")
                             in
                               List.map (fn (n, s, t, gl, bsp) =>
                                            let val own = List.filter (fn v => member (v, tyvars t)) g
                                            in
                                              note {kind = "binder", span = bsp, ty = t, own = own};
                                              (n, LVal {stamp = s, scheme = {bound = own, ty = t}, global = gl})
                                            end) bs
                             end) binds
            in ownVals (List.concat vals) end
        | DValRec (tvs, binds, sp, _) =>
            (* rule 26 *)
            let
              val (ci, us) = valScope (c, tvs, d, sp)
              fun vars p =
                case p of
                  PVar (([], n), slot, psp, _) => ([(n, slot, psp)], [])
                | PWild _ => ([], [])
                | PTyped (p, t, _, _) => let val (vs, ts) = vars p in (vs, t :: ts) end
                | PLayered (n, t, p, slot, psp, _) =>
                    let val (vs, ts) = vars p in ((n, slot, psp) :: vs, (case t of SOME t => [t] | NONE => []) @ ts) end
                | _ => stop ("26 rec", spanOfPat p, "a val rec pattern of other than variables")
              val prepared =
                List.map (fn (p, e) =>
                             let
                               val (vs, tys) = vars p
                               val bs = List.map (fn (n, slot, psp) =>
                                                     case !slot of
                                                       SOME (PIVar (s, g)) => (n, s, binderTy (psp, s), g, psp)
                                                     | _ => stop ("slot", psp, "a val rec variable without its slot")) vs
                             in (p, e, tys, bs) end) binds
              val crec = bindingsCtx (ci, List.concat (List.map #4 prepared))
              fun isFn (EFn _) = true | isFn (ETyped (e, _, _, _)) = isFn e | isFn _ = false
              val typed =
                List.map (fn (p, e, tys, bs) =>
                             let
                               val te = synthExp (crec, e)
                               val t = case bs of (_, _, t, _, _) :: _ => t | [] => te
                             in
                               List.app (fn (n, _, t', _, _) => expect ("26 rec", spanOfPat p, "val rec's " ^ n, t, t')) bs;
                               List.app (fn ty => expect ("26 annotation", spanOfPat p, "a val rec annotation", elabTy (ci, ty), t)) tys;
                               if isFn e then () else alarm ("26 rec", spanOfExp e, "val rec of other than fn");
                               expect ("26 rec", spanOfExp e, "the function bound", t, te);
                               (p, t, bs)
                             end) prepared
              val vals =
                List.map (fn (p, t, bs) =>
                             let val g = closure (c, us, spanOfPat p, t, true, idOfPat p, "val rec")
                             in
                               List.map (fn (n, s, t, gl, bsp) =>
                                            (note {kind = "binder", span = bsp, ty = t, own = g};
                                             (n, LVal {stamp = s, scheme = {bound = g, ty = t}, global = gl}))) bs
                             end) typed
            in ownVals (List.concat vals) end
        | DFun (tvs, fundefs, sp, _) =>
            (* Appendix A: fun is val rec of a fn of its clauses *)
            let
              val (ci, us) = valScope (c, tvs, d, sp)
              val prepared =
                List.map (fn (f : fundef) =>
                             case !(#info f) of
                               SOME (PIVar (s, g)) => let val t = binderTy (#span f, s) in (f, t, (#name f, s, t, g, #span f)) end
                             | _ => stop ("slot", #span f, "fun " ^ #name f ^ " without its slot")) fundefs
              val crec = bindingsCtx (ci, List.map #3 prepared)
              val () =
                List.app (fn (f : fundef, t, _) =>
                             List.app (fn ({pats, resty, body, span, ...} : clause) =>
                                          let
                                            val rs = List.map (fn p => synthPat (crec, p)) pats
                                            val tb = synthExp (bindingsCtx (crec, List.concat (List.map #2 rs)), body)
                                            val () = case resty of
                                                       SOME ty => expect ("9 annotation", spanOfExp body, "a result annotation", elabTy (ci, ty), tb)
                                                     | NONE => ()
                                            val ct = List.foldr (fn ((a, _), r) => S.arrow (a, r)) tb rs
                                          in expect ("13 match", span, "a clause of " ^ #name f, t, ct) end)
                                      (#clauses f)) prepared
              val vals =
                List.map (fn (f : fundef, t, (n, s, _, gl, _)) =>
                             let
                               val g = closure (c, us, #span f, t, true, #id f, "fun " ^ n)
                               (* the function's name where a clause begins with it (not
                                  an infix clause's), for the editor *)
                               val () = List.app (fn ({pats, span, ...} : clause) =>
                                                     let val stop = #start span + size n
                                                     in case pats of
                                                          p :: _ => if #start (spanOfPat p) >= stop
                                                                    then note {kind = "binder", span = {file = #file span, start = #start span, stop = stop},
                                                                               ty = t, own = g}
                                                                    else ()
                                                        | [] => ()
                                                     end) (#clauses f)
                             in (n, LVal {stamp = s, scheme = {bound = g, ty = t}, global = gl}) end) prepared
            in ownVals vals end
        | DType (tbs, _, _) =>
            (* rules 16, 27; the explicit type variables in scope seen in
               the abbreviation, as Rune reads it (4.4.scoped) *)
            ownTys (List.map (fn (tb : typbind) =>
                                 let
                                   val ps = List.map (fn (v, _) => (v, ownVar (String.isPrefix "''" v))) (#tyvars tb)
                                   val scope = List.foldl (fn ((v, (_, t)), m) => StringMap.insert (m, v, t)) (#scope c) ps
                                   val body = elabTy ({env = #env c, ftv = #ftv c, scope = scope}, #ty tb)
                                 in (#name tb, TS {fcn = FAbbrev (List.map (#1 o #2) ps, body), cons = []}) end) tbs)
        | DDatatype (dbs, tbs, sp, n) =>
            (* rule 17, its datbinds by rule 28, the names new ones *)
            let
              val created = case entry (#created reader, n) of
                              SOME cs => cs
                            | NONE => stop ("17 datatype", sp, "no record of the names the datatype declaration created")
              val names' =
                List.map (fn (db : datbind) =>
                             case List.find (fn (tc : Types.tycon) => #name tc = #name db) created of
                               SOME tc => (db, tc)
                             | NONE => stop ("17 datatype", #span db, "no name created for " ^ #name db)) dbs
              val () = made := List.map (fn (_, tc : Types.tycon) => #stamp tc) names' @ !made
              val c1 = extend (c, ownTys (List.map (fn (db : datbind, tc : Types.tycon) =>
                                                       (#name db, TS {fcn = FName {stamp = #stamp tc, name = #name tc, arity = #arity tc, eq = #eq tc},
                                                                      cons = []})) names'))
              val abbrevs = checkDec (c1, DType (tbs, sp, noId), made)
              val c2 = extend (c1, abbrevs)
              val groups =
                List.map (fn (db : datbind, tc : Types.tycon) =>
                             let
                               val ps = List.map (fn (v, _) => (v, ownVar (String.isPrefix "''" v))) (#tyvars db)
                               val scope = List.foldl (fn ((v, (_, t)), m) => StringMap.insert (m, v, t)) (#scope c) ps
                               val cs = {env = #env c2, ftv = #ftv c2, scope = scope}
                               val res = S.con (#stamp tc, #name tc, List.map (#2 o #2) ps)
                               val bound = List.map (#1 o #2) ps
                               val cons = List.map (fn (n, arg, _) =>
                                                       let val a = Option.map (fn t => elabTy (cs, t)) arg
                                                       in (n, a, {bound = bound, ty = case a of SOME a => S.arrow (a, res) | NONE => res}) end)
                                                   (#cons db)
                             in (db, tc, cons) end) names'
              (* 4.9: equality maximised, AstLint's own fixed point *)
              fun admitsUnder assume t =
                case S.node t of
                  S.Var _ => true
                | S.Con {stamp, args, ...} =>
                    (case List.find (fn (s, _) => s = stamp) assume of
                       SOME (_, b) => b andalso List.all (admitsUnder assume) args
                     | NONE => stamp = refStamp orelse stamp = arrayStamp orelse (nameEq stamp andalso List.all (admitsUnder assume) args))
                | S.Record fs => List.all (admitsUnder assume o #2) fs
                | S.Arrow _ => false
                | S.Flex _ => false
              fun iterate assume =
                let val next = List.map (fn (_, tc : Types.tycon, cons) =>
                                            (#stamp tc, List.all (fn (_, a, _) => case a of SOME a => admitsUnder assume a | NONE => true) cons))
                                        groups
                in if next = assume then assume else iterate next end
              val final = iterate (List.map (fn (_, tc : Types.tycon, _) => (#stamp tc, true)) groups)
              val () = List.app (fn (db : datbind, tc : Types.tycon, _) =>
                                    let
                                      val mine = #2 (valOf (List.find (fn (s, _) => s = #stamp tc) final))
                                      val theirs = if faulty "equality" then not (#eq tc) else #eq tc
                                    in
                                      if mine = theirs then ()
                                      else alarm ("4.9 equality", #span db, "datatype " ^ #name db ^ ": maximised, its equality is "
                                                                           ^ Bool.toString mine ^ ", the elaborator's " ^ Bool.toString theirs);
                                      IntTable.insert (eqOf, #stamp tc, mine)
                                    end) groups
              val tys = List.map (fn (db : datbind, tc : Types.tycon, cons) =>
                                     let
                                       val k = List.length cons
                                       val cs = List.map (fn (cn, a, scheme) =>
                                                             (cn, LCon {scheme = scheme, info = {name = cn, tag = ~1, hasArg = isSome a, ncons = k,
                                                                                                 isRef = false, siblings = []}})) cons
                                     in (#name db, TS {fcn = FName {stamp = #stamp tc, name = #name tc, arity = #arity tc, eq = #eq tc}, cons = cs}, cs) end)
                                 groups
            in plus (abbrevs, plus (ownTys (List.map (fn (n, ts, _) => (n, ts)) tys), ownVals (List.concat (List.map #3 tys)))) end
        | DDatatypeRepl (name, longid, sp, _) =>
            (* rule 18 *)
            (case findTy (#env c, longid) of
               SOME (ts as TS {cons, ...}) => plus (ownTys [(name, ts)], ownVals cons)
             | NONE => stop ("18 datatype", sp, "datatype " ^ longidToString longid ^ " is not in the context"))
        | DAbstype (dbs, tbs, decs, sp, n) =>
            (* rule 19, as Rune reads Abs: the same names, without their
               constructors and without equality outside *)
            let
              val delta1 = checkDec (c, DDatatype (dbs, tbs, sp, n), made)
              val delta2 = checkDecs (extend (c, delta1), decs, made)
              val abs = List.mapPartial (fn db : datbind =>
                                            case findTyIn (delta1, #name db) of
                                              SOME (TS {fcn = fcn as FName {stamp, ...}, ...}) =>
                                                (IntTable.insert (eqOf, stamp, false); SOME (#name db, TS {fcn = fcn, cons = []}))
                                            | _ => NONE) dbs
            in plus (ownTys abs, delta2) end
        | DException (ebs, _, _) =>
            (* rules 20, 30, 31 *)
            ownVals (List.map (fn ExnDecl (name, tyopt, slot, sp, _) =>
                                    (case !slot of
                                       SOME (PIExn info) =>
                                         (name, LExn {ty = case tyopt of SOME t => S.arrow (elabTy (c, t), exnTy) | NONE => exnTy, info = info})
                                     | _ => stop ("slot", sp, "exception " ^ name ^ " without its slot"))
                                | ExnRepl (name, longid, slot, sp, _) =>
                                    (case (findVal (#env c, longid), !slot) of
                                       (SOME (v as LExn {info, ...}), SOME (PIExn i)) =>
                                         (if #stamp info = #stamp i then () else alarm ("31 identity", sp, "exception " ^ name ^ ": another exception");
                                          (name, v))
                                     | _ => stop ("31 identity", sp, "exception " ^ name ^ ": the replication of a non-exception"))) ebs)
        | DLocal (d1, d2, _, _) =>
            (* rule 23 *)
            let val delta1 = checkDecs (c, d1, made)
            in checkDecs (extend (c, delta1), d2, made) end
        | DOpen (ids, sp, _) =>
            (* rule 22 *)
            List.foldl (fn ((path, name), delta) =>
                           case findPath (#env c, path @ [name]) of
                             SOME e => plus (delta, e)
                           | NONE => stop ("22 open", sp, "structure " ^ longidToString (path, name) ^ " is not in the context")) [] ids
        | DInfix _ => []
        | DInfixr _ => []
        | DNonfix _ => []
        | DOverload _ => []
        | DStructure (binds, _, _) =>
            [Own {vals = StringMap.empty, tys = StringMap.empty,
                  strs = List.foldl (fn (b : strbind, m) => StringMap.insert (m, #name b, checkStrexp (c, #strexp b, made))) StringMap.empty binds}]
        | DSignature _ => []
        | DFunctor (binds, _, _) =>
            (List.app (fn (b : funbind) => functorsSeen := StringMap.insert (!functorsSeen, #name b,
                                                           1 + getOpt (StringMap.find (!functorsSeen, #name b), 0))) binds;
             List.app (fn (b : funbind) =>
                          let
                            val pe = case entry (#functorParam reader, #id b) of
                                       SOME e => e
                                     | NONE => stop ("86 functor", #span b, "no record of functor " ^ #name b ^ "'s parameter")
                            val cb = case #param b of
                                       SOME x => extend (c, [Own {vals = StringMap.empty, tys = StringMap.empty,
                                                                  strs = StringMap.insert (StringMap.empty, x, SBase pe)}])
                                     | NONE => extend (c, [Base pe])
                          in ignore (checkStrexp (cb, #body b, ref [])) end) binds;
             [])

      and checkStrexp (c : ctx, se : strexp, made) : str =
        case se of
          StrStruct (decs, _, _) => SOwn (checkDecs (c, decs, made))
        | StrId ((path, name), sp, _) =>
            (case findPath (#env c, path @ [name]) of
               SOME e => SOwn e
             | NONE => stop ("51 structure", sp, "structure " ^ longidToString (path, name) ^ " is not in the context"))
        | StrAscribe (se, _, false, sp, n) =>
            (* rule 52: the structure enriches the result the elaborator
               made of the signature, which its types and identities are *)
            let val actual = checkStrexp (c, se, made)
                val result = axiom (n, sp, "an ascription")
            in
              (case (observe, result) of
                 (NONE, SBase e) => enrich (sp, [], IntMap.empty, e, layersOf actual, true)
               | _ => ());
              result
            end
        | StrAscribe (se, _, true, sp, n) => (ignore (checkStrexp (c, se, made)); axiom (n, sp, "an ascription"))
        | StrApp (funid, arg, sp, n) =>
            (* rule 54's match: the argument enriches the parameter's
               signature, its bound names realised by paths (5.6); the
               application's result is taken as given *)
            let val actual = checkStrexp (c, arg, made)
            in
              (case (observe, StringMap.find (!Elaborate.funs, funid)) of
                 (NONE, SOME (Elaborate.FunInfo {paramSig = {bound, env = pEnv, ...}, ...})) =>
                   if not (lastBinding funid) then ()
                   else
                     let val layers = layersOf actual
                         val phi = phiByPaths (sp, bound, pEnv, layers)
                     in enrich (sp, [], phi, pEnv, layers, false) end
               | _ => ());
              axiom (n, sp, "a functor's application")
            end
        | StrLet (decs, body, _, _) => let val delta = checkDecs (c, decs, made) in checkStrexp (extend (c, delta), body, made) end
        | StrDynamic (_, _, _, sp, n) => axiom (n, sp, "a dynamic module")
        | StrExport (_, _, body, _, sp, n) => (ignore (checkStrexp (c, body, made)); axiom (n, sp, "an export"))
      and axiom (n, sp, what) : str =
        case entry (#moduleResult reader, n) of
          SOME e => SBase e
        | NONE => stop ("D5 axiom", sp, "no record of the result of " ^ what)

      (* ---- a declaration at top level: its result against the
         elaborator's, and rules 87-89's closure of what it leaves ---- *)
      fun compareDelta (sp, mine : env, theirs : Env.env) =
        let
          fun vals (prefix, layers : env, e : Env.env) =
            (StringMap.appi (fn (n, v) =>
                                case (findValIn (layers, n), v) of
                                  (SOME (LVal {stamp, scheme, ...}), Env.Val {stamp = s, scheme = sc, ...}) =>
                                    let
                                      val z = zonk sc
                                      val z = if faulty "result" then other z else z
                                    in
                                      if stamp <> s then alarm ("result", sp, prefix ^ n ^ ": another variable") else ();
                                      if S.same (#ty scheme, z) andalso sameSet (#bound scheme, genericVars z) then ()
                                      else alarm ("result", sp, prefix ^ n ^ ": its scheme is " ^ show (#ty scheme) ^ " ("
                                                                ^ Int.toString (List.length (#bound scheme)) ^ " bound), the elaborator's "
                                                                ^ show z ^ " (" ^ Int.toString (List.length (genericVars z)) ^ " bound)")
                                    end
                                | (SOME (LExn {info, ...}), Env.Exn {info = i, ...}) =>
                                    if #stamp info = #stamp i then () else alarm ("result", sp, prefix ^ n ^ ": another exception")
                                | (SOME _, _) => ()
                                | (NONE, _) => alarm ("result", sp, prefix ^ n ^ ": not in what the declaration declares")) (Env.vals e);
             StringMap.appi (fn (n, sub) =>
                                case findStrIn (layers, n) of
                                  SOME (SOwn l) => vals (prefix ^ n ^ ".", l, sub)
                                | SOME (SBase _) => ()
                                | NONE => alarm ("result", sp, prefix ^ n ^ ": a structure not in what the declaration declares")) (Env.strs e))
        in vals ("", mine, theirs) end
      fun closed (sp, delta : env) =
        case ownFree delta of
          [] => ()
        | _ => alarm ("87 closure", sp, "the declaration leaves a free type variable in the basis")

      val checked = ref 0
      val skipped = ref 0
      fun top {dec, env, delta} =
        let
          val sp = spanOfDec dec
          val c0 = {env = [Base env], ftv = IntMap.empty, scope = StringMap.empty}
        in
          ((if fatal then S.batch else S.batchFinished)
             (fn () => let val mine = checkDec (c0, dec, ref [])
                       in case observe of NONE => (compareDelta (sp, mine, delta); closed (sp, mine)) | SOME _ => () end);
           checked := !checked + 1)
          handle Stop => checked := !checked + 1
               | S.Budget => skipped := !skipped + 1
        end
      val () = List.app top tops
    in
      if !nalarms = 0 orelse not fatal then {checked = !checked, skipped = !skipped, alarms = !nalarms}
      else
        raise Error.Bug ("astlint: " ^ Int.toString (!nalarms) ^ " alarm(s) in " ^ Int.toString (!checked) ^ " declarations: "
                         ^ String.concatWith "; " (List.map (fn (rule, sp, msg) => Source.describe sp ^ ": [" ^ rule ^ "] " ^ msg)
                                                             (List.rev (!alarms))))
    end

  (* What the driver runs after Elaborate.finish (Pass.checkAt ("astlint",
     2)): the declarations elaborated since the records were last dropped,
     which are dropped after *)
  fun run tops = runWith {reader = global, observe = NONE, fatal = true} tops
  fun check () : unit =
    let val tops = List.rev (!Elaborate.tops)
    in (ignore (run tops); Elaborate.forgetLintRecords ()) handle e => (Elaborate.forgetLintRecords (); raise e) end

  (* The typer the editor uses (CompilerNodeTypes): a declaration's every
     node worked out as AstLint works it out, from what a reader gives, each
     node handed to observe; nothing an alarm would find stops it but where
     no type can be worked out further (a missing witness), and the types
     are those of a finished unit (SourceTy.batchFinished, so the caller
     vouches that its unit's elaboration has ended) *)
  fun typeDecl (reader : reader, observe : node -> unit, top : {dec : dec, env : Env.env, delta : Env.env}) : unit =
    ignore (runWith {reader = reader, observe = SOME observe, fatal = false} [top])
end
