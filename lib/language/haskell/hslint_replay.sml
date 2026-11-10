(* HsLint's replay of Faxén's rules (the haskell98 roadmap's M16, D54;
   Faxén 2002, A Static Semantics for Haskell) on the program and the
   checker's evidence records (D31): each record held to the rule that
   makes it, a breach refused as `[RULE] ...`, the rule's name his.

   - [bindg]: Rule 1 by his bindg with Definition 2 (MonoRes, p 338): a
     group of bindings that is not unrestricted abstracts over no
     dictionary. His Definition 2 reads a simple pattern binding as a
     single variable; it is amended to 4.5.5's, guards allowed and `(x)`
     and `~x` not simple (R18, D32), as his deviations of 2.2, 4.2 and 4.3
     are.
   - [dict tuple], [dict var], [dict inst], [dict super] (his fig. 28):
     every dictionary a record holds proves the predicate its place wants:
     a use's, one for each predicate of its variable's context at the
     types it is used at; a construct's, one for each class its
     translation names; a parameter of an enclosing abstraction of that
     predicate; an instance's dictionary function at its head's types, of
     its context's dictionaries; a superclass's from a dictionary of a
     subclass. Where the rules admit two (`dict inst` against `dict
     super`, 10.2.2), the record's choice is read, not derived.
   - [super]: an instance's superclasses' dictionaries are one for each of
     its class's direct superclasses, in their order (a superclass path).
   - [method]: an instance's method is bound at its class's type for the
     method at the instance (a method's slot).
   - [scc], rhc's own: his rules are per module, and recursive modules
     have none of his (1.3); a group of bindings across a cycle's modules
     is one bindG, whose binders share one context, and a variable
     defaulted where each module's `default` holds (D30) is defaulted by
     the module its predicates arose in.

   The classes, instances and superclasses replay reads are HsLint's own
   (HsLintEnv, HsLintClasses); of the checker it reads the records and the
   types of the values its uses instantiate (`HsInfer.valueScheme`), which
   say what a use's types are in order. A derived instance's methods,
   which HsDerive makes as the tree a user would write (M14), are read as
   any instance's (D54); his rules have none for deriving (1.3), so a
   derived instance's context is HsLint's own, the least the second
   inference finds by 10.1's fixpoint, and [dict inst] holds the
   checker's dictionaries to it.

   RHC_HSLINT_FAULT=RULE reads the first record RULE checks corrupted, so
   that RULE, and no other, refuses it. *)
structure HsLintReplay =
struct
  structure A = HsAst
  structure T = HsLintTypes
  structure C = HsLintClasses
  structure E = HsLintEnv
  structure M = HsStringMap
  structure H = HsTypes
  structure V = HsEvidence

  fun breach (span, rule, msg) = raise T.Refuse (span, "[" ^ rule ^ "] " ^ msg)

  val fault = ref ""
  fun faulty rule = if !fault = rule then (fault := ""; true) else false

  (* ---- the checker's types as HsLint's ---- *)

  val idOfKey = E.idOfKey

  (* a rigid variable's name, unique to the program: the checker's names
     carry their numbers already *)
  fun rigidName ({id, name} : H.rigid) =
    if String.isSuffix ("_" ^ Int.toString id) name then name else name ^ "_" ^ Int.toString id

  (* a rigid variable as a constant of its own *)
  fun rigid n = T.TCon {id = {qual = "'", name = n}, kind = T.Star}

  fun conv (t : H.ty) : T.ty =
    case t of
      H.TCon k => let val q = idOfKey k in T.TCon {id = q, kind = getOpt (E.tyconKind q, T.Star)} end
    | H.TAp (a, b) => T.TAp (conv a, conv b)
    | H.TRigid r => rigid (rigidName r)
    | H.TGen i => T.TGen i
    | H.TMeta m => (case !m of H.Link t' => conv t' | H.Free {id, ...} => rigid ("?" ^ Int.toString id))

  fun convPred ({cls, ty} : H.pred) = T.IsIn (idOfKey cls, conv ty)

  (* the checker's type with a scheme's named variables replaced *)
  fun substNamed (vars : string list, tys : H.ty list) (t : H.ty) : H.ty =
    case t of
      H.TRigid r =>
        let
          fun find ([], _) = t
            | find (v :: vs, u :: us) = if v = rigidName r orelse v = #name r then u else find (vs, us)
            | find (_ :: _, []) = t
        in
          find (vars, tys)
        end
    | H.TAp (a, b) => H.TAp (substNamed (vars, tys) a, substNamed (vars, tys) b)
    | H.TMeta m => (case !m of H.Link t' => substNamed (vars, tys) t' | _ => t)
    | _ => t

  (* ---- the source: names, literals, binders and groups, by span ---- *)

  fun spanKey ({file, start, stop} : HsSource.span) = file ^ ":" ^ Int.toString start ^ "-" ^ Int.toString stop

  (* the span of a node's key, `FILE:START-STOP` *)
  fun spanOfKey k =
    let
      fun lastColon i = if i < 0 then NONE else if String.sub (k, i) = #":" then SOME i else lastColon (i - 1)
    in
      case lastColon (size k - 1) of
        SOME i =>
          (case String.fields (fn c => c = #"-") (String.extract (k, i + 1, NONE)) of
             [a, b] => {file = String.substring (k, 0, i), start = getOpt (Int.fromString a, 0),
                        stop = getOpt (Int.fromString b, 0)}
           | _ => HsSource.noSpan)
      | NONE => HsSource.noSpan
    end

  type source = {names : A.qname M.map ref, lits : bool M.map ref, binders : HsSource.span M.map ref,
                 decls : (string * A.decl list) list ref, instances : (HsSource.span * string * A.decl list) list ref}

  fun nameSpan (A.Name ({span, ...}, _)) = span
  fun nameOf (A.Name (_, q)) = q

  (* `walkDecls (mid, decls, src)`: the names, literals, binders and lists
     of declarations of `decls`, of the module `mid` *)
  fun walkDecls (mid, decls, src : source) =
    let
      fun name n = #names src := M.insert (!(#names src), spanKey (nameSpan n), nameOf n)
      (* a local's name is unique in its module alone: keyed by its file *)
      fun binder n = (name n; #binders src := M.insert (!(#binders src), #file (nameSpan n) ^ " " ^ T.idKey (nameOf n), nameSpan n))
      fun lit (span, A.Lit ({span = s, ...}, l)) =
        let val frac = case l of A.LFloat _ => true | _ => false
        in #lits src := M.insert (M.insert (!(#lits src), spanKey span, frac), spanKey s, frac) end
      fun pat (A.P ({span, ...}, x)) =
        case x of
          A.PVar n => binder n
        | A.PLit l => lit (span, l)
        | A.PNegLit l => lit (span, l)
        | A.PCon (c, ps) => (name c; List.app pat ps)
        | A.PRec (c, fs) => (name c; List.app (fn (f, p) => (name f; pat p)) fs)
        | A.PTuple ps => List.app pat ps
        | A.PList ps => List.app pat ps
        | A.PParen p => pat p
        | A.PAs (n, p) => (binder n; pat p)
        | A.PLazy p => pat p
        | A.PNPlusK (n, l) => (binder n; lit (span, l))
        | A.PSeq items => List.app (fn A.PA p => pat p | A.PO (A.ConOp c) => name c | A.PO (A.VarOp v) => name v) items
        | _ => ()
      fun qop (A.VarOp n) = name n
        | qop (A.ConOp n) = name n
      fun exp (A.E ({span, ...}, x)) =
        case x of
          A.EVar n => name n
        | A.ECon n => name n
        | A.ELit l => lit (span, l)
        | A.EApp (f, a) => (exp f; exp a)
        | A.ESeq items => List.app (fn A.EA e => exp e | A.EO q => qop q | A.ENeg => ()) items
        | A.ELam (ps, b) => (List.app pat ps; exp b)
        | A.ELet (ds, b) => (locals ds; exp b)
        | A.EIf (a, b, c) => (exp a; exp b; exp c)
        | A.ECase (e, alts) => (exp e; List.app (fn A.Alt (_, p, r) => (pat p; rhs r)) alts)
        | A.EDo ss => stmts ss
        | A.ETuple es => List.app exp es
        | A.EParen e => exp e
        | A.EList es => List.app exp es
        | A.EEnum (a, b, c) => (exp a; Option.app exp b; Option.app exp c)
        | A.EComp (e, ss) => (stmts ss; exp e)
        | A.ELeftSec (e, q) => (exp e; qop q)
        | A.ERightSec (q, e) => (qop q; exp e)
        | A.ERecCon (c, fs) => (name c; List.app (fn (f, e) => (name f; exp e)) fs)
        | A.ERecUpd (e, fs) => (exp e; List.app (fn (f, e) => (name f; exp e)) fs)
        | A.ESig (e, _, _) => exp e
      and stmts ss =
        List.app (fn A.S (_, s) => case s of A.SBind (p, e) => (exp e; pat p) | A.SLet ds => locals ds | A.SExp e => exp e) ss
      and rhs (A.Rhs (_, x)) =
        case x of
          A.Plain (e, w) => (Option.app locals w; exp e)
        | A.Guarded (gs, w) => (Option.app locals w; List.app (fn A.Guard (_, g, e) => (exp g; exp e)) gs)
      and decl (A.D (_, x)) =
        case x of
          A.DFun (A.F (_, l), r) => (lhs l; rhs r)
        | A.DPat (p, r) => (pat p; rhs r)
        | A.DClass (_, _, _, SOME body) => List.app decl body
        | A.DInstance (_, _, _, SOME body) => List.app decl body
        | _ => ()
      and lhs l =
        case l of
          A.FPrefix (f, ps) => (binder f; List.app pat ps)
        | A.FInfix (p1, A.VarOp f, p2) => (binder f; pat p1; pat p2)
        | A.FInfix (p1, A.ConOp f, p2) => (binder f; pat p1; pat p2)
        | A.FParen (A.F (_, l'), ps) => (lhs l'; List.app pat ps)
      and locals ds = (#decls src := (mid, ds) :: !(#decls src); List.app decl ds)
    in
      List.app decl decls
    end

  fun walk (mid, A.Module (_, {decls, ...}), src : source) =
    (#decls src := (mid, decls) :: !(#decls src);
     walkDecls (mid, decls, src);
     List.app (fn A.D ({span, ...}, A.DInstance (_, c, _, body)) =>
                    #instances src := (span, #name (nameOf c), getOpt (body, [])) :: !(#instances src)
                | _ => ())
       decls)

  (* the span of a binder's first name in a list of declarations *)
  fun firstBinder (decls : A.decl list, id : T.id) : HsSource.span option =
    let
      fun funName (A.F (_, x)) =
        case x of
          A.FPrefix (v, _) => SOME v
        | A.FInfix (_, A.VarOp v, _) => SOME v
        | A.FInfix (_, A.ConOp v, _) => SOME v
        | A.FParen (l, _) => funName l
      fun inPat (A.P (_, x)) =
        case x of
          A.PVar n => if T.idEq (nameOf n, id) then SOME (nameSpan n) else NONE
        | A.PCon (_, ps) => first ps
        | A.PRec (_, fs) => first (List.map #2 fs)
        | A.PTuple ps => first ps
        | A.PList ps => first ps
        | A.PParen p => inPat p
        | A.PAs (n, p) => if T.idEq (nameOf n, id) then SOME (nameSpan n) else inPat p
        | A.PLazy p => inPat p
        | A.PSeq items => first (List.mapPartial (fn A.PA p => SOME p | _ => NONE) items)
        | _ => NONE
      and first [] = NONE
        | first (p :: ps) = case inPat p of SOME s => SOME s | NONE => first ps
      fun go [] = NONE
        | go (A.D (_, x) :: rest) =
            case x of
              A.DFun (f, _) => (case funName f of
                                  SOME n => if T.idEq (nameOf n, id) then SOME (nameSpan n) else go rest
                                | NONE => go rest)
            | A.DPat (p, _) => (case inPat p of SOME s => SOME s | NONE => go rest)
            | _ => go rest
    in
      go decls
    end

  (* ---- the rules ---- *)

  val rules =
    [("bindg", "a restricted group abstracts over no dictionary (Rule 1; Faxen 2002, bindg and Definition 2, p 338)"),
     ("dict tuple", "a use or a construct has one dictionary for each predicate it needs (Faxen 2002, fig. 28, dict tuple)"),
     ("dict var", "a dictionary parameter is one of an enclosing abstraction, of the predicate wanted (fig. 28, dict var)"),
     ("dict inst", "an instance's dictionary is the wanted class's at the wanted type, of its context's (fig. 28, dict inst)"),
     ("dict super", "a superclass's dictionary is taken from a subclass's, one step (fig. 28, dict super)"),
     ("super", "an instance's superclass dictionaries are one for each direct superclass, in the class's order"),
     ("method", "an instance's method is bound at its class's type for it at the instance"),
     ("scc", "a group across a cycle's modules has one context, and is defaulted where its predicates arose (D30)")]

  (* `replay {modules, records, env, derived, cycleDefault, fault}` holds
     the records to the rules, the derived instances' methods' (`derived`,
     as HsDerive made them) as a user's; the classes and instances are
     HsLintClasses' as the second inference left them. *)
  fun replay {modules : E.module list, groups : E.module list list, records : V.table, env : HsInfer.env,
              derived : (string * string * A.decl list) list, cycleDefault : bool, fault = f} =
    let
      val () = fault := f
      val src : source = {names = ref M.empty, lits = ref M.empty, binders = ref M.empty, decls = ref [],
                          instances = ref []}
      val () = List.app (fn {id, ast, ...} => walk (id, ast, src)) modules
      val all = V.all records
      (* a derived instance's methods, made as a user's would be (D54): its
         record is at its class's name in the deriving clause *)
      val instanceAt =
        List.foldl (fn ((key, recs), m) =>
                      List.foldl (fn (V.Instance {inst, ...}, m) =>
                                       if String.isPrefix "instance@" key then M.insert (m, inst, key) else m
                                   | (_, m) => m)
                        m recs)
          M.empty all
      val () =
        List.app (fn (mid, inst, decls) =>
                    (walkDecls (mid, decls, src);
                     case M.find (instanceAt, inst) of
                       SOME key => #instances src := (spanOfKey (String.extract (key, size "instance@", NONE)),
                                                      #name (#1 (E.ofInstanceId inst)), decls)
                                                     :: !(#instances src)
                     | NONE => ()))
          derived
      fun parse key =
        case CharVector.findi (fn (_, c) => c = #"@") key of
          SOME (i, _) => (String.substring (key, 0, i), String.extract (key, i + 1, NONE))
        | NONE => (key, "")
      fun recordsAt (kind, span) = V.find (records, V.node (kind, span))
      (* the parameters of every abstraction: a binder's, a signature's, an
         instance's context's, a class's (by its class alone) *)
      val params : (string * T.pred option) list ref = ref []
      fun addParam (p, q) = params := (p, q) :: !params
      val () =
        List.app
          (fn (key, recs) =>
             List.app
               (fn V.Binding {scheme = {ctx, ...}, params = ps} =>
                     (* a class's default method takes the class's
                        parameter first, then one for each predicate of its
                        own context: the predicates are the last ones *)
                     let val extra = length ps - length ctx
                     in
                       if extra < 0 then ()
                       else ListPair.app (fn (p, q) => addParam (p, SOME (convPred q))) (List.drop (ps, extra), ctx)
                     end
                 | V.Instance {inst, vars, params = ps, ...} =>
                     let
                       val (cls, tc) = E.ofInstanceId inst
                       val ctx =
                         case List.find (fn ({head = T.IsIn (_, h), ...} : C.inst) =>
                                           case T.spine h of (T.TCon {id, ...}, _) => T.idEq (id, tc) | _ => false)
                                (C.instsOf cls) of
                           SOME {context, ...} =>
                             let val ts = Vector.fromList (List.map rigid vars)
                             in List.map (fn p => SOME (T.instPred ts p)) context handle Subscript => [] end
                         | NONE => []
                     in
                       ListPair.app addParam (ps, ctx)
                     end
                 | V.Class {param} => addParam (param, NONE)
                 | _ => ())
               recs)
          all
      val paramOf = fn p => List.find (fn (q, _) => q = p) (!params)

      (* `proves (span, d, p)`: the dictionary `d` proves the predicate `p` *)
      fun proves (span, d, p as T.IsIn (c, t)) =
        case d of
          V.DParam n =>
            let val n = if faulty "dict var" then "dFault" else n
            in
              case paramOf n of
                SOME (_, SOME q) =>
                  if T.predEq (p, q) then ()
                  else breach (span, "dict var", "the parameter " ^ n ^ " is a dictionary of " ^ T.showPred q ^
                                                 ", and " ^ T.showPred p ^ " is wanted")
              | SOME (_, NONE) => ()
              | NONE => breach (span, "dict var", "the dictionary parameter " ^ n ^ " is no parameter of an enclosing " ^
                                                  "abstraction (" ^ T.showPred p ^ " is wanted)")
            end
        | V.DInst {inst, tys, args} =>
            let
              val inst = if faulty "dict inst" then inst ^ "Fault" else inst
              val (cls, tc) = case CharVector.findi (fn (_, ch) => ch = #"@") inst of
                                SOME (i, _) => (idOfKey (String.substring (inst, 0, i)), idOfKey (String.extract (inst, i + 1, NONE)))
                              | NONE => (idOfKey inst, idOfKey "")
              val (h, targs) = T.spine t
              val wanted = case h of T.TCon {id, ...} => SOME id | _ => NONE
              val () =
                if T.idEq (cls, c) andalso (case wanted of SOME w => T.idEq (w, tc) | NONE => false) then ()
                else breach (span, "dict inst", "the instance " ^ #name cls ^ " " ^ #name tc ^ " is given where " ^
                                                T.showPred p ^ " is wanted")
              val tys' = List.map conv tys
              val () =
                if length tys' = length targs andalso ListPair.all T.same (tys', targs) then ()
                else breach (span, "dict inst", "the instance " ^ #name cls ^ " " ^ #name tc ^ " is taken at " ^
                                                String.concatWith " " (List.map (fn t => T.showTyAt (2, t)) tys') ^
                                                ", other than " ^ T.showPred p ^ "'s types")
              val ctx =
                case List.find (fn ({head = T.IsIn (_, hh), ...} : C.inst) =>
                                  case T.spine hh of (T.TCon {id, ...}, _) => T.idEq (id, tc) | _ => false)
                       (C.instsOf c) of
                  SOME {context, arity, ...} =>
                    if arity = length targs then List.map (T.instPred (Vector.fromList targs)) context
                    else breach (span, "dict inst", "the instance " ^ #name cls ^ " " ^ #name tc ^ " has another arity")
                | NONE => breach (span, "dict inst", "no instance " ^ #name cls ^ " " ^ #name tc ^ " is declared or derived")
            in
              if length args = length ctx then ListPair.app (fn (a, q) => proves (span, a, q)) (args, ctx)
              else breach (span, "dict tuple", "the instance " ^ #name cls ^ " " ^ #name tc ^ " is given " ^
                                               Int.toString (length args) ^ " dictionaries for a context of " ^
                                               Int.toString (length ctx))
            end
        | V.DSuper {dict, cls, super} =>
            let
              val super = if faulty "dict super" then cls else super
              val sub = idOfKey cls
              val sup = idOfKey super
            in
              if not (T.idEq (sup, c)) then
                breach (span, "dict super", "a dictionary of " ^ #name sup ^ " is given where " ^ T.showPred p ^ " is wanted")
              else if not (List.exists (fn s => T.idEq (s, sup)) (C.supers sub)) then
                breach (span, "dict super", #name sup ^ " is no direct superclass of " ^ #name sub ^ " (a superclass path)")
              else proves (span, dict, T.IsIn (sub, t))
            end

      (* the context a use instantiates *)
      fun wanted (span, q : A.qname, tys : H.ty list) : T.pred list option =
        if #qual q = "" andalso CharVector.exists (fn c => c = #"#") (#name q) then
          case M.find (!(#binders src), #file span ^ " " ^ T.idKey q) of
            SOME b =>
              (case recordsAt ("bind", b) of
                 V.Binding {scheme = {vars, ctx, ...}, ...} :: _ =>
                   SOME (List.map (fn {cls, ty} => convPred {cls = cls, ty = substNamed (vars, tys) ty}) ctx)
               | V.Mono _ :: _ => SOME []
               | _ => NONE)
          | NONE => NONE
        else if #qual q = "" then SOME []
        else
          case HsInfer.valueScheme (env, HsModules.key {space = HsModules.Value, home = #qual q, name = #name q}) of
            SOME {ctx, ...} => SOME (List.map (fn {cls, ty} => convPred {cls = cls, ty = H.substGen (tys, ty)}) ctx)
          | NONE => NONE


      (* the dictionaries of each record *)
      fun check (key, recs) =
        let
          val (kind, rest) = parse key
          val span = spanOfKey rest
        in
          if #file span = "" then ()
          else
            List.app
              (fn r =>
                 case (kind, r) of
                   ("use", V.Use {tys, dicts}) =>
                     (case M.find (!(#names src), rest) of
                        SOME q =>
                          (case wanted (span, q, tys) of
                             SOME ps =>
                               let val dicts = if not (null dicts) andalso faulty "dict tuple" then List.take (dicts, length dicts - 1)
                                               else dicts
                               in
                                 if length dicts = length ps then ListPair.app (fn (d, p) => proves (span, d, p)) (dicts, ps)
                                 else breach (span, "dict tuple", "`" ^ #name q ^ "` is used with " ^ Int.toString (length dicts) ^
                                                                  " dictionaries, and its context at its types has " ^
                                                                  Int.toString (length ps) ^ " predicates")
                               end
                           | NONE => ())
                      | NONE => ())
                 | (k, V.Overloaded {ty, dicts}) =>
                     let
                       val frac = getOpt (M.find (!(#lits src), rest), false)
                       val classes =
                         case k of
                           "lit" => [if frac then "Fractional" else "Num"]
                         | "neg" => ["Num"]
                         | "enum" => ["Enum"]
                         | "do" => ["Monad"]
                         | "patlit" => ["Eq", if frac then "Fractional" else "Num"]
                         | "npk" => ["Integral"]
                         | _ => []
                       val got = List.map (fn (c, _) => #name (idOfKey c)) dicts
                       fun member (x, xs) = List.exists (fn y => y = x) xs
                     in
                       if null classes orelse (List.all (fn c => member (c, classes)) got
                                               andalso List.all (fn c => member (c, got)) classes)
                       then List.app (fn (c, d) => proves (span, d, T.IsIn (idOfKey c, conv ty))) dicts
                       else breach (span, "dict tuple", "the " ^ k ^ " is given dictionaries of " ^
                                                        String.concatWith ", " got ^ ", and its translation names " ^
                                                        String.concatWith ", " classes)
                     end
                 | ("instance", V.Instance {inst, vars, supers, ...}) =>
                     let
                       val (cls, tc) = E.ofInstanceId inst
                       val kind = getOpt (E.tyconKind tc, T.Star)
                       val head = List.foldl (fn (v, f) => T.TAp (f, rigid v)) (T.TCon {id = tc, kind = kind}) vars
                       val supers = if length supers >= 2 andalso faulty "super" then List.rev supers else supers
                       val wantedSupers = C.supers cls
                       fun classOf d =
                         case d of
                           V.DInst {inst, ...} =>
                             (case CharVector.findi (fn (_, c) => c = #"@") inst of
                                SOME (i, _) => SOME (idOfKey (String.substring (inst, 0, i)))
                              | NONE => NONE)
                         | V.DSuper {super, ...} => SOME (idOfKey super)
                         | V.DParam n => (case paramOf n of SOME (_, SOME (T.IsIn (c, _))) => SOME c | _ => NONE)
                     in
                       if length supers <> length wantedSupers then
                         breach (span, "super", "the instance " ^ #name cls ^ " " ^ #name tc ^ " has " ^
                                                Int.toString (length supers) ^ " superclass dictionaries, and " ^ #name cls ^
                                                " has " ^ Int.toString (length wantedSupers) ^ " direct superclasses")
                       else
                         ListPair.app
                           (fn (d, s) =>
                              case classOf d of
                                SOME c => if T.idEq (c, s) then proves (span, d, T.IsIn (s, head))
                                          else breach (span, "super", "the instance " ^ #name cls ^ " " ^ #name tc ^
                                                                      " has a dictionary of " ^ #name c ^ " in the place of " ^
                                                                      #name s ^ "'s (a superclass path wrong)")
                              | NONE => proves (span, d, T.IsIn (s, head)))
                           (supers, wantedSupers)
                     end
                 | ("default", V.Defaulted {module_, ...}) =>
                     if cycleDefault then ()
                     else
                       let
                         val home = List.find (fn {ast = A.Module ({span = s, ...}, _), ...} : E.module => #file s = #file span)
                                      modules
                       in
                         case home of
                           SOME {id, library = false, ...} =>
                             let val module_ = if faulty "scc" then module_ ^ "Fault" else module_
                             in
                             if id = module_ orelse HsModules.moduleName id = module_ then ()
                             else breach (span, "scc", "a variable whose predicates arose in " ^ HsModules.moduleName id ^
                                                       " is defaulted by the default of " ^ module_ ^
                                                       ", and each module's default holds (D30)")
                             end
                         | _ => ()
                       end
                 | _ => ())
              recs
        end
      (* a binder's record: its type and its dictionary parameters *)
      fun bindRecord (decls, id) =
        case firstBinder (decls, id) of
          SOME s => (s, recordsAt ("bind", s))
        | NONE => (HsSource.noSpan, [])
      (* [bindg]: each group of each list of declarations, Rule 1 *)
      fun group (mid, decls) =
        let
          val signed = List.concat (List.map (fn A.D (_, A.DSig (vs, _, _)) => List.map nameOf vs | _ => []) decls)
          fun isSigned id = List.exists (fn s => T.idEq (s, id)) signed
        in
          List.app
            (fn g =>
               let
                 val restricted =
                   List.exists (fn HsLintInfer.Pat {simple = false, ...} => true
                                 | HsLintInfer.Pat {simple = true, vars, ...} => List.exists (not o isSigned) vars
                                 | HsLintInfer.Fun _ => false)
                     g
               in
                 if not restricted then ()
                 else
                   List.app
                     (fn id =>
                        let val (s, recs) = bindRecord (decls, id)
                        in
                          List.app
                            (fn V.Binding {params, scheme = {ctx, ...}} =>
                                  let val params = if faulty "bindg" then "dFault" :: params else params
                                  in
                                    if null params andalso null ctx then ()
                                    else breach (s, "bindg", "`" ^ HsLintInfer.plain id ^ "` is bound by a restricted group " ^
                                                             "and abstracted over dictionaries, " ^
                                                             String.concatWith ", " params ^
                                                             ": MonoRes (Faxen 2002, Definition 2, p 338, with 4.5.5's " ^
                                                             "simple pattern binding, R18) does not hold")
                                  end
                              | _ => ())
                            recs
                        end)
                     (List.concat (List.map HsLintInfer.bound g))
               end)
            (HsLintInfer.groupsOf (HsLintInfer.bindsOf decls))
        end
      (* [scc]: a group across the modules of a cycle shares one context *)
      fun sccGroups (g : E.module list) =
        if length g < 2 then ()
        else
          let
            val tops = List.concat (List.map (fn {ast = A.Module (_, {decls, ...}), ...} => decls) g)
          in
            List.app
              (fn grp =>
                 let
                   val ids = List.concat (List.map HsLintInfer.bound grp)
                   val homes = List.foldl (fn (id, acc) => if List.exists (fn h => h = #qual id) acc then acc else #qual id :: acc)
                                 [] ids
                 in
                   if length homes < 2 then ()
                   else
                     let
                       val ctxs = List.mapPartial (fn id => case #2 (bindRecord (tops, id)) of
                                                              V.Binding {scheme = {ctx, ...}, ...} :: _ =>
                                                                SOME (id, List.map (fn {cls, ...} => cls) ctx)
                                                            | _ => NONE)
                                    ids
                       fun sorted xs = T.sortStrings xs
                     in
                       case ctxs of
                         (_, first) :: rest =>
                           List.app (fn (id, c) => if sorted c = sorted first then ()
                                                   else breach (HsSource.noSpan, "scc",
                                                                "`" ^ HsLintInfer.plain id ^ "` of a group across the " ^
                                                                "modules of a cycle has a context of its own: the group " ^
                                                                "is one bindG, of one context"))
                             rest
                       | [] => ()
                     end
                 end)
              (HsLintInfer.groupsOf (HsLintInfer.bindsOf tops))
          end
      (* [method]: an instance's methods at their types there *)
      fun methods (span, cls : string, body) =
        let
          val recs = recordsAt ("instance", span)
        in
          case recs of
            V.Instance {inst, vars, ...} :: _ =>
              let
                val tc = #2 (E.ofInstanceId inst)
                val kind = getOpt (E.tyconKind tc, T.Star)
                val head = List.foldl (fn (v, f) => T.TAp (f, rigid v)) (T.TCon {id = tc, kind = kind}) vars
                val binds = HsLintInfer.bindsOf body
                val found =
                  List.mapPartial
                    (fn b =>
                       case HsLintInfer.bound b of
                         id :: _ =>
                           (case (M.find (!E.methods, T.idKey id), #2 (bindRecord (body, id))) of
                              (SOME m, r :: _) => SOME (id, m, r, #1 (bindRecord (body, id)))
                            | _ => NONE)
                       | [] => NONE)
                    binds
                val types = List.map (fn (_, _, r, _) => r) found
                fun text r = case r of
                               V.Binding {scheme = {ty, ...}, ...} => T.showTy (conv ty)
                             | V.Mono ty => T.showTy (conv ty)
                             | _ => ""
                (* the fault swaps two methods' records of different types *)
                val types = case types of
                              a :: b :: more => if text a <> text b andalso faulty "method" then b :: a :: more else types
                            | _ => types
              in
                ListPair.app
                  (fn ((id, {scheme = T.Forall (ks, (ps, t)), ...} : E.method, _, s), r) =>
                     let
                       val gens = Vector.fromList (head :: List.tabulate (length ks - 1, fn i => T.TGen (i + 1)))
                       val mine = T.inst gens t
                       val theirs = case r of
                                      V.Binding {scheme = {ty, ...}, ...} => SOME (conv ty)
                                    | V.Mono ty => SOME (conv ty)
                                    | _ => NONE
                     in
                       case theirs of
                         SOME th =>
                           if HsLintClaims.canonical (T.showTy th) = HsLintClaims.canonical (T.showTy mine) then ()
                           else breach (s, "method", "the method `" ^ HsLintInfer.plain id ^ "` of the instance " ^
                                                     cls ^
                                                     " " ^ #name tc ^ " is bound at " ^ T.showTy th ^ ", and its type there is " ^
                                                     T.showTy mine ^ " (a method's slot)")
                       | NONE => ()
                     end)
                  (found, types)
              end
          | _ => ()
        end
    in
      List.app check all;
      List.app group (List.rev (!(#decls src)));
      List.app sccGroups groups;
      List.app methods (List.rev (!(#instances src)));
      fault := ""
    end

  (* `claimsOf {modules, records, derived}`: the records as claims of the
     program's modules (HsLintClaims): each binding's type at the top
     level, and each default, its derived instances' methods' too, its
     predicates' classes the least that imply the rest, at no place; no
     kind or derived instance, which the records do not hold *)
  fun claimsOf {modules : E.module list, records : V.table, derived : (string * string * A.decl list) list}
               : HsLintClaims.claims =
    let
      val program = List.filter (fn {library, ...} => not library) modules
      fun text {vars, ctx, ty} =
        (case ctx of
           [] => ""
         | [p] => T.showPred (convPred p) ^ " => "
         | ps => "(" ^ String.concatWith ", " (List.map (T.showPred o convPred) ps) ^ ") => ")
        ^ T.showTy (conv ty)
      val bindings =
        List.concat
          (List.map
             (fn {id = mid, ast = A.Module (_, {decls, ...}), ...} =>
                let
                  val signed = List.concat (List.map (fn A.D (_, A.DSig (vs, _, _)) => List.map nameOf vs | _ => []) decls)
                in
                  List.mapPartial
                    (fn id =>
                       case firstBinder (decls, id) of
                         SOME s =>
                           (case V.find (records, V.node ("bind", s)) of
                              V.Binding {scheme, ...} :: _ =>
                                SOME {module = #qual id, name = #name id, scheme = text scheme,
                                      signed = List.exists (fn x => T.idEq (x, id)) signed}
                            | V.Mono ty :: _ =>
                                SOME {module = #qual id, name = #name id, scheme = T.showTy (conv ty),
                                      signed = List.exists (fn x => T.idEq (x, id)) signed}
                            | _ => NONE)
                       | NONE => NONE)
                    (List.concat (List.map HsLintInfer.bound (HsLintInfer.bindsOf decls)))
                end)
             program)
      (* the program's files, and those of its derived instances' methods *)
      val files =
        List.map (fn {ast = A.Module ({span, ...}, _), ...} : E.module => #file span) program
        @ List.concat (List.map (fn (mid, _, decls) =>
                                   if List.exists (fn {id, ...} : E.module => id = mid) program
                                   then List.map (fn A.D ({span, ...}, _) => #file span) decls
                                   else [])
                         derived)
      fun least classes =
        List.filter (fn c => not (List.exists (fn d => not (T.idEq (c, d))
                                                       andalso List.exists (fn e => T.idEq (e, c)) (C.closure d))
                                    classes))
          classes
      val defaults =
        List.concat
          (List.map
             (fn (key, recs) =>
                List.mapPartial
                  (fn V.Defaulted {preds, module_, choice, ...} =>
                        if String.isPrefix "default@" key
                           andalso List.exists (fn f => String.isPrefix ("default@" ^ f ^ ":") key) files then
                          let
                            val classes = List.foldl (fn ({cls, ...} : H.pred, acc) =>
                                                        let val c = idOfKey cls
                                                        in if List.exists (fn d => T.idEq (c, d)) acc then acc else acc @ [c] end)
                                            [] preds
                          in
                            SOME {module = module_, place = "",
                                  preds = String.concatWith ", " (T.sortStrings (List.map (fn c => #name c ^ " a") (least classes))),
                                  choice = T.showTy (conv choice)}
                          end
                        else NONE
                    | _ => NONE)
                  recs)
             (V.all records))
    in
      {kinds = [], derived = [], bindings = bindings, defaults = defaults, whole = false}
    end
end
