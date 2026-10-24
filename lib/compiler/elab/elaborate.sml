(* Elaboration: type inference for the Core language with namespace-only
   structures. Fills the annotation slots in the AST for the translator. *)
structure Elaborate =
struct
  open Ast Types Env

  val stampCounter = ref 0
  val () = CompilerState.cellRoot ("Elaborate.stampCounter", stampCounter)
  fun freshStamp () = let val s = !stampCounter in stampCounter := s + 1; s end

  val allowPrim = ref false
  val () = CompilerState.cellRoot ("Elaborate.allowPrim", allowPrim)

  (* Signatures and functors are components of the basis, not of
     environments (Section 5.1); both are declared at top level only. *)
  val sigs : SigMatch.sigma StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Elaborate.sigs", sigs)

  (* A functor's signature (Section 5.1, (T)(E, (T')E')): its parameter's,
     and the summary of its body that its declaration's check left -- the
     environment E' the body gave against the parameter, the type names T'
     the body made that E' names, and what the check used of the counters
     of stamps, type names and type variables. The values and exceptions
     of E' are named by placeholders (placeholder), which name nothing of
     a unit. Every application is typed by it (rule 54): one inside a
     functor's declaration, or in a compile that makes no code (makesCode),
     by the summary alone, one whose code is made by the summary realised
     with the names of a copy of the body elaborated for its code
     (signatureTyped). A type variable the body leaves free refuses the
     declaration (rule 89); one of the basis's that a later declaration of
     the topdec may determine the summary shares. NONE where E' keeps a
     flexible record, which the end of the topdec refuses: every
     application elaborates a copy then, and is typed by it. *)
  type summary = {generated : tycon list, result : env, counts : int * int * int}

  datatype funinfo =
      FunInfo of {param : string option, paramSig : SigMatch.sigma, body : strexp, defEnv : env, allowPrim : bool,
                  defSigs : SigMatch.sigma StringMap.map, defFuns : funinfo StringMap.map,
                  summary : summary option,
                  origin : string,binding:Env.origin,   (* the identity of the unit it was loaded from; "" where elaborated *)
                  code : int option}   (* --functors=functions: the global of its function *)
  val funs : funinfo StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Elaborate.funs", funs)

  (* --functors=functions (docs/plans/functors-units.md, M5; a prototype):
     a functor's body elaborated once, at its declaration, and compiled
     there to a function of its argument's record to its result's
     (FunCode); every application typed by the summary alone (rule 54) and
     compiled to a call. Off, a functor is compiled by static
     interpretation, a copy of its body for each application. *)
  val functorFunctions = ref false
  val () = CompilerState.cellRoot ("Elaborate.functorFunctions", functorFunctions)

  (* Whether what is elaborated is only checked: a functor's body at its
     declaration, or a copy of a body applied there; a functor application
     makes code where it is not *)
  val checking = ref 0
  val () = CompilerState.cellRoot ("Elaborate.checking", checking)

  (* Whether code is made of what is elaborated: not under --typecheck-only
     and --serve, nor in the analyses of the compiler library, which only
     check (docs/plans/functors-units.md, D15). Where it is not, every
     application is typed by the functor's summary alone, as one inside a
     functor's declaration is, and no copy of the body is elaborated *)
  val makesCode = ref true
  val () = CompilerState.cellRoot ("Elaborate.makesCode", makesCode)

  (* --lint: each application whose code is made checks that its copy
     agrees with the functor's summary but for the names the copy made *)
  val lintSummaries = ref false
  val () = CompilerState.cellRoot ("Elaborate.lintSummaries", lintSummaries)

  (* Dynamic modules (docs/units.md, Dynamic modules; the incremental
     roadmap's M9, D17 and D18): the fingerprint of a signature's ABI, which
     UnitBasis gives (the hash of UnitBasis.fpSigma); and, while the body
     of an _export is elaborated, the order the signature gives the
     constructors of each datatype it specifies, by the datatype's name,
     which a datatype of the body of that name and those constructors takes
     its tags in *)
  val sigFingerprint : (SigMatch.sigma -> string) ref = ref (fn _ => "")
  val () = CompilerState.cellRoot ("Elaborate.sigFingerprint", sigFingerprint)
  val exportTags : string list StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Elaborate.exportTags", exportTags)
  (* where the program loads a dynamic module, which only a program built in
     units can (Main): the first such declaration *)
  val dynamicAt : Source.span option ref = ref NONE
  val () = CompilerState.cellRoot ("Elaborate.dynamicAt", dynamicAt)

  (* The signatures and functors declared since UnitBasis.begin, newest
     first: what a unit's basis holds of them (lib/compiler/driver/unitbasis.sml) *)
  val insertedSigs : string list ref = ref []
  val () = CompilerState.cellRoot ("Elaborate.insertedSigs", insertedSigs)
  val insertedFuns : string list ref = ref []
  val () = CompilerState.cellRoot ("Elaborate.insertedFuns", insertedFuns)

  (* The constructors of every datatype declared so far, with their schemes,
     by the stamp of its type name, in or out of scope: what the REPL's
     printers match a value of the datatype with (src/repl/show.sml). *)
  val dataCons : (string * valstatus) list IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Elaborate.dataCons", dataCons)

  (* overloaded operator variables and flexible records awaiting resolution *)
  val pendingOverloads : tvar ref list ref = ref []
  val () = CompilerState.cellRoot ("Elaborate.pendingOverloads", pendingOverloads)
  val pendingFlex : (tvar ref * span) list ref = ref []
  val () = CompilerState.cellRoot ("Elaborate.pendingFlex", pendingFlex)
  (* the declarations of the topdec so far, whose free variables are checked
     where it ends (rules 87 to 89; elabTop) *)
  val pendingClosed : (env * span) list ref = ref []
  val () = CompilerState.cellRoot ("Elaborate.pendingClosed", pendingClosed)

  (* How large the context is that must determine a flexible record's
     labels (Section 4.11 leaves it open; docs/language.md, --flex-records):
     the binding that would generalise it (SML/NJ, Hamlet), the declaration
     at structure level it is in (MLKit), the top-level declaration -- to a
     `;` or the end of the file -- with no flexible record generalised
     (Moscow ML) or with one generalised and determined at each use
     (Poly/ML and MLton, the default), or the whole program (the unit, with
     --units) *)
  datatype flexMode = FlexBinding | FlexDeclaration | FlexTopdecMono | FlexTopdec | FlexProgram
  val flexRecords = ref FlexTopdec
  val () = CompilerState.cellRoot ("Elaborate.flexRecords", flexRecords)
  fun flexModeName m =
    case m of
      FlexBinding => "binding" | FlexDeclaration => "declaration" | FlexTopdecMono => "topdec-monomorphic"
    | FlexTopdec => "topdec" | FlexProgram => "program"
  fun flexModeOf name =
    List.find (fn m => flexModeName m = name) [FlexBinding, FlexDeclaration, FlexTopdecMono, FlexTopdec, FlexProgram]

  (* Exhaustiveness and redundancy reports are deferred to the end of the
     top-level declaration, when flexible record patterns have their types.
     They are switched off while a functor body is re-elaborated for an
     application, since the body was reported on when the functor was declared. *)
  val pendingChecks : (unit -> unit) list ref = ref []
  val () = CompilerState.cellRoot ("Elaborate.pendingChecks", pendingChecks)
  val reportMatches = ref true
  val () = CompilerState.cellRoot ("Elaborate.reportMatches", reportMatches)
  fun deferCheck (f : unit -> unit) = if !reportMatches then pendingChecks := f :: !pendingChecks else ()

  fun err (sp, msg) = Error.error (sp, msg)

  fun unifyAt (sp, t1, t2, context) =
    Unify.unify (t1, t2)
    handle Unify.Unify reason =>
      let
        val printer = newPrinter ()
        val s1 = toStringWith printer t1
        val s2 = toStringWith printer t2
      in
        err (sp, context ^ ": type mismatch between " ^ s1 ^ " and " ^ s2 ^ " (" ^ reason ^ ")")
      end

  (* int and word constants awaiting the resolution of their type, for the
     check that the type can represent them *)
  val pendingLiterals : (scon * ty * Source.span) list ref = ref []
  val () = CompilerState.cellRoot ("Elaborate.pendingLiterals", pendingLiterals)

  fun power2 (n : int) : IntInf.int = IntInf.pow (IntInf.fromInt 2, n)

  (* Reuse immutable limits for common literal widths, not acceptance
     decisions. The bounded cache cannot grow with user-defined widths. *)
  local
    val one = IntInf.fromInt 1
    val zero = IntInf.fromInt 0
    val known : (IntInf.int * IntInf.int) option array = Array.array (130, NONE)
    val () = CompilerState.arrayRoot ("Elaborate.known", known)
  in
    fun literalBounds (signed, n) =
      let
        fun calculate () =
          if signed then
            let val half = power2 (n - 1)
            in (IntInf.~ half, IntInf.- (half, one)) end
          else (zero, IntInf.- (power2 n, one))
      in
        if n < 0 orelse n >= 65 then calculate ()
        else let val index = n + n + (if signed then 0 else 1)
             in case Array.sub (known, index) of
                  SOME limits => limits
                | NONE => let val limits = calculate ()
                          in Array.update (known, index, SOME limits); limits end
             end
      end
  end

  fun checkLiteral (sc, t, sp) =
    let
      fun check (what, v, lo, hi) =
        if IntInf.< (v, lo) orelse IntInf.> (v, hi)
        then err (sp, what ^ " constant " ^ Ast.sconToString sc ^ " is out of range for the type " ^ toString t)
        else ()
      fun bounded (what, v, signed, n) =
        let val (lo, hi) = literalBounds (signed, n)
        in check (what, v, lo, hi) end
      (* a raw character above 127 read under --unicode, which means its
         code point (D6): an error at an 8-bit type, whose constant says
         by an escape whether it means the character or its bytes *)
      fun raw (what, c) =
        let
          fun ddd b = "\\" ^ StringCvt.padLeft #"0" 3 (Int.toString b)
          val utf8 = String.concat (List.map (ddd o Char.ord) (String.explode (Utf8.encode c)))
        in
          err (sp, "raw character " ^ Lexer.codePoint c ^ " in a " ^ what ^ " constant of type " ^ toString t ^ ": "
                   ^ (if c <= 255 then "write " ^ ddd c ^ " for the character"
                                       ^ (if what = "string" then ", or " ^ utf8 ^ " for its UTF-8" else "")
                      else if what = "string" then "write " ^ utf8 ^ " for its UTF-8, or give the constant a wide type"
                      else "give the constant a wide type"))
        end
    in
      case prune t of
        TCon (c, _) =>
          (case (sc, Overload.literalOf c) of
             (SInt v, SOME (Overload.Bits n)) =>
               bounded ("integer", v, true, n)
           | (SWord v, SOME (Overload.Bits n)) =>
               bounded ("word", v, false, n)
           | (SChar (_, SOME r), SOME (Overload.Bits _)) => raw ("character", r)
           | (SChar (v, NONE), SOME (Overload.Bits n)) =>
               bounded ("character", IntInf.fromInt v, false, n)
           | (SWideString (_, SOME r), SOME (Overload.Bits _)) => raw ("string", r)
           | (SWideString (cs, NONE), SOME (Overload.Bits n)) =>
               (case cs of [] => ()
                | _ => let val (lo, hi) = literalBounds (false, n)
                       in List.app (fn v => check ("string", IntInf.fromInt v, lo, hi)) cs end)
           | _ => ())
      | _ => ()
    end

  fun registerOverloads t =
    case prune t of
      TVar r => (case !r of Unbound {kind = KOverload _, ...} => pendingOverloads := r :: !pendingOverloads | _ => ())
    | TCon (_, args) => List.app registerOverloads args
    | TRecord fields => List.app (fn (_, a) => registerOverloads a) fields
    | TArrow (a, b) => (registerOverloads a; registerOverloads b)

  (* The types that an int or a word constant, or an operator of the
     classes Int and Word, defaults to when its declaration leaves it open:
     int and word (Appendix E), or Int64.int and Word64.word in the
     program's own files under --default-type (main.sml). *)
  val intDefault = ref intTy
  val () = CompilerState.cellRoot ("Elaborate.intDefault", intDefault)
  val wordDefault = ref wordTy
  val () = CompilerState.cellRoot ("Elaborate.wordDefault", wordDefault)

  fun resolvePending () =
    (List.app (fn r =>
                 case !r of
                   Unbound {kind = KOverload names, ...} =>
                     let
                       val default =
                         if List.exists (fn n => n = "int") names then !intDefault
                         else if List.exists (fn n => n = "real") names then realTy
                         else if List.exists (fn n => n = "word") names then !wordDefault
                         else if List.exists (fn n => n = "char") names then charTy
                         else if List.exists (fn n => n = "string") names then stringTy
                         else Error.bug "resolvePending: empty overload class"
                     in Unify.unify (TVar r, default) end
                 | _ => ()) (!pendingOverloads);
     pendingOverloads := [];
     List.app checkLiteral (List.rev (!pendingLiterals));
     pendingLiterals := [])

  (* Section 4.11: the program context must determine every flexible record.
     Checked once the whole program is elaborated, together with the deferred
     match reports (which need the records' labels); with --units, at the
     end of each unit, which is then settled before the next is compiled
     (docs/units.md). *)
  (* every flexible record so far determined, or an error at the first that
     is not: where the context --flex-records names ends *)
  fun settleFlex () =
    (List.app (fn (r, sp) =>
                 case !r of
                   Unbound {kind = KFlex _, ...} =>
                     err (sp, "unresolved flexible record: cannot determine the full set of fields")
                 | _ => ()) (List.rev (!pendingFlex));
     pendingFlex := [])

  fun finish () =
    let
      val () = ElabStats.reset ()
      val () = settleFlex ()
      val () = List.app (fn f => f ()) (List.rev (!pendingChecks))
      val () = pendingChecks := []
    in
      (* --pass-stats=elab: the checks deferred to here, a line of their own *)
      if !ElabStats.on then ElabStats.emit ("-", "deferred", "", 0) else ()
    end

  (* A binding's type generalised (rule 15's Clos): under
     --flex-records=binding a flexible record it would generalise is an
     error there; under topdec-monomorphic it is not generalised, nor are
     the variables of its fields, and the uses after it determine it *)
  fun flexAbove (level : int, t : ty) : bool =
    case prune t of
      TVar (ref (Unbound {kind = KFlex _, level = l, ...})) => l > level andalso l <> genericLevel
    | TVar _ => false
    | TCon (_, args) => List.exists (fn a => flexAbove (level, a)) args
    | TRecord fields => List.exists (fn (_, a) => flexAbove (level, a)) fields
    | TArrow (a, b) => flexAbove (level, a) orelse flexAbove (level, b)
  fun lowerFlex (level : int, t : ty) : unit =
    case prune t of
      t' as TVar (ref (Unbound {kind = KFlex _, level = l, ...})) =>
        if l > level andalso l <> genericLevel then Unify.lowerLevels (level, t') else ()
    | TVar _ => ()
    | TCon (_, args) => List.app (fn a => lowerFlex (level, a)) args
    | TRecord fields => List.app (fn (_, a) => lowerFlex (level, a)) fields
    | TArrow (a, b) => (lowerFlex (level, a); lowerFlex (level, b))
  fun generalizeBinding (level : int, t : ty, sp : span) : unit =
    case !flexRecords of
      FlexBinding =>
        (if flexAbove (level, t) then err (sp, "unresolved flexible record: cannot determine the full set of fields")
         else ();
         Unify.generalize (level, t))
    | FlexTopdecMono => (lowerFlex (level, t); Unify.generalize (level, t))
    | _ => Unify.generalize (level, t)

  (* Section 2.9 and 3.5: identifiers that no binding or description may (re)bind. *)
  val reservedVids = ["true", "false", "nil", "::", "ref"]
  fun checkBindable (name, sp, allowIt : bool) =
    if List.exists (fn r => r = name) reservedVids orelse (not allowIt andalso name = "it") then
      err (sp, "'" ^ name ^ "' cannot be rebound")
    else ()

  fun checkDupLabels (fields : (string * 'a) list, sp) =
    let
      fun go [] = ()
        | go ((l, _) :: rest) =
          if List.exists (fn (l2, _) => l2 = l) rest then err (sp, "duplicate record label '" ^ l ^ "'") else go rest
    in go fields end

  (* The type of a special constant. An int, word or real constant is
     overloaded over the types of its kind (Appendix E: the classes Int, Word
     and Real) and defaults to int, word or real; its type is left in the slot
     for Translate. *)
  fun sconTy (level, sc, slot : ty option ref, sp) =
    let
      fun overloaded kind =
        let val t = freshTvar (level, KOverload [kind], false)
        in
          registerOverloads t;
          pendingLiterals := (sc, t, sp) :: !pendingLiterals;
          slot := SOME t;
          t
        end
    in
      case sc of
        SInt _ => overloaded "int"
      | SWord _ => overloaded "word"
      | SReal _ => overloaded "real"
      | SString _ => overloaded "string"
      | SWideString _ => overloaded "string"
      | SChar _ => overloaded "char"
    end

  type scope = ty StringMap.map ref

  (* --- explicit type variables (Section 4.6) --- *)
  fun addTyvar (v, acc) = if List.exists (fn w => w = v) acc then acc else v :: acc

  fun tyvarsOfTy (t : Ast.ty, acc : string list) : string list =
    case t of
      TyVar (v, _) => addTyvar (v, acc)
    | TyRecord (fields, _) => List.foldl (fn ((_, t), acc) => tyvarsOfTy (t, acc)) acc fields
    | TyTuple (ts, _) => List.foldl tyvarsOfTy acc ts
    | TyCon (args, _, _) => List.foldl tyvarsOfTy acc args
    | TyArrow (a, b, _) => tyvarsOfTy (b, tyvarsOfTy (a, acc))

  fun minusTyvars (vs, bound) = List.filter (fn v => not (List.exists (fn w => w = v) bound)) vs

  (* The type variables occurring unguarded in a value declaration: those
     in it that are not inside a smaller value declaration. Variables bound
     by the tyvarseq of a type or datatype binding do not count. *)
  fun unguardedExp (e : exp, acc) : string list =
    case e of
      EScon _ => acc
    | EVar _ => acc
    | ERecord (fields, _) => List.foldl (fn ((_, e), acc) => unguardedExp (e, acc)) acc fields
    | ETuple (es, _) => List.foldl unguardedExp acc es
    | ESelect _ => acc
    | EList (es, _, _) => List.foldl unguardedExp acc es
    | ESeq (es, _) => List.foldl unguardedExp acc es
    | ELet (decs, e, _) => unguardedExp (e, List.foldl unguardedDec acc decs)
    | EApp (f, a, _) => unguardedExp (a, unguardedExp (f, acc))
    | ETyped (e, t, _) => tyvarsOfTy (t, unguardedExp (e, acc))
    | EAndalso (a, b, _) => unguardedExp (b, unguardedExp (a, acc))
    | EOrelse (a, b, _) => unguardedExp (b, unguardedExp (a, acc))
    | EHandle (e, rules, _) => unguardedRules (rules, unguardedExp (e, acc))
    | ERaise (e, _) => unguardedExp (e, acc)
    | EIf (a, b, c, _) => unguardedExp (c, unguardedExp (b, unguardedExp (a, acc)))
    | EWhile (a, b, _) => unguardedExp (b, unguardedExp (a, acc))
    | ECase (e, rules, _) => unguardedRules (rules, unguardedExp (e, acc))
    | EFn (rules, _, _) => unguardedRules (rules, acc)
    | EPrim (_, t, _, _) => tyvarsOfTy (t, acc)

  and unguardedRules (rules : mrule list, acc) =
    List.foldl (fn ((p, e), acc) => unguardedExp (e, unguardedPat (p, acc))) acc rules

  and unguardedPat (p : pat, acc) : string list =
    case p of
      PRecord (fields, _, _, _) => List.foldl (fn ((_, p), acc) => unguardedPat (p, acc)) acc fields
    | PTuple (ps, _) => List.foldl unguardedPat acc ps
    | PList (ps, _) => List.foldl unguardedPat acc ps
    | PApp (_, _, p, _) => unguardedPat (p, acc)
    | PTyped (p, t, _) => tyvarsOfTy (t, unguardedPat (p, acc))
    | PLayered (_, tyopt, p, _, _) =>
        unguardedPat (p, case tyopt of SOME t => tyvarsOfTy (t, acc) | NONE => acc)
    | POr (ps, _) => List.foldl unguardedPat acc ps
    | _ => acc

  (* declarations nested in an expression *)
  and unguardedDec (d : dec, acc) : string list =
    case d of
      DVal _ => acc                          (* a smaller value declaration guards its variables *)
    | DValRec _ => acc
    | DFun _ => acc
    | DType (tbs, _) =>
        List.foldl (fn (tb : typbind, acc) => minusTyvars (tyvarsOfTy (#ty tb, []), #tyvars tb) @ acc) acc tbs
    | DDatatype (dbs, tbs, _) =>
        List.foldl (fn (db : datbind, acc) =>
                       minusTyvars (List.foldl (fn ((_, SOME t, _), a) => tyvarsOfTy (t, a) | ((_, NONE, _), a) => a) [] (#cons db),
                                    #tyvars db) @ acc)
                   (unguardedDec (DType (tbs, Source.noSpan), acc)) dbs
    | DException (ebs, _) =>
        List.foldl (fn (ExnDecl (_, SOME t, _, _), acc) => tyvarsOfTy (t, acc) | (_, acc) => acc) acc ebs
    | DLocal (d1, d2, _) => List.foldl unguardedDec (List.foldl unguardedDec acc d1) d2
    | DAbstype (dbs, tbs, decs, _) =>
        List.foldl unguardedDec (unguardedDec (DDatatype (dbs, tbs, Source.noSpan), acc)) decs
    | _ => acc

  (* the unguarded variables of a value declaration itself *)
  fun unguardedValDec (d : dec) : string list =
    case d of
      DVal (_, binds, _) => List.foldl (fn ((p, e), acc) => unguardedExp (e, unguardedPat (p, acc))) [] binds
    | DValRec (_, binds, _) => List.foldl (fn ((p, e), acc) => unguardedExp (e, unguardedPat (p, acc))) [] binds
    | DFun (_, fs, _) =>
        List.foldl (fn (f : fundef, acc) =>
                       List.foldl (fn ({pats, resty, body}, acc) =>
                                      unguardedExp (body, List.foldl unguardedPat
                                                                    (case resty of SOME t => tyvarsOfTy (t, acc) | NONE => acc)
                                                                    pats))
                                  acc (#clauses f)) [] fs
    | _ => []

  (* Rule 15: the scope of a value declaration binds its explicit type
     variables and those implicitly scoped at it, as rigid variables. *)
  fun valScope (outer : scope, explicit : string list, d : dec, level, sp) : scope * string list =
    let
      val () = List.app (fn v =>
                            if StringMap.member (!outer, v) then err (sp, "explicit type variable " ^ v ^ " is already in scope")
                            else ()) explicit
      val implicit = List.filter (fn v => not (StringMap.member (!outer, v)) andalso not (List.exists (fn w => w = v) explicit))
                                 (List.rev (unguardedValDec d))
      val scoped = explicit @ implicit
      val m = List.foldl (fn (v, m) => StringMap.insert (m, v, freshTvar (level, KRigid v, String.isPrefix "''" v))) (!outer) scoped
    in (ref m, scoped) end

  (* Rule 15's side condition: the scoped variables must have been generalised.
     A variable that was unified with a type of the enclosing context has
     been lowered to the context's level; an unused one still sits at the
     declaration's own level, which is fine. *)
  fun checkGeneralised (scope : scope, scoped : string list, level, sp) =
    List.app (fn v =>
                 case StringMap.find (!scope, v) of
                   SOME t =>
                     (case prune t of
                        TVar (ref (Unbound {level = l, ...})) =>
                          if l > level then ()
                          else err (sp, "explicit type variable " ^ v ^ " cannot be generalised")
                      | _ => err (sp, "explicit type variable " ^ v ^ " cannot be generalised"))
                 | NONE => ()) scoped

  (* A scope for the type variables of a type expression in a specification,
     which are implicitly quantified (rule 79). *)
  fun specScope (t : Ast.ty, level) : scope =
    ref (List.foldl (fn (v, m) => StringMap.insert (m, v, freshTvar (level, KPlain, String.isPrefix "''" v)))
                    StringMap.empty (tyvarsOfTy (t, [])))

  (* ------------------------------------------------------------------ *)
  (* Functors' summaries (rule 54)                                        *)

  (* the types an environment holds, each given to f *)
  fun appEnvTypes (f : ty -> unit) (Env {vals, tys, strs,...}) : unit =
    let
      fun value v =
        case v of
          Val {scheme, ...} => f scheme | Con {scheme, ...} => f scheme | Prim {scheme, ...} => f scheme
        | ConAsVal {scheme, ...} => f scheme | Exn {ty = t, ...} => f t | ExnAsVal {ty = t, ...} => f t
      fun tystr (TyStr {fcn, cons}) =
        ((case fcn of TName c => f (TCon (c, [])) | TAbbrev (_, t) => f t); List.app (fn (_, v) => value v) cons)
    in
      StringMap.app value vals; StringMap.app tystr tys; StringMap.app (appEnvTypes f) strs
    end

  (* A type variable that unification may still bind: one not generalised,
     and not a flexible record's *)
  fun isFree (r : tvar ref) : bool =
    case !r of
      Unbound {kind = KFlex _, ...} => false
    | Unbound {level, ...} => level <> genericLevel
    | _ => false

  (* The type variables the declarations of the topdec so far leave free,
     which a declaration after them may still determine (rules 87 to 89):
     the basis a functor's body is checked in shares them with it, and with
     every application, so they are no body's own *)
  fun basisTyvars () : tvar ref list =
    let
      val found : tvar ref list ref = ref []
      fun ty t =
        case prune t of
          TVar r => if isFree r andalso not (List.exists (fn r' => r' = r) (!found)) then found := r :: !found else ()
        | TCon (_, args) => List.app ty args
        | TRecord fields => List.app (fn (_, a) => ty a) fields
        | TArrow (a, b) => (ty a; ty b)
    in List.app (fn (e, _) => appEnvTypes ty e) (!pendingClosed); !found end

  (* Whether a summary may stand for every application: no type variable of
     it that unification may still bind -- one not generalised, or a
     flexible record -- which each copy would have of its own; but those of
     the basis (shared), which every copy shares *)
  fun closedEnv (e : env, shared : tvar ref list) : bool =
    let
      exception Open
      fun ty t =
        case prune t of
          TVar (ref (Unbound {kind = KFlex _, ...})) => raise Open
        | TVar r => if isFree r andalso not (List.exists (fn r' => r' = r) shared) then raise Open else ()
        | TCon (_, args) => List.app ty args
        | TRecord fields => List.app (fn (_, a) => ty a) fields
        | TArrow (a, b) => (ty a; ty b)
    in (appEnvTypes ty e; true) handle Open => false end

  (* The first value of a functor's result, by its long name, whose type
     keeps a type variable that the body left free and the basis does not
     share (rule 89, which the end of no top-level declaration can meet:
     nothing after the body reaches the variable) *)
  fun bodyTyvar (e : env, shared : tvar ref list) : (string * ty) option =
    let
      exception Found of string * ty
      fun free t =
        case prune t of
          TVar r => isFree r andalso not (List.exists (fn r' => r' = r) shared)
        | TCon (_, args) => List.exists free args
        | TRecord fields => List.exists (fn (_, a) => free a) fields
        | TArrow (a, b) => free a orelse free b
      fun walk (prefix, Env {vals, strs, ...}) =
        (StringMap.appi (fn (n, Val {scheme, ...}) => if free scheme then raise Found (prefix ^ n, scheme) else ()
                          | _ => ()) vals;
         StringMap.appi (fn (n, s) => walk (prefix ^ n ^ ".", s)) strs)
    in (walk ("", e); NONE) handle Found f => SOME f end

  (* The type names made from lo on that an environment names, by stamp *)
  fun generatedIn (lo : int, e : env) : tycon list =
    let
      val seen : tycon IntMap.map ref = ref IntMap.empty
      fun ty t =
        case prune t of
          TVar _ => ()
        | TCon (c, args) => ((if #stamp c >= lo then seen := IntMap.insert (!seen, #stamp c, c) else ()); List.app ty args)
        | TRecord fields => List.app (fn (_, a) => ty a) fields
        | TArrow (a, b) => (ty a; ty b)
    in appEnvTypes ty e; IntMap.listItems (!seen) end

  (* The values and exceptions of an environment renamed by f, a stamp to
     a stamp, each once *)
  fun restamp (f : int -> int) (Env {vals, tys, strs,origins}) : env =
    let
      fun exn (info : exninfo) : exninfo =
        {name = #name info, stamp = f (#stamp info), isGlobal = #isGlobal info, hasArg = #hasArg info,
         builtin = #builtin info}
      fun value v =
        case v of
          Val {scheme, stamp, global} => Val {scheme = scheme, stamp = f stamp, global = global}
        | Exn {ty, info} => if isSome (#builtin info) then v else Exn {ty = ty, info = exn info}
        | ExnAsVal {ty, info} => if isSome (#builtin info) then v else ExnAsVal {ty = ty, info = exn info}
        | other => other
    in Env {vals = StringMap.map value vals, tys = tys, strs = StringMap.map (restamp f) strs,origins=origins} end

  (* The placeholders a summary names its values and exceptions by: one
     for each, in the order of the environment, under every stamp a unit
     can have, so that writing a summary into a unit's basis adds no name
     of the unit's own (lib/compiler/driver/unitbasis.sml) *)
  val placeholderBase = ~1000000
  fun placeholders (e : env) : env =
    let
      val given : int IntMap.map ref = ref IntMap.empty
      val next = ref placeholderBase
      fun f s =
        case IntMap.find (!given, s) of
          SOME p => p
        | NONE => let val p = !next in next := p - 1; given := IntMap.insert (!given, s, p); p end
    in restamp f e end

  (* What an application typed from a summary gives in place of the
     placeholders: a fresh stamp for each exception, which each
     application makes anew (rule 154), and the placeholders of values as
     they are, which name nothing that is translated *)
  fun freshExceptions (e : env) : env =
    let
      val given : int IntMap.map ref = ref IntMap.empty
      val exns : unit IntMap.map ref = ref IntMap.empty
      fun note (Env {vals, strs, ...}) =
        (StringMap.app (fn Exn {info, ...} => exns := IntMap.insert (!exns, #stamp info, ())
                         | ExnAsVal {info, ...} => exns := IntMap.insert (!exns, #stamp info, ())
                         | _ => ()) vals;
         StringMap.app note strs)
      val () = note e
      fun f s =
        if not (IntMap.member (!exns, s)) then s
        else
          case IntMap.find (!given, s) of
            SOME p => p
          | NONE => let val p = freshStamp () in given := IntMap.insert (!given, s, p); p end
    in restamp f e end

  (* the counters of stamps, type names and type variables *)
  fun counters () = (!stampCounter, !tyconCounter, !tvarCounter)

  (* Where an application is typed from a summary, the counters moved on to
     where the copy it stands for would have left them: a declaration's
     check uses what a copy of the same body uses, so that every name made
     after it is the one it was before summaries *)
  fun replay ((s0, c0, v0) : int * int * int, (ds, dc, dv) : int * int * int) : unit =
    (stampCounter := Int.max (!stampCounter, s0 + ds);
     tyconCounter := Int.max (!tyconCounter, c0 + dc);
     tvarCounter := Int.max (!tvarCounter, v0 + dv))

  (* An application whose code is made, typed by the functor's signature
     (Section 5.4, rule 54): the summary realised -- the parameter's names
     by the argument's types (phi), the names the body made by those the
     copy made in their place, with the equality the summary gives them --
     with the copy's stamps and constructors, which are its code's. The
     copy, elaborated with the actual argument, can find that a datatype of
     the body admits equality where the body checked against the parameter
     did not, or a value more polymorphic where a type of the argument
     drops a parameter (`type 'a t = u`). The summary and the copy agree
     but for the names each made and their type variables; NONE where they
     do not, which lintSummaries makes an error. *)
  fun signatureTyped ({generated, result, ...} : summary, phi : realisation, copy : env, where_ : string) : env option =
    let
      exception Disagree
      val made = List.foldl (fn (c, m) => IntMap.insert (m, #stamp c, c)) IntMap.empty generated
      (* each name the body made, by the copy's in its place, with the
         equality the summary gives it; and the copy's names that admit
         equality where the summary's do not *)
      val psi : realisation ref = ref IntMap.empty
      val fix : realisation ref = ref IntMap.empty
      fun pair (c : tycon, c' : tycon) =
        case IntMap.find (made, #stamp c) of
          SOME d =>
            (case IntMap.find (!psi, #stamp c) of
               SOME (TName e) => if #stamp e = #stamp c' then () else raise Disagree
             | SOME _ => raise Disagree
             | NONE =>
                 (psi := IntMap.insert (!psi, #stamp c, TName (withEq (c', #eq d)));
                  if not (#eq d) andalso #eq c' then fix := IntMap.insert (!fix, #stamp c', TName (withEq (c', false)))
                  else ()))
        | NONE => if #stamp c = #stamp c' then () else raise Disagree
      (* whether the copy's every type is the summary's but for its type
         variables' names (renamed one to one, a scheme at a time): then
         the copy with the summary's equality is the summary realised *)
      val same = ref true
      (* the summary's type (a), realised by phi as it is walked, and the
         copy's (b), and the variables of the scheme paired so far *)
      fun ty (a, b, vs : (tvar ref * tvar ref) list ref) =
        case (prune a, prune b) of
          (TCon (c, xs), b') =>
            (case IntMap.find (phi, #stamp c) of
               SOME f => ty (applyFcn (f, xs), b', vs)
             | NONE =>
                 (case b' of
                    TCon (c', ys) => (pair (c, c'); tys (xs, ys, vs))
                  | TVar (ref (Unbound {kind = KOverload _, ...})) => ()
                  | TVar _ => same := false
                  | _ => raise Disagree))
        | (TVar r, TVar r') =>
            (case (List.find (fn (x, _) => x = r) (!vs), List.find (fn (_, y) => y = r') (!vs)) of
               (SOME (_, y), _) => if y = r' then () else same := false
             | (NONE, SOME _) => same := false
             | (NONE, NONE) => vs := (r, r') :: !vs)
        | (TVar _, _) => raise Disagree
        (* an overloaded constant or operator of the copy's, which the end
           of the declaration settles as the declaration's check settled it *)
        | (_, TVar (ref (Unbound {kind = KOverload _, ...}))) => ()
        | (_, TVar _) => same := false
        | (TRecord fs, TRecord gs) =>
            if List.length fs <> List.length gs then raise Disagree
            else ListPair.app (fn ((l, x), (l', y)) => if l = l' then ty (x, y, vs) else raise Disagree) (fs, gs)
        | (TArrow (x1, y1), TArrow (x2, y2)) => (ty (x1, x2, vs); ty (y1, y2, vs))
        | _ => raise Disagree
      and tys (xs, ys, vs) = if List.length xs <> List.length ys then raise Disagree else ListPair.app (fn (x, y) => ty (x, y, vs)) (xs, ys)
      fun scheme (a, b) = ty (a, b, ref [])
      fun value (v, v') =
        case (v, v') of
          (Val {scheme = s, ...}, Val {scheme = s', ...}) => scheme (s, s')
        | (Con {scheme = s, ...}, Con {scheme = s', ...}) => scheme (s, s')
        | (Exn {ty = t, ...}, Exn {ty = t', ...}) => scheme (t, t')
        | (Prim {scheme = s, ...}, Prim {scheme = s', ...}) => scheme (s, s')
        | (ConAsVal {scheme = s, ...}, ConAsVal {scheme = s', ...}) => scheme (s, s')
        | (ExnAsVal {ty = t, ...}, ExnAsVal {ty = t', ...}) => scheme (t, t')
        | _ => raise Disagree
      fun fcn (f, f') =
        case (f, f') of
          (TName c, _) =>
            (case IntMap.find (phi, #stamp c) of
               SOME g => fcn (g, f')
             | NONE => (case f' of TName c' => pair (c, c') | _ => raise Disagree))
        | (TAbbrev (ps, t), TAbbrev (ps', t')) => if List.length ps <> List.length ps' then raise Disagree else scheme (t, t')
        | (TAbbrev (_, t), TName c') => scheme (t, TCon (c', []))
      fun maps (f : 'a * 'a -> unit) (m : 'a StringMap.map, m' : 'a StringMap.map) : unit =
        if StringMap.numItems m <> StringMap.numItems m' then raise Disagree
        else StringMap.appi (fn (n, x) => case StringMap.find (m', n) of SOME y => f (x, y) | NONE => raise Disagree) m
      fun walk (Env {vals, tys = ts, strs,origins}, Env {vals = vals', tys = ts', strs = strs',origins=origins'}) =
        (maps value (vals, vals');
         maps (fn (TyStr {fcn = f, cons}, TyStr {fcn = f', cons = cons'}) =>
                  (fcn (f, f');
                   if List.length cons <> List.length cons' then raise Disagree
                   else ListPair.app (fn ((n, v), (n', v')) => if n = n' then value (v, v') else raise Disagree) (cons, cons')))
              (ts, ts');
         maps walk (strs, strs'))
      (* where the copy is more general: the summary's types, realised,
         with the copy's stamps and constructors *)
      fun merged () =
        let
          fun value (v, v') =
            case (v, v') of
              (Val {scheme, ...}, Val {stamp, global, ...}) => Val {scheme = scheme, stamp = stamp, global = global}
            | (Con {scheme, ...}, Con {info, ...}) => Con {scheme = scheme, info = info}
            | (Exn {ty = t, ...}, Exn {info, ...}) => Exn {ty = t, info = info}
            | (Prim {scheme, ...}, Prim {name, ...}) => Prim {scheme = scheme, name = name}
            | (ConAsVal {scheme, ...}, ConAsVal {info, ...}) => ConAsVal {scheme = scheme, info = info}
            | (ExnAsVal {ty = t, ...}, ExnAsVal {info, ...}) => ExnAsVal {ty = t, info = info}
            | _ => raise Disagree
          fun get (m', n) = case StringMap.find (m', n) of SOME y => y | NONE => raise Disagree
          fun env (Env {vals, tys = ts, strs,origins}, Env {vals = vals', tys = ts', strs = strs',origins=origins'}) : env =
            Env {vals = StringMap.mapi (fn (n, v) => value (v, get (vals', n))) vals,
                 tys = StringMap.mapi (fn (n, TyStr {fcn = f, cons}) =>
                                          let val TyStr {cons = cons', ...} = get (ts', n)
                                          in TyStr {fcn = f, cons = ListPair.map (fn ((c, v), (_, v')) => (c, value (v, v'))) (cons, cons')} end)
                                      ts,
                 strs = StringMap.mapi (fn (n, e) => env (e, get (strs', n))) strs,origins=origins'}
          val typed = realizeEnv (IntMap.unionWith #2 (phi, !psi), env (result, copy))
          (* no name of the body's left where the copy has none in its place *)
          fun left t =
            case prune t of
              TVar _ => ()
            | TCon (c, xs) => if IntMap.member (made, #stamp c) then raise Disagree else List.app left xs
            | TRecord fs => List.app (fn (_, x) => left x) fs
            | TArrow (x, y) => (left x; left y)
        in appEnvTypes left typed; typed end
      (* the copy can be more general only where the argument's type for a
         parameter's drops a type variable of it, and differ in equality
         only where a name the body made does not admit it *)
      fun drops (TName _) = false
        | drops (TAbbrev (ps, body)) =
            let
              val seen : int list ref = ref []
              fun occurs t =
                case prune t of
                  TVar (ref (Unbound {id, ...})) => seen := id :: !seen
                | TVar _ => ()
                | TCon (_, xs) => List.app occurs xs
                | TRecord fs => List.app (fn (_, x) => occurs x) fs
                | TArrow (x, y) => (occurs x; occurs y)
            in occurs body; not (List.all (fn p => List.exists (fn q => q = p) (!seen)) ps) end
      val alike = not (List.exists (fn c => not (#eq c)) generated)
                  andalso not (IntMap.foldl (fn (f, b) => b orelse drops f) false phi)
    in
      if alike andalso not (!lintSummaries) then SOME copy
      else
        (walk (result, copy);
         (* --lint: where nothing can differ, nothing does *)
         if alike andalso not (!same andalso IntMap.isEmpty (!fix)) then
           Error.bug ("the copy of " ^ where_ ^ " is typed otherwise than its signature where nothing should differ"
                      ^ (if !same then "" else " (more general)") ^ (if IntMap.isEmpty (!fix) then "" else " (equality)"))
         else ();
         SOME (if !same then (if IntMap.isEmpty (!fix) then copy else realizeEnv (!fix, copy)) else merged ()))
        handle Disagree => NONE
    end

  (* ------------------------------------------------------------------ *)
  (* Functors compiled once (--functors=functions; functors-units.md, M5) *)

  (* Whether what is elaborated is a functor's body under
     --functors=functions: its declarations bind local variables of the
     function the body is compiled to, not globals *)
  val inBody = ref false
  val () = CompilerState.cellRoot ("Elaborate.inBody", inBody)
  fun globalAt (top : bool) : bool = top andalso not (!inBody)

  (* A structure's record at run time (D3): a tuple of its slots, each
     cast to unit -- its values, exceptions (their constructors), and the
     constructors, exceptions and primitives a value specification gave as
     values, by name; then each substructure's record, by name, a record of
     its own; at least two. A structure has one where it reaches a
     functor: an argument, made where it is passed, unless one of the same
     slots is in reach (shared); the parameter, the function's argument; a
     result, the body's, from which the application's variables are set.
     A reach is where a record is in reach: the variable that holds one,
     and the substructures to go through, each by its place in the record
     and the number of slots of its own *)
  datatype record = Record of {vals : (string * valstatus) list, descs : desc list, strs : (string * record) list,
                               shared : reach option}
  (* A parameter's record holds, after its values, a descriptor for each
     constructor of a datatype it specifies whose layout it leaves open
     (D4, openConstructors): the number of fields of the argument's
     constructor, 0 where it boxes its argument. An argument's gives it, a
     constant, or the descriptor of the body it is made in where the
     argument's datatype is that body's parameter's; the parameter's are
     the function's variables *)
  and desc = DescConst of int | DescVar of int
  withtype reach = {var : int, global : bool, path : (int * int) list}

  fun slotsOf (Record {vals, descs, strs, ...}) : int = List.length vals + List.length descs + List.length strs
  fun recordTyOf (n : int) : ty = tupleTy (List.tabulate (Int.max (n, 2), fn _ => unitTy))
  fun recordTy (r : record) : ty = recordTyOf (slotsOf r)

  (* the values of an environment that are slots: all but the
     constructors, which are the datatype's, the same in every instance *)
  fun valSlots (Env {vals, ...}) : (string * valstatus) list =
    List.filter (fn (_, Con _) => false | _ => true) (StringMap.listItemsi vals)

  fun recordOf (e : env) : record =
    Record {vals = valSlots e, descs = [], strs = List.map (fn (n, s) => (n, recordOf s)) (StringMap.listItemsi (strs e)),
            shared = NONE}

  (* The records in reach, by what their slots hold (key): while one
     top-level declaration is elaborated, which is compiled as a whole in
     every mode, so that whether one is shared does not depend on what is
     compiled with it (elabTop empties it) *)
  val inReach : reach StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Elaborate.inReach", inReach)

  exception Unshared
  fun recordKey (Record {vals, descs, strs, ...}) : string =
    let
      fun slot (_, v) =
        case v of
          Val {stamp, ...} => Int.toString stamp ^ ","
        | Exn {info, ...} => if isSome (#builtin info) then raise Unshared else "e" ^ Int.toString (#stamp info) ^ ","
        | _ => raise Unshared
      fun desc (DescConst n) = "#" ^ Int.toString n ^ ","
        | desc (DescVar d) = "d" ^ Int.toString d ^ ","
    in
      "(" ^ String.concat (List.map slot vals) ^ String.concat (List.map desc descs)
      ^ String.concat (List.map (fn (_, r) => recordKey r) strs) ^ ")"
    end
  fun keyOf (r : record) : string option = SOME (recordKey r) handle Unshared => NONE

  (* r is in reach by h, and so is each of its substructures' *)
  fun register (r as Record {vals, descs, strs, ...}, h : reach) : unit =
    (case keyOf r of SOME k => inReach := StringMap.insert (!inReach, k, h) | NONE => ();
     ignore (List.foldl (fn ((_, sub), i) =>
                           (register (sub, {var = #var h, global = #global h, path = #path h @ [(i, slotsOf sub)]}); i + 1))
                        (List.length vals + List.length descs) strs))

  (* the record an argument's environment, thinned to the parameter's
     signature, makes, with the descriptors given: one in reach where there
     is one *)
  fun argRecordWith (e : env, descs : desc list) : record =
    let
      val vals = valSlots e
      val strs = List.map (fn (n, s) => (n, argRecordWith (s, []))) (StringMap.listItemsi (strs e))
      val r = Record {vals = vals, descs = descs, strs = strs, shared = NONE}
    in
      case Option.mapPartial (fn k => StringMap.find (!inReach, k)) (keyOf r) of
        SOME h => Record {vals = vals, descs = descs, strs = strs, shared = SOME h}
      | NONE => r
    end

  (* What Translate makes of a functor's declaration and of an
     application, by the place of the one and the other (spanKey): the
     function's global, the variable of its argument, the parameter's
     record, which its variables are set from, and the body's, its result;
     the function an application calls, the record it gives it, the
     variable of what it returns, and the record of that, which the
     application's variables are set from *)
  (* a constructor whose layout the parameter leaves open, in the body:
     the parameter's datatype and the tag, the variable of its descriptor,
     the functions that make and take apart such a constructor by it (con,
     decon), the datatype at its parameters and the constructor's argument *)
  type openCon = {tycon : int, tag : int, desc : int, con : int, decon : int, dataTy : ty, argTy : ty}
  type functorCode = {func : int, param : int, paramRecord : record, result : record, opens : openCon list}
  type callCode = {func : int, arg : record, result : int, global : bool, record : record}
  fun spanKey ({file, start, stop} : Source.span) : string =
    file ^ "\000" ^ Int.toString start ^ "\000" ^ Int.toString stop
  val bodies : functorCode StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Elaborate.bodies", bodies)
  val calls : callCode StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("Elaborate.calls", calls)
  fun bodyAt (sp : Source.span) : functorCode option = StringMap.find (!bodies, spanKey sp)
  fun callAt (sp : Source.span) : callCode option = StringMap.find (!calls, spanKey sp)

  (* The datatypes a signature specifies that the compiler's tables do not
     have, under the names an instance of the signature gave them (rule
     65): their constructors from the specification's, with their schemes
     and tags -- what a functor's body is compiled against, and a dynamic
     module's program (StrDynamic) *)
  fun specDatatypes (isNew : tycon -> bool, e : env) : int list =
    let
      val specified : int list ref = ref []
      fun datatypes (Env {tys, strs, ...}) =
        (StringMap.app (fn TyStr {fcn = TName c, cons = cs as _ :: _} =>
                           if isNew c then
                             let
                               val () = specified := #stamp c :: !specified
                               fun result t = case prune t of TArrow (_, r) => prune r | r => r
                               val params = case cs of
                                              (_, Con {scheme, ...}) :: _ =>
                                                (case result scheme of
                                                   TCon (_, args) => List.mapPartial (fn a => case prune a of
                                                                                                TVar (ref (Unbound {id, ...})) => SOME id
                                                                                              | _ => NONE) args
                                                 | _ => [])
                                            | _ => []
                               val cons = List.mapPartial (fn (n, Con {scheme, info}) =>
                                                                SOME (#tag info, n, case prune scheme of TArrow (a, _) => SOME a | _ => NONE)
                                                            | _ => NONE) cs
                               val sorted = List.foldl (fn (x as (t, _, _), acc) =>
                                                          let fun ins [] = [x]
                                                                | ins ((y as (u, _, _)) :: rest) = if t < u then x :: y :: rest else y :: ins rest
                                                          in ins acc end) [] cons
                             in
                               Ty.bindDatatype (#stamp c, {params = params, cons = sorted});
                               dataCons := IntMap.insert (!dataCons, #stamp c, cs)
                             end
                           else ()
                         | _ => ()) tys;
         StringMap.app datatypes strs)
    in datatypes e; !specified end

  (* The parameter's values and exceptions as local variables of the
     function the body is compiled to, fresh ones *)
  fun localParam (Env {vals, tys, strs, origins}) : env =
    let
      fun value v =
        case v of
          Val {scheme, ...} =>
            let val s = freshStamp () in Ty.bindVar (s, scheme); Val {scheme = scheme, stamp = s, global = false} end
        | Exn {ty, info} =>
            if isSome (#builtin info) then v
            else
              let
                val s = freshStamp ()
                val () = Ty.bindExn (s, case prune ty of TArrow (a, _) => SOME a | _ => NONE)
              in Exn {ty = ty, info = {name = #name info, stamp = s, isGlobal = false, hasArg = #hasArg info, builtin = NONE}} end
        | other => other
      val vals' = List.foldl (fn ((n, v), m) => StringMap.insert (m, n, value v)) StringMap.empty (StringMap.listItemsi vals)
      val strs' = List.foldl (fn ((n, e), m) => StringMap.insert (m, n, localParam e)) StringMap.empty (StringMap.listItemsi strs)
    in Env {vals = vals', tys = tys, strs = strs', origins = origins} end

  (* An application's result: the summary's values and exceptions given
     fresh variables -- globals at the top level, locals in a body -- which
     the call's result sets; an exception a value specification gave as a
     value is a value then *)
  fun freshSlots (g : bool, Env {vals, tys, strs, origins}) : env =
    let
      fun bindVal (scheme : ty) : valstatus =
        let val s = freshStamp () in Ty.bindVar (s, scheme); Val {scheme = scheme, stamp = s, global = g} end
      fun value v =
        case v of
          Val {scheme, ...} => bindVal scheme
        | ExnAsVal {ty, ...} => bindVal ty
        | Exn {ty, info} =>
            if isSome (#builtin info) then v
            else
              let
                val s = freshStamp ()
                val () = Ty.bindExn (s, case prune ty of TArrow (a, _) => SOME a | _ => NONE)
              in Exn {ty = ty, info = {name = #name info, stamp = s, isGlobal = g, hasArg = #hasArg info, builtin = NONE}} end
        | other => other
      val vals' = List.foldl (fn ((n, v), m) => StringMap.insert (m, n, value v)) StringMap.empty (StringMap.listItemsi vals)
      val strs' = List.foldl (fn ((n, e), m) => StringMap.insert (m, n, freshSlots (g, e))) StringMap.empty (StringMap.listItemsi strs)
    in Env {vals = vals', tys = tys, strs = strs', origins = origins} end

  (* The type names made from lo on that an environment names, and those
     an opaque one of them stands for (Ty.realizations), by stamp: what an
     application's summary makes fresh, so that a type of a client is
     never one of the body's that names the parameter's types *)
  fun generatedDeep (lo : int, e : env) : tycon list =
    let
      val seen : tycon IntMap.map ref = ref IntMap.empty
      fun name (c : tycon) =
        if #stamp c < lo orelse IntMap.member (!seen, #stamp c) then ()
        else
          (seen := IntMap.insert (!seen, #stamp c, c);
           case IntTable.find (Ty.realizations, #stamp c) of
             SOME (TName c') => name c'
           | SOME (TAbbrev (_, t)) => ty t
           | NONE => ())
      and ty t =
        case prune t of
          TVar _ => ()
        | TCon (c, args) => (name c; List.app ty args)
        | TRecord fields => List.app (fn (_, a) => ty a) fields
        | TArrow (a, b) => (ty a; ty b)
    in appEnvTypes ty e; IntMap.listItems (!seen) end

  (* A name an application's summary made fresh (c'), in place of the
     body's (c): a datatype's constructors with the types the application
     realised (phi), and the layout the body gave them (D5); an opaque
     name's realisation, realised *)
  fun instance (phi : realisation, c : tycon, c' : tycon) : unit =
    ((case IntMap.find (!Ty.datatypes, #stamp c) of
        SOME {params, cons} =>
          (Ty.extras := Ty.Unknown;
           Ty.datatypes := IntMap.insert (!Ty.datatypes, #stamp c',
                                          {params = params,
                                           cons = List.map (fn (t, n, a) =>
                                                               (t, n, Option.map (fn Ty.FromElab x => Ty.FromElab (realize (phi, x))
                                                                                   | d => d) a)) cons});
           Ty.pinLayout (#stamp c', Ty.layoutOf (#stamp c)))
      | NONE => ());
     (case IntTable.find (Ty.realizations, #stamp c) of
        SOME f => Ty.bindRealization (#stamp c', realizeFcn (phi, f))
      | NONE => ());
     (case IntMap.find (!dataCons, #stamp c) of
        SOME cs => dataCons := IntMap.insert (!dataCons, #stamp c',
                                              List.map (fn (n, Con {scheme, info}) => (n, Con {scheme = realize (phi, scheme), info = info})
                                                         | x => x) cs)
      | NONE => ()))

  (* The constructors whose layout a parameter's signature leaves open
     (D4): of a datatype it specifies, one whose argument is one of its
     abstract types, which the argument may realise as a tuple, laid out
     flat where the specification reads it boxed. In the order of the
     signature's types, then its structures', by name, each datatype's by
     tag: the datatype, the tag and the constructor's scheme *)
  fun openConstructors ({bound, env = pe, ...} : SigMatch.sigma) : (tycon * int * ty) list =
    let
      fun isBound (c : tycon) = List.exists (fn b => #stamp b = #stamp c) bound
      fun isDatatype (c : tycon) = IntMap.member (!Ty.datatypes, #stamp c)
      fun opens (c, cs) =
        List.mapPartial (fn (_, Con {scheme, info}) =>
                              (case prune scheme of
                                 TArrow (arg, _) =>
                                   (case prune arg of
                                      TCon (u, _) => if isBound u andalso not (isDatatype u) then SOME (#tag info, (c, #tag info, scheme))
                                                     else NONE
                                    | _ => NONE)
                               | _ => NONE)
                          | _ => NONE) cs
      fun byTag l = List.foldl (fn (x as (t, _), acc) =>
                                  let fun ins [] = [x] | ins ((y as (u, _)) :: rest) = if t < u then x :: y :: rest else y :: ins rest
                                  in ins acc end) [] l
      fun go (Env {tys, strs, ...}) =
        List.concat (List.map (fn (_, TyStr {fcn = TName c, cons = cs as _ :: _}) =>
                                    if isBound c then List.map #2 (byTag (opens (c, cs))) else []
                                | _ => []) (StringMap.listItemsi tys))
        @ List.concat (List.map (fn (_, e) => go e) (StringMap.listItemsi strs))
    in go pe end

  (* the open constructors of the bodies elaborated, by the stamp of the
     parameter's datatype: what Translate and ToMid build and take apart
     such a constructor by *)
  val opened : openCon list IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("Elaborate.opened", opened)
  fun openAt (stamp : int, tag : int) : openCon option =
    case IntMap.find (!opened, stamp) of
      SOME l => List.find (fn (o' : openCon) => #tag o' = tag) l
    | NONE => NONE
  fun hasOpen (stamp : int) : bool = IntMap.member (!opened, stamp)

  (* An argument's descriptors for a parameter's open constructors: its
     datatype's layout of each (phi), or, where its datatype is the
     parameter's of the body the application is in, that body's
     descriptor *)
  fun descriptors (paramSig : SigMatch.sigma, phi : realisation, sp : Source.span) : desc list =
    List.map (fn (c, tag, _) =>
                case IntMap.find (phi, #stamp c) of
                  SOME (TName a) =>
                    (case openAt (#stamp a, tag) of
                       SOME {desc, ...} => DescVar desc
                     | NONE =>
                         (case List.find (fn (t, _) => t = tag) (Ty.layoutOf (#stamp a)) of
                            SOME (_, SOME n) =>
                              if n > Ty.maxFlat then
                                err (sp, "--functors=functions: the argument lays out a constructor of " ^ #name c ^ " in "
                                         ^ Int.toString n ^ " fields, more than the " ^ Int.toString Ty.maxFlat
                                         ^ " a descriptor may give")
                              else DescConst n
                          | _ => DescConst 0))
                | _ => Error.bug ("a datatype of a parameter realised by no type name: " ^ #name c))
             (openConstructors paramSig)

  (* ------------------------------------------------------------------ *)
  (* Types                                                                *)
  fun elabTy (env, scope : scope, level, t : Ast.ty) : ty =
    case t of
      TyVar (v, sp) =>
        (case StringMap.find (!scope, v) of
           SOME t => t
         | NONE => err (sp, "unbound type variable " ^ v))
    | TyRecord (fields, sp) =>
        (checkDupLabels (fields, sp);
         TRecord (sortFields (List.map (fn (l, t) => (l, elabTy (env, scope, level, t))) fields)))
    | TyTuple (ts, _) => tupleTy (List.map (fn t => elabTy (env, scope, level, t)) ts)
    | TyCon (args, longid, sp) =>
        let
          val args' = List.map (fn t => elabTy (env, scope, level, t)) args
          val () =
            case longid of
              ([], name) =>
                if String.isPrefix "_" name andalso not (!allowPrim)
                then err (sp, "_prim is only allowed when compiling with --allow-prim")
                else ()
            | _ => ()
        in
          (Env.noteUse (env,"t",longid,sp);case findTy (env, longid) of
            NONE => err (sp, "unbound type constructor: " ^ longidToString longid)
          | SOME (TyStr {fcn, ...}) =>
              if List.length args' <> fcnArity fcn then
                err (sp, "type constructor " ^ longidToString longid ^ " expects " ^ Int.toString (fcnArity fcn)
                         ^ " argument(s) but got " ^ Int.toString (List.length args'))
              else applyFcn (fcn, args'))
        end
    | TyArrow (a, b, _) => TArrow (elabTy (env, scope, level, a), elabTy (env, scope, level, b))

  (* A generic parameter variable for type abbreviations and datatypes. *)
  fun paramVar (name : string) : int * ty =
    let val t = freshTvar (genericLevel, KPlain, String.isPrefix "''" name)
    in
      case t of
        TVar (ref (Unbound {id, ...})) => (id, t)
      | _ => Error.bug "paramVar"
    end

  (* ------------------------------------------------------------------ *)
  (* Patterns                                                             *)
  fun bindingsToEnv (bindings : (string * valstatus) list) =
    List.foldl (fn ((n, v), e) => bindVal (e, n, v)) Env.empty bindings

  fun lookupCon (env, longid, sp) =
    case findVal (env, longid) of
      SOME (Con c) => (Env.noteUse (env,"v",longid,sp);SOME (Con c))
    | SOME (Exn e) => (Env.noteUse (env,"v",longid,sp);SOME (Exn e))
    | SOME _ => NONE                       (* values, including constructors that lost their status *)
    | NONE =>
        (case longid of
           ([], _) => NONE
         | _ => err (sp, "unbound constructor: " ^ longidToString longid))

  fun elabPat (env, level, scope, isGlobal, p : pat, bound : (string * span) list ref)
      : ty * (string * valstatus) list =
    let
      (* An alternative of an or-pattern after the first binds the variables
         of the first, to the same stamps and types: shares holds their
         bindings, the innermost or-pattern's first, with the names the
         alternative has bound so far. *)
      val shares : ((string * (int * ty * (string * valstatus))) list * string list ref) list ref = ref []
      fun bindVar (name, sp) =
        case !shares of
          (share, seen) :: _ =>
            (checkBindable (name, sp, true);
             if List.exists (fn n => n = name) (!seen) then err (sp, "duplicate variable '" ^ name ^ "' in pattern")
             else seen := name :: !seen;
             case List.find (fn (n, _) => n = name) share of
               SOME (_, b) => b
             | NONE => err (sp, "variable '" ^ name ^ "' is not bound by the first alternative of the or-pattern"))
        | [] =>
            (checkBindable (name, sp, true);
             if List.exists (fn (n, _) => n = name) (!bound) then
               err (sp, "duplicate variable '" ^ name ^ "' in pattern")
             else bound := (name, sp) :: !bound;
             let
               val stamp = freshStamp ()
               val t = fresh level
             in
               Ty.bindVar (stamp, t); Ty.nameVar (stamp, name, t); Env.noteStamp (stamp,name,sp);
               (stamp, t, (name, Val {scheme = t, stamp = stamp, global = isGlobal}))
             end)
      fun elab p =
        case p of
          PWild _ => (fresh level, [])
        | PScon (sc, slot, sp) => (sconTy (level, sc, slot, sp), [])
        | PVar (longid as (path, name), slot, sp) =>
            (case lookupCon (env, longid, sp) of
               SOME (Con {scheme, info}) =>
                 if #hasArg info then err (sp, "constructor " ^ name ^ " expects an argument")
                 else (slot := SOME (PICon info); (Unify.instantiate (level, scheme), []))
             | SOME (Exn {ty, info}) =>
                 if #hasArg info then err (sp, "exception constructor " ^ name ^ " expects an argument")
                 else (slot := SOME (PIExn info); (ty, []))
             | _ =>
                 (case path of
                    [] => let val (stamp, t, b) = bindVar (name, sp)
                          in slot := SOME (PIVar (stamp, isGlobal)); (t, [b]) end
                  | _ => err (sp, longidToString longid ^ " is not a constructor")))
        | PRecord (fields, flex, slot, sp) =>
            let
              val () = checkDupLabels (fields, sp)
              val results = List.map (fn (l, p) => let val (t, bs) = elab p in ((l, t), bs) end) fields
              val ftys = sortFields (List.map #1 results)
              val bindings = List.concat (List.map #2 results)
            in
              if flex then
                let val r = freshFlex (level, ftys, false)
                in
                  case r of
                    TVar rr => pendingFlex := (rr, sp) :: !pendingFlex
                  | _ => ();
                  slot := SOME r;
                  (r, bindings)
                end
              else (TRecord ftys, bindings)
            end
        | PTuple ([], _) => (unitTy, [])
        | PTuple (ps, _) =>
            let val results = List.map elab ps
            in (tupleTy (List.map #1 results), List.concat (List.map #2 results)) end
        | PList (ps, sp) =>
            let
              val a = fresh level
              val results = List.map (fn p => let val (t, bs) = elab p
                                              in unifyAt (spanOfPat p, a, t, "list pattern element"); bs end) ps
            in (listTy a, List.concat results) end
        | PApp (longid, slot, arg, sp) =>
            let
              val conTy =
                case lookupCon (env, longid, sp) of
                  SOME (Con {scheme, info}) =>
                    if not (#hasArg info) then err (sp, "constructor " ^ #name info ^ " takes no argument")
                    else (slot := SOME (PICon info); Unify.instantiate (level, scheme))
                | SOME (Exn {ty, info}) =>
                    if not (#hasArg info) then err (sp, "exception constructor " ^ #name info ^ " takes no argument")
                    else (slot := SOME (PIExn info); ty)
                | _ => err (sp, longidToString longid ^ " is not a constructor")
              val (targ, bs) = elab arg
            in
              case conTy of
                TArrow (dom, cod) => (unifyAt (spanOfPat arg, dom, targ, "constructor argument"); (cod, bs))
              | _ => Error.bug "constructor with argument has non-arrow type"
            end
        | PTyped (p, t, sp) =>
            let
              val (tp, bs) = elab p
              val ta = elabTy (env, scope, level, t)
            in unifyAt (sp, ta, tp, "pattern type annotation"); (ta, bs) end
        | PLayered (name, tyopt, p, slot, sp) =>
            let
              val (stamp, tv, b) = bindVar (name, sp)
              val () = slot := SOME (PIVar (stamp, isGlobal))
              val (tp, bs) = elab p
              val () = unifyAt (sp, tv, tp, "layered pattern")
              val () = case tyopt of
                         NONE => ()
                       | SOME t => unifyAt (sp, elabTy (env, scope, level, t), tv, "pattern type annotation")
            in (tv, b :: bs) end
        | POr (p1 :: rest, _) =>
            let
              val (t1, bs1) = elab p1
              val share = List.mapPartial (fn (name, st as Val {scheme, stamp, ...}) => SOME (name, (stamp, scheme, (name, st)))
                                            | _ => NONE) bs1
              fun alt p =
                let
                  val seen = ref []
                  val () = shares := (share, seen) :: !shares
                  val (t, _) = elab p
                  val () = shares := List.tl (!shares)
                in
                  case List.find (fn (n, _) => not (List.exists (fn m => m = n) (!seen))) share of
                    SOME (n, _) => err (spanOfPat p, "variable '" ^ n ^ "' is not bound by every alternative of the or-pattern")
                  | NONE => unifyAt (spanOfPat p, t1, t, "or-pattern alternative")
                end
            in List.app alt rest; (t1, bs1) end
        | POr ([], _) => Error.bug "an or-pattern of no alternative"
    in
      elab p
    end

  (* ------------------------------------------------------------------ *)
  (* Expressions                                                          *)
  fun nonexpansive e =
    case e of
      EScon _ => true
    | EVar _ => true
    | EFn _ => true
    | EPrim _ => true
    | ESelect _ => true
    | ETuple (es, _) => List.all nonexpansive es
    | ERecord (fs, _) => List.all (fn (_, e) => nonexpansive e) fs
    | EList (es, _, _) => List.all nonexpansive es
    | ETyped (e, _, _) => nonexpansive e
    | EApp (EVar (_, slot, _), a, _) =>
        (case !slot of
           SOME (VCon (info, _)) => not (#isRef info) andalso nonexpansive a
         | SOME (VExn _) => nonexpansive a
         | _ => false)                     (* a constructor that lost its status is an ordinary variable *)
    | _ => false

  fun elabExp (env, level, scope : scope, e : exp) : ty =
    (Env.noteExpression (e,env);case e of
      EScon (sc, slot, sp) => sconTy (level, sc, slot, sp)
    | EVar (longid, slot, sp) =>
        (Env.noteUse (env,"v",longid,sp);case findVal (env, longid) of
           NONE => err (sp, "unbound variable or constructor: " ^ longidToString longid)
         | SOME (Val {scheme, stamp, global}) =>
             let val t = Unify.instantiate (level, scheme)
             in slot := SOME (if global then VGlobal (stamp, t) else VLocal (stamp, t)); t end
         | SOME (Con {scheme, info}) =>
             let val t = Unify.instantiate (level, scheme) in slot := SOME (VCon (info, t)); t end
         | SOME (Exn {ty, info}) => (slot := SOME (VExn (info, ty)); ty)
         | SOME (Prim {scheme, name}) =>
             let val t = Unify.instantiate (level, scheme)
             in registerOverloads t; slot := SOME (VBuiltin (name, t)); t end
         | SOME (ConAsVal {scheme, info}) =>
             let val t = Unify.instantiate (level, scheme) in slot := SOME (VConVal (info, t)); t end
         | SOME (ExnAsVal {ty, info}) => (slot := SOME (VExnVal (info, ty)); ty))
    | ERecord (fields, sp) =>
        (checkDupLabels (fields, sp);
         TRecord (sortFields (List.map (fn (l, e) => (l, elabExp (env, level, scope, e))) fields)))
    | ETuple ([], _) => unitTy
    | ETuple (es, _) => tupleTy (List.map (fn e => elabExp (env, level, scope, e)) es)
    | ESelect (lab, slot, sp) =>
        let
          val a = fresh level
          val r = freshFlex (level, [(lab, a)], false)
        in
          case r of TVar rr => pendingFlex := (rr, sp) :: !pendingFlex | _ => ();
          slot := SOME r;
          TArrow (r, a)
        end
    | EList (es, slot, _) =>
        let val a = fresh level
        in
          List.app (fn e => unifyAt (spanOfExp e, a, elabExp (env, level, scope, e), "list element")) es;
          slot := SOME (listTy a);
          listTy a
        end
    | ESeq (es, _) =>
        List.foldl (fn (e, _) => elabExp (env, level, scope, e)) unitTy es
    | ELet (decs, body, sp) =>
        let
          val first = !tyconCounter
          val delta = elabDecs (env, level, false, scope, decs)
          val result = elabExp (plus (env, delta), level, scope, body)
          val () = if !tyconCounter = first then ()
                   else (Types.noEscape (first, sp, result); Env.noEscape (first, sp, env))
        in result end
    | EApp (f, a, sp) =>
        let
          val tf = elabExp (env, level, scope, f)
          val ta = elabExp (env, level, scope, a)
        in
          case prune tf of
            TArrow (dom, cod) => (unifyAt (spanOfExp a, dom, ta, "function argument"); cod)
          | _ =>
            let val r = fresh level
            in unifyAt (sp, tf, TArrow (ta, r), "function application"); r end
        end
    | ETyped (e, t, sp) =>
        let
          val te = elabExp (env, level, scope, e)
          val ta = elabTy (env, scope, level, t)
        in unifyAt (sp, ta, te, "type annotation"); ta end
    | EAndalso (a, b, _) =>
        (unifyAt (spanOfExp a, boolTy, elabExp (env, level, scope, a), "operand of andalso");
         unifyAt (spanOfExp b, boolTy, elabExp (env, level, scope, b), "operand of andalso");
         boolTy)
    | EOrelse (a, b, _) =>
        (unifyAt (spanOfExp a, boolTy, elabExp (env, level, scope, a), "operand of orelse");
         unifyAt (spanOfExp b, boolTy, elabExp (env, level, scope, b), "operand of orelse");
         boolTy)
    | EHandle (e, rules, sp) =>
        let val te = elabExp (env, level, scope, e)
        in elabMatch (env, level, scope, rules, exnTy, te, false, sp); te end
    | ERaise (e, _) =>
        (unifyAt (spanOfExp e, exnTy, elabExp (env, level, scope, e), "argument of raise"); fresh level)
    | EIf (c, t, e, _) =>
        let
          val () = unifyAt (spanOfExp c, boolTy, elabExp (env, level, scope, c), "condition of if")
          val tt = elabExp (env, level, scope, t)
          val te = elabExp (env, level, scope, e)
        in unifyAt (spanOfExp e, tt, te, "branches of if"); tt end
    | EWhile (c, b, _) =>
        (unifyAt (spanOfExp c, boolTy, elabExp (env, level, scope, c), "condition of while");
         ignore (elabExp (env, level, scope, b));
         unitTy)
    | ECase (e, rules, sp) =>
        let
          val te = elabExp (env, level, scope, e)
          val res = fresh level
        in elabMatch (env, level, scope, rules, te, res, true, sp); res end
    | EFn (rules, slot, sp) =>
        let
          val arg = fresh level
          val res = fresh level
        in elabMatch (env, level, scope, rules, arg, res, true, sp); slot := SOME (TArrow (arg, res)); TArrow (arg, res) end
    | EPrim (name, t, slot, sp) =>
        if not (!allowPrim) then err (sp, "_prim is only allowed when compiling with --allow-prim")
        else
          (case Prims.find name of
             NONE => err (sp, "unknown primitive '" ^ name ^ "'")
           | SOME _ => let val ty = elabTy (env, scope, level, t) in slot := SOME ty; ty end))

  (* Section 4.11: a fn match must be exhaustive, every match irredundant. *)
  and elabMatch (env, level, scope, rules : mrule list, argTy, resTy, exhaustive : bool, sp) =
    (List.app (fn (p, e) =>
                 let
                   val bound = ref []
                   val (tp, bindings) = elabPat (env, level, scope, false, p, bound)
                   val () = unifyAt (spanOfPat p, argTy, tp, "pattern")
                   val env' = plus (env, bindingsToEnv bindings)
                   val te = elabExp (env', level, scope, e)
                 in unifyAt (spanOfExp e, resTy, te, "result of match rule") end) rules;
     deferCheck (fn () => Exhaust.checkMatch (List.map #1 rules, sp, exhaustive)))

  (* ------------------------------------------------------------------ *)
  (* Declarations. Return the environment delta.                          *)
  and elabDecs (env, level, top, scope, decs : dec list) : env =
    let
      fun go ([], _, delta, _) = delta
        | go (d :: rest, env, delta, from) =
          let val span=spanOfDec d
              val ()=Env.noteScope ({file= #file span,start=from,stop= #stop span},env)
              val d' = elabDec (env, level, top, scope, d)
          in go (rest, plus (env, d'), plus (delta, d'), #stop span) end
    in go (decs, env, Env.empty,case decs of [] => 0 | d::_ => #start (spanOfDec d)) end

  and elabDec (env, level, top, outerScope : scope, d : dec) : env =
    case d of
      DVal (tvs, binds, sp) =>
        let
          val (scope, scoped) = valScope (outerScope, tvs, d, level + 1, sp)
          val allBindings =
            List.map (fn (p, e) =>
                         let
                           val te = elabExp (env, level + 1, scope, e)
                           val bound = ref []
                           val (tp, bindings) = elabPat (env, level + 1, scope, globalAt top, p, bound)
                           val () = unifyAt (spanOfPat p, tp, te, "val binding")
                           val () = if nonexpansive e then generalizeBinding (level, tp, spanOfPat p)
                                    else Unify.lowerLevels (level, tp)
                           (* 4.11: reported except for components of a top-level declaration *)
                           val () = if top then () else deferCheck (fn () => Exhaust.checkBinding (p, spanOfPat p))
                         in bindings end) binds
          val flat = List.concat allBindings
          fun checkDups [] = ()
            | checkDups ((n, _) :: rest) =
              if List.exists (fn (m, _) => m = n) rest then err (sp, "duplicate variable '" ^ n ^ "' in val declaration")
              else checkDups rest
        in
          checkDups flat; checkGeneralised (scope, scoped, level, sp);
          if top andalso !flexRecords = FlexDeclaration then settleFlex () else ();
          bindingsToEnv flat
        end
    | DValRec (tvs, binds, sp) =>
        let
          val (scope, scoped) = valScope (outerScope, tvs, d, level + 1, sp)
          fun isFn (EFn _) = true
            | isFn (ETyped (e, _, _)) = isFn e
            | isFn _ = false
          (* every variable of a binding's pattern is bound to the same function *)
          val prepared =
            List.map (fn (p, e) =>
                         let
                           val (vars, tys) =
                             case recBindVars p of
                               SOME r => r
                             | NONE => err (spanOfPat p, "val rec requires a variable on the left-hand side")
                           val () = if isFn e then () else err (spanOfExp e, "val rec right-hand side must be a function expression")
                           val tv = fresh (level + 1)
                           val bindings =
                             List.map (fn (name, slot, psp) =>
                                          let val stamp = freshStamp ()
                                          in
                                            checkBindable (name, psp, true);
                                            Ty.bindVar (stamp, tv);
                                            Ty.nameVar (stamp, name, tv);Env.noteStamp (stamp,name,psp);
                                            slot := SOME (PIVar (stamp, globalAt top));
                                            (name, Val {scheme = tv, stamp = stamp, global = globalAt top})
                                          end) vars
                         in (bindings, tv, tys, e, spanOfPat p) end) binds
          val allBindings = List.concat (List.map #1 prepared)
          fun checkDups [] = ()
            | checkDups ((n, _) :: rest) =
              if List.exists (fn (m, _) => m = n) rest then err (sp, "duplicate variable '" ^ n ^ "' in val rec declaration")
              else checkDups rest
          val () = checkDups allBindings
          val env' = plus (env, bindingsToEnv allBindings)
        in
          List.app (fn (_, tv, tys, e, psp) =>
                       let
                         val () = List.app (fn t => unifyAt (psp, elabTy (env, scope, level + 1, t), tv, "val rec type annotation")) tys
                         val te = elabExp (env', level + 1, scope, e)
                       in unifyAt (spanOfExp e, tv, te, "val rec binding") end) prepared;
          List.app (fn (_, tv, _, _, psp) => generalizeBinding (level, tv, psp)) prepared;
          checkGeneralised (scope, scoped, level, sp);
          if top andalso !flexRecords = FlexDeclaration then settleFlex () else ();
          bindingsToEnv allBindings
        end
    | DFun (tvs, fundefs, sp) =>
        let
          val (scope, scoped) = valScope (outerScope, tvs, d, level + 1, sp)
          val prepared =
            List.map (fn (f : fundef) =>
                         let
                           val () = checkBindable (#name f, #span f, true)
                           val stamp = freshStamp ()
                           val tv = fresh (level + 1)
                           val () = Ty.bindVar (stamp, tv)
                           val () = Ty.nameVar (stamp, #name f, tv)
                           val () = Env.noteFunction (stamp,f)
                           val () = #info f := SOME (PIVar (stamp, globalAt top))
                         in (#name f, Val {scheme = tv, stamp = stamp, global = globalAt top}, tv, f) end) fundefs
          fun checkDups [] = ()
            | checkDups ((n, _, _, _) :: rest) =
              if List.exists (fn (m, _, _, _) => m = n) rest then err (sp, "duplicate function name '" ^ n ^ "'")
              else checkDups rest
          val () = checkDups prepared
          val env' = plus (env, bindingsToEnv (List.map (fn (n, v, _, _) => (n, v)) prepared))
        in
          List.app (fn (name, _, tv, f : fundef) =>
                      (List.app (fn {pats, resty, body} =>
                                    let
                                      val bound = ref []
                                      val results = List.map (fn p => elabPat (env', level + 1, scope, false, p, bound)) pats
                                      val argTys = List.map #1 results
                                      val bindings = List.concat (List.map #2 results)
                                      val env'' = plus (env', bindingsToEnv bindings)
                                      val tbody = elabExp (env'', level + 1, scope, body)
                                      val () = case resty of
                                                 NONE => ()
                                               | SOME t => unifyAt (spanOfExp body, elabTy (env, scope, level + 1, t), tbody, "function result type annotation")
                                      val clauseTy = List.foldr TArrow tbody argTys
                                    in unifyAt (#span f, tv, clauseTy, "clauses of function " ^ name) end)
                                (#clauses f);
                       deferCheck (fn () =>
                         Exhaust.checkClauses (List.map #pats (#clauses f),
                                               List.map (fn (c : clause) => spanOfPat (List.hd (#pats c))) (#clauses f),
                                               #span f)))) prepared;
          List.app (fn (_, _, tv, _) => generalizeBinding (level, tv, sp)) prepared;
          checkGeneralised (scope, scoped, level, sp);
          if top andalso !flexRecords = FlexDeclaration then settleFlex () else ();
          bindingsToEnv (List.map (fn (n, v, _, _) => (n, v)) prepared)
        end
    | DType (typbinds, _) =>
        List.foldl (fn (tb : typbind, delta) =>
                       let
                         val () = if StringMap.member (tys delta, #name tb) then
                                    err (#span tb, "duplicate type constructor '" ^ #name tb ^ "' in one declaration") else ()
                         val params = List.map paramVar (#tyvars tb)
                         val scope = ref (List.foldl (fn ((v, t), m) => StringMap.insert (m, v, t)) (!outerScope)
                                                     (ListPair.zip (#tyvars tb, List.map #2 params)))
                         val body = elabTy (env, scope, level, #ty tb)
                       in bindTyAt (delta, #name tb, TyStr {fcn = TAbbrev (List.map #1 params, body), cons = []},#span tb) end)
                   Env.empty typbinds
    | DDatatype (datbinds, typbinds, sp) =>
        let
          (* Fresh type names, provisionally admitting equality; the maximal
             attributes are computed below (Section 4.9, rule 17). *)
          fun dupTycons [] = ()
            | dupTycons ((db : datbind) :: rest) =
              if List.exists (fn (db' : datbind) => #name db' = #name db) rest
                 orelse List.exists (fn (tb : typbind) => #name tb = #name db) typbinds then
                err (#span db, "duplicate type constructor '" ^ #name db ^ "' in one declaration")
              else dupTycons rest
          val () = dupTycons datbinds
          val tycons = List.map (fn (db : datbind) => (db, freshTycon (#name db, List.length (#tyvars db), true))) datbinds
          val env1 = List.foldl (fn ((db, tc), e) => bindTyAt (e, #name db, TyStr {fcn = TName tc, cons = []},#span db)) env tycons
          val abbrevs = elabDec (env1, level, top, outerScope, DType (typbinds, sp))
          val env2 = plus (env1, abbrevs)
          fun elabDatbind ((db : datbind, tc), (delta, groups)) =
            let
              val params = List.map paramVar (#tyvars db)
              val scope = ref (List.foldl (fn ((v, t), m) => StringMap.insert (m, v, t)) (!outerScope)
                                          (ListPair.zip (#tyvars db, List.map #2 params)))
              val resTy = TCon (tc, List.map #2 params)
              val ncons = List.length (#cons db)
              (* the tags: in the order of the declaration, or of the
                 signature an _export ascribes it to (exportTags); by the
                 names, sorted, under --datatype-tags (Types.tagNames), as
                 every specification numbers them *)
              val order =
                case (!Types.tagOrder, StringMap.find (!exportTags, #name db)) of
                  (Types.TagsDeclared, SOME names) =>
                    if List.length names = ncons
                       andalso List.all (fn (c, _, _) => List.exists (fn n => n = c) names) (#cons db)
                    then names else List.map #1 (#cons db)
                | _ => Types.tagNames (List.map #1 (#cons db))
              fun tagOf c =
                let fun go (_, []) = 0 | go (i, n :: rest) = if n = c then i else go (i + 1, rest)
                in go (0, order) end
              val siblings = List.map (fn n => (n, List.exists (fn (c, a, _) => c = n andalso isSome a) (#cons db))) order
              val conArgs : (int * string * ty option) list ref = ref []
              val cons =
                List.foldl (fn ((cname, argOpt, csp), (acc, i, args)) =>
                               let
                                 val () = checkBindable (cname, csp, false)
                                 val () = if List.exists (fn (n, _) => n = cname) acc then
                                            err (csp, "duplicate constructor '" ^ cname ^ "'") else ()
                                 val tag = tagOf cname
                                 val (scheme, args) =
                                   case argOpt of
                                     NONE => (conArgs := (tag, cname, NONE) :: !conArgs; (resTy, args))
                                   | SOME t => let val ta = elabTy (env2, scope, level, t)
                                               in conArgs := (tag, cname, SOME ta) :: !conArgs; (TArrow (ta, resTy), ta :: args) end
                                 val info = {name = cname, tag = tag, hasArg = isSome argOpt, ncons = ncons, isRef = false,
                                             siblings = siblings}
                               in ((cname, Con {scheme = scheme, info = info}) :: acc, i + 1, args) end)
                           ([], 0, []) (#cons db)
              val args = #3 cons
              val cons = List.rev (#1 cons)
              (* by tag *)
              val sortedArgs = List.foldl (fn (x as (t, _, _), acc) =>
                                             let fun ins [] = [x]
                                                   | ins ((y as (u, _, _)) :: rest) = if t < u then x :: y :: rest else y :: ins rest
                                             in ins acc end) [] (!conArgs)
              val () = Ty.bindDatatype (#stamp tc, {params = List.map #1 params, cons = sortedArgs})
              val () = dataCons := IntMap.insert (!dataCons, #stamp tc, cons)
              val delta = bindTyAt (delta, #name db, TyStr {fcn = TName tc, cons = cons},#span db)
            in (List.foldl (fn ((n, v), d) => if !Env.tracking then
                bindValAt (d,n,v,#3 (valOf (List.find (fn (name,_,_) => name=n) (#cons db)))) else bindVal (d,n,v)) delta cons, (tc, args) :: groups) end
          val (delta, groups) = List.foldl elabDatbind (Env.empty, []) tycons
          (* Maximise equality: a datatype of the group admits equality iff
             every constructor argument does under the current assumption. *)
          fun admitsUnder (assume : bool IntMap.map) (t : ty) : bool =
            case prune t of
              TVar _ => true
            | TCon (c, args) =>
                (case IntMap.find (assume, #stamp c) of
                   SOME b => b andalso List.all (admitsUnder assume) args
                 | NONE =>
                     sameTycon (c, refTycon) orelse sameTycon (c, arrayTycon)
                     orelse (#eq c andalso List.all (admitsUnder assume) args))
            | TRecord fields => List.all (fn (_, a) => admitsUnder assume a) fields
            | TArrow _ => false
          fun iterate assume =
            let
              val assume' =
                List.foldl (fn ((tc : tycon, args), m) => IntMap.insert (m, #stamp tc, List.all (admitsUnder assume) args))
                           IntMap.empty groups
            in if IntMap.listItems assume' = IntMap.listItems assume then assume else iterate assume' end
          val final = iterate (List.foldl (fn ((tc : tycon, _), m) => IntMap.insert (m, #stamp tc, true)) IntMap.empty groups)
          val phi =
            List.foldl (fn ((tc : tycon, _), m) =>
                           IntMap.insert (m, #stamp tc, TName (withEq (tc, IntMap.lookup (final, #stamp tc)))))
                       IntMap.empty groups
        in
          realizeEnv (phi, plus (abbrevs, delta))
        end
    | DDatatypeRepl (name, longid, sp) =>
        (case findTy (env, longid) of
           SOME (ts as TyStr {cons, ...}) =>
             List.foldl (fn ((n, v), d) => Env.putOrigin (bindVal (d,n,v),"v",n,
               Env.originOf (env,"v",(#1 longid,n)))) (bindTyAt (Env.empty,name,ts,sp)) cons
         | NONE => err (sp, "unbound type constructor: " ^ longidToString longid))
    | DAbstype (datbinds, typbinds, decs, sp) =>
        let
          (* rule 19: the datatypes are visible with their constructors in the
             body only; outside they are abstract and do not admit equality *)
          val delta1 = elabDec (env, level, top, outerScope, DDatatype (datbinds, typbinds, sp))
          val delta2 = elabDecs (plus (env, delta1), level, top, outerScope, decs)
          val phi =
            StringMap.foldli (fn (_, TyStr {fcn = TName c, cons = _ :: _}, m) => IntMap.insert (m, #stamp c, TName (withEq (c, false)))
                               | (_, _, m) => m) IntMap.empty (tys delta1)
          val absTys = Env {origins=Env.origins delta1,vals = StringMap.empty,
                            tys = StringMap.map (fn TyStr {fcn, ...} => TyStr {fcn = realizeFcn (phi, fcn), cons = []}) (tys delta1),
                            strs = StringMap.empty}
        in plus (absTys, realizeEnv (phi, delta2)) end
    | DException (exbinds, _) =>
        List.foldl (fn (eb, delta) =>
                       case eb of
                         ExnDecl (name, tyopt, slot, sp) =>
                           let
                             val () = checkBindable (name, sp, false)
                             val () = if StringMap.member (vals delta, name) then
                                        err (sp, "duplicate exception constructor '" ^ name ^ "' in one declaration") else ()
                             val stamp = freshStamp ()
                             val scope = ref (!outerScope)
                             val arg = Option.map (fn t => elabTy (env, scope, level + 1, t)) tyopt
                             val ty = case arg of
                                        NONE => exnTy
                                      | SOME ta => TArrow (ta, exnTy)
                             val () = Ty.bindExn (stamp, arg)
                             val info = {name = name, stamp = stamp, isGlobal = globalAt top, hasArg = isSome tyopt, builtin = NONE}
                           in slot := SOME (PIExn info); bindValAt (delta, name, Exn {ty = ty, info = info},sp) end
                       | ExnRepl (name, longid, slot, sp) =>
                           (checkBindable (name, sp, false);
                            if StringMap.member (vals delta, name) then
                              err (sp, "duplicate exception constructor '" ^ name ^ "' in one declaration") else ();
                            case findVal (env, longid) of
                              SOME (Exn {ty, info}) => (slot := SOME (PIExn info); bindValAt (delta, name, Exn {ty = ty, info = info},sp))
                            | SOME _ => err (sp, longidToString longid ^ " is not an exception constructor")
                            | NONE => err (sp, "unbound exception constructor: " ^ longidToString longid)))
                   Env.empty exbinds
    | DLocal (d1, d2, _) =>
        let val delta1 = elabDecs (env, level, top, outerScope, d1)
        in elabDecs (plus (env, delta1), level, top, outerScope, d2) end
    | DOpen (ids, sp) =>
        List.foldl (fn ((path, name), delta) =>
                       case findStr (env, path @ [name]) of
                         SOME e => plus (delta, e)
                       | NONE => err (sp, "unbound structure: " ^ longidToString (path, name))) Env.empty ids
    | DInfix _ => Env.empty
    | DInfixr _ => Env.empty
    | DNonfix _ => Env.empty
    | DOverload {kind, strid, literal, span = sp} =>
        (* Register <strid>.<kind> as an overloading type whose operators are
           the values of the structure. A structure that only renames a
           registered type (structure Int64 = Int) needs no registration. *)
        let
          val () = if !allowPrim then () else err (sp, "_overload is only allowed when compiling with --allow-prim")
          val name = String.concatWith "." strid
          val () = if List.exists (fn k => k = kind) ["int", "word", "real", "char", "string"] then ()
                   else err (sp, "_overload: unknown kind " ^ kind)
          val str = case Env.findStr (env, strid) of
                      SOME e => e
                    | NONE => err (sp, "unbound structure: " ^ name)
          val tycon = case Env.findTy (str, ([], kind)) of
                        SOME tystr =>
                          (case Env.tyStrName tystr of
                             SOME c => c
                           | NONE => err (sp, "_overload: " ^ name ^ "." ^ kind ^ " is not a type name"))
                      | NONE => err (sp, "_overload: structure " ^ name ^ " has no type " ^ kind)
          fun global what longid =
            case Env.findVal (env, longid) of
              SOME (Val {stamp, global = true, ...}) => stamp
            | _ => err (sp, "_overload: " ^ what ^ " is not a top-level value")
          fun operator opname = (opname, Overload.Global (global (name ^ "." ^ opname) (strid, opname)))
          val lit = case literal of
                      OvBits n => Overload.Bits n
                    | OvVia (path, f) => Overload.Via (global (String.concatWith "." (path @ [f])) (path, f))
        in
          case Overload.kindOf tycon of
            SOME _ => ()
          | NONE => Overload.register (tycon, kind, List.map operator (Overload.operators kind), lit);
          Env.empty
        end
    | DStructure (binds, _) =>
        (* all bindings of one declaration are elaborated in the same environment (rule 61) *)
        List.foldl (fn (b : strbind, delta) => bindStrAt (delta, #name b, elabStrexp (env, level, top, outerScope, #strexp b),#span b))
                   Env.empty binds
    | DSignature (binds, _) =>
        (* all bindings are elaborated in the same basis (rule 67) *)
        let val elaborated = List.map (fn (b : sigbind) => (#name b, let val sg=elabSigexp (env,#sigexp b)
          in {bound= #bound sg,env= #env sg,origin=Env.originAt ("signature",#name b,#span b)}:SigMatch.sigma end)) binds
        in
          List.app (fn (n, sg) => (sigs := StringMap.insert (!sigs, n, sg); insertedSigs := n :: !insertedSigs;
            if !Env.tracking then (case Env.primary (#origin sg) of Env.Named {span,...} =>
              Env.emit ("def-g",([],n),span,#origin sg) | _ => ()) else ())) elaborated;
          Env.empty
        end
    | DFunctor (binds, _) =>
        let
          (* --functors=functions: the body elaborated once, its
             annotations kept for its code, its declarations local to the
             function it is compiled to, which takes the parameter's
             record (functorCode) *)
          fun function (b : funbind) =
            let
              val sigma = elabSigexp (env, #paramSig b)
              val _ = specDatatypes (fn c => List.exists (fn b' => #stamp b' = #stamp c) (#bound sigma)
                                              andalso not (IntMap.member (!Ty.datatypes, #stamp c)), #env sigma)
              val pEnv = localParam (#env sigma)
              val bodyEnv = case #param b of
                              SOME x => bindStrAt (env, x, pEnv, #span b)
                            | NONE => plus (env, pEnv)
              val param = freshStamp ()
              val opens =
                List.map (fn (c, tag, scheme) =>
                            let
                              val (argTy, dataTy) = case prune scheme of
                                                      TArrow (a, r) => (a, r)
                                                    | _ => Error.bug "an open constructor of no argument"
                              val () = if tag >= Ty.flatTags then err (#span b, "--functors=functions: constructor "
                                                                                 ^ Int.toString tag ^ " of " ^ #name c
                                                                                 ^ " is past what a descriptor can build")
                                       else ()
                              val o' = {tycon = #stamp c, tag = tag, desc = freshStamp (), con = freshStamp (),
                                        decon = freshStamp (), dataTy = dataTy, argTy = argTy}
                            in
                              opened := IntMap.insert (!opened, #stamp c, o' :: getOpt (IntMap.find (!opened, #stamp c), []));
                              o'
                            end)
                         (openConstructors sigma)
              val paramRecord = case recordOf pEnv of
                                  Record {vals, strs, shared, ...} =>
                                    Record {vals = vals, descs = List.map (fn (o' : openCon) => DescVar (#desc o')) opens,
                                            strs = strs, shared = shared}
              val () = register (paramRecord, {var = param, global = false, path = []})
              val lo = !tyconCounter
              val saved = !inBody
              val () = inBody := true
              val result = ElabStats.within ElabStats.FunDecl (fn () => elabStrexp (bodyEnv, level, top, outerScope, #body b))
                           handle e => (inBody := saved; raise e)
              val () = inBody := saved
              val () = resolvePending ()
              val summary =
                if closedEnv result then
                  SOME {generated = generatedDeep (lo, result), result = placeholders result, counts = (0, 0, 0)}
                else err (#span b, "functor " ^ #name b ^ " has no signature: its result has a type variable not "
                                   ^ "generalised, which --functors=functions refuses (rule 89)")
              val func = freshStamp ()
              val resultRecord = recordOf result
              val () = Ty.bindVar (func, TArrow (recordTy paramRecord, recordTy resultRecord))
              val () = bodies := StringMap.insert (!bodies, spanKey (#span b),
                                                   {func = func, param = param, paramRecord = paramRecord, result = resultRecord,
                                                    opens = opens})
            in
              (#name b, FunInfo {param = #param b, paramSig = sigma, body = #body b, defEnv = Env.empty, origin = "",
                                 binding = Env.originAt ("functor", #name b, #span b),
                                 allowPrim = false, defSigs = StringMap.empty, defFuns = StringMap.empty,
                                 summary = summary, code = SOME func})
            end
          val elaborated =
            if !functorFunctions then
              (if !ElabStats.on then ElabStats.count ElabStats.FunDecls else (); List.map function binds)
            else
            List.map (fn (b : funbind) =>
                         let
                           val sigma = elabSigexp (env, #paramSig b)
                           val bodyEnv = case #param b of
                                           SOME x => bindStrAt (env, x, #env sigma,#span b)
                                         | NONE => plus (env, #env sigma)
                           (* the body is checked once against the parameter signature (rule 86);
                              its annotations are discarded, and what it gave is the functor's
                              summary (rule 54); each application whose code is made
                              elaborates a copy *)
                           val () = if !ElabStats.on then ElabStats.count ElabStats.FunDecls else ()
                           val lo = !tyconCounter
                           val (s0, c0, v0) = counters ()
                           val () = checking := !checking + 1
                           val result = ElabStats.within ElabStats.FunDecl (fn () => elabStrexp (bodyEnv, level, top, outerScope, #body b))
                                        handle e => (checking := !checking - 1; raise e)
                           val () = checking := !checking - 1
                           val (s1, c1, v1) = counters ()
                           val () = resolvePending ()
                           (* rule 89: no free type variable enters the basis.
                              One the body leaves free (`val r = ref []`, which
                              the value restriction does not generalise) would be
                              in the functor's signature, the same in every
                              application (rule 54), and no declaration after
                              the body can determine it: the declaration is
                              refused, as the Definition's Appendix G allows and
                              HaMLet and MLKit do. The basis's own, which a
                              declaration later in the topdec may determine, the
                              summary shares *)
                           val closed = closedEnv (result, [])
                           val shared = if closed then [] else basisTyvars ()
                           val () =
                             case if closed then NONE else bodyTyvar (result, shared) of
                               SOME (n, t) =>
                                 err (#span b, "the type of " ^ n ^ " in the result of functor " ^ #name b ^ ", " ^ toString t
                                                ^ ", contains a type variable that cannot be generalised "
                                                ^ "(a functor's result may not have free type variables)")
                             | NONE => ()
                           (* none where a flexible record is left, which the
                              topdec's end refuses (settleFlex) *)
                           val summary =
                             if closed orelse closedEnv (result, shared) then
                               SOME {generated = generatedIn (lo, result), result = placeholders result,
                                     counts = (s1 - s0, c1 - c0, v1 - v0)}
                             else NONE
                           val sigsNow = !sigs
                           val funsNow = !funs
                         in
                           (#name b, FunInfo {param = #param b, paramSig = sigma, body = #body b, defEnv = env, origin = "",binding=Env.originAt ("functor",#name b,#span b),
                                              allowPrim = !allowPrim, defSigs = sigsNow, defFuns = funsNow,
                                              summary = summary, code = NONE})
                         end) binds
        in
          List.app (fn (n, f as FunInfo {binding,...}) => (funs := StringMap.insert (!funs, n, f); insertedFuns := n :: !insertedFuns;
            if !Env.tracking then (case Env.primary binding of Env.Named {span,...} =>
              Env.emit ("def-f",([],n),span,binding) | _ => ()) else ())) elaborated;
          Env.empty
        end

  (* RuneDynamic.load, .take or .export, which a dynamic module's boundary calls *)
  and dynamicVia (env, name, sp) : int =
    case findVal (env, (["RuneDynamic"], name)) of
      SOME (Val {stamp, ...}) => stamp
    | _ => err (sp, "a dynamic module needs RuneDynamic." ^ name ^ " of the Basis Library")

  (* ------------------------------------------------------------------ *)
  (* Structure expressions.                                               *)
  and elabStrexp (env, level, top, scope : scope, se : strexp) : env =
    case se of
      StrStruct (decs, _) => elabDecs (env, level, top, scope, decs)
    | StrId ((path, sname), sp) =>
        ((Env.noteUse (env,"s",(path,sname),sp);case findStr (env, path @ [sname]) of
           SOME e => e
         | NONE => err (sp, "unbound structure: " ^ longidToString (path, sname))))
    | StrAscribe (se, sigexp, opaque, sp) =>
        let
          val e = elabStrexp (env, level, top, scope, se)
          val sigma = elabSigexp (env, sigexp)
        in ElabStats.during ElabStats.Match (fn () => SigMatch.ascribe (sigma, e, opaque, sp)) end
    | StrApp (funid, arg, slot, sp) =>
        (Usage.use ("fun", funid);
         case StringMap.find (!funs, funid) of
           NONE => err (sp, "unbound functor: " ^ funid)
         | SOME (FunInfo {param, paramSig, body, defEnv, allowPrim = ap, defSigs, defFuns, summary, origin,binding,code}) =>
             let val ()=if !Env.tracking then Env.emit ("f",([],funid),sp,binding) else ()
               (* rule 54: match the argument, then type the application by
                  the functor's signature *)
               val argEnv = elabStrexp (env, level, top, scope, arg)
               (* only checked (inside a functor's declaration): the summary
                  realised, the parameter's names by the argument's types and
                  the names the body made by fresh ones *)
               fun typed ({generated, result, counts} : summary) =
                 let
                   val (phi, _) = ElabStats.during ElabStats.Match (fn () => SigMatch.match (paramSig, argEnv, sp))
                   val start = counters ()
                   val phi = List.foldl (fn (c, m) => IntMap.insert (m, #stamp c, TName (freshTycon (#name c, #arity c, #eq c))))
                                        phi generated
                   val r = freshExceptions (realizeEnv (phi, result))
                 in replay (start, counts); r end
               (* a copy of the body specialised to the argument, in the
                  basis of the functor's definition, for the application's
                  code; its types the signature's where a summary gives them *)
               fun copied () =
                 let
                   (* the code made of the copy is the body's, of the unit it is
                      from, which this one depends on as such: "fun F" holds by
                      the signature alone, and F may be another functor here *)
                   val () = if !checking = 0 andalso origin <> "" then Usage.use ("funat", origin) else ()
                   val (phi, specE) = ElabStats.during ElabStats.Match (fn () => SigMatch.match (paramSig, argEnv, sp))
                   val thinned = SigMatch.mergeInfo (specE, argEnv)
                   val bodyEnv = case param of
                                   SOME x => (case Env.primary binding of Env.Named {span,...} =>
                                     let val savedUnit= !Env.currentUnit
                                         val ()=Env.currentUnit:=(case Env.primary binding of Env.Named {unit,...} => unit | _ => savedUnit)
                                         val result=bindStrAt (defEnv,x,thinned,span)
                                     in Env.currentUnit:=savedUnit;result end
                                   | _ => bindStr (defEnv,x,thinned))
                                 | NONE => plus (defEnv, thinned)
                   val copy = ElabStats.during ElabStats.Copy (fn () => copyStrexp body)
                   val saved = (!allowPrim, !reportMatches, !sigs, !funs, !Env.currentUnit, !Env.applicationDepth)
                   fun restore () =
                     (allowPrim := #1 saved; reportMatches := #2 saved; sigs := #3 saved; funs := #4 saved;Env.currentUnit:= #5 saved;Env.applicationDepth:= #6 saved)
                   val () = (allowPrim := ap; reportMatches := false; sigs := defSigs; funs := defFuns;
                     Env.applicationDepth:= !Env.applicationDepth+1;
                     case Env.primary binding of Env.Named {unit,...} => Env.currentUnit:=unit | _ => ())
                   val result =
                     elabStrexp (bodyEnv, level, top, scope, copy)
                     handle Error.CompileError (sp', msg) =>
                       (restore ();
                        raise Error.CompileError (sp', "in the application of functor " ^ funid ^ " at "
                                                       ^ Source.describe sp ^ ": " ^ msg))
                   val () = restore ()
                   val result =
                     case summary of
                       NONE => result
                     | SOME s =>
                         (case signatureTyped (s, phi, result, "functor " ^ funid ^ " at " ^ Source.describe sp) of
                            SOME r => r
                          | NONE =>
                              if !lintSummaries then Error.bug ("the copy of functor " ^ funid ^ " at " ^ Source.describe sp
                                                                ^ " disagrees with its summary")
                              else result)
                 in slot := SOME copy; result end
               (* --functors=functions: typed by the summary alone, the
                  names it made fresh, its values and exceptions fresh
                  variables, which the call's result sets (callCode) *)
               fun call () =
                 let
                   val func = case code of
                                SOME f => f
                              | NONE => err (sp, "functor " ^ funid ^ " is not compiled to a function (--functors=functions)")
                   val {generated, result, ...} =
                     case summary of
                       SOME s => s
                     | NONE => err (sp, "functor " ^ funid ^ " has no signature (--functors=functions)")
                   val (phi, specE) = ElabStats.during ElabStats.Match (fn () => SigMatch.match (paramSig, argEnv, sp))
                   val thinned = SigMatch.mergeInfo (specE, argEnv)
                   val descs = descriptors (paramSig, phi, sp)
                   val fresh = List.map (fn c => (c, freshTycon (#name c, #arity c, #eq c))) generated
                   val phi = List.foldl (fn ((c, c'), m) => IntMap.insert (m, #stamp c, TName c')) phi fresh
                   val () = List.app (fn (c, c') => instance (phi, c, c')) fresh
                   val g = globalAt top
                   val res = freshSlots (g, realizeEnv (phi, result))
                   val r = freshStamp ()
                   val record = recordOf res
                   val () = Ty.bindVar (r, recordTy record)
                   val arg = argRecordWith (thinned, descs)
                   val () = register (record, {var = r, global = g, path = []})
                 in
                   calls := StringMap.insert (!calls, spanKey sp, {func = func, arg = arg, result = r, global = g, record = record});
                   res
                 end
               (* --pass-stats=elab: the match, the copy and its elaboration
                  are the application's *)
               fun apply () =
                 case (!checking > 0 orelse not (!makesCode), summary) of
                   (true, SOME s) => typed s
                 | _ => copied ()
             in ElabStats.application (!makesCode) (if !functorFunctions then call else apply) end)
    | StrLet (decs, body, _) =>
        let val delta = elabDecs (env, level, top, scope, decs)
        in elabStrexp (plus (env, delta), level, top, scope, body) end
    | StrDynamic (from, sigexp, slot, sp) =>
        (* a structure the program loads when it runs (D18): an instance
           of the signature with nothing behind it -- fresh abstract types,
           as an opaque ascription gives -- and a fresh global per value
           and exception, its slot, set from what the module exports *)
        let
          (* a loaded unit names the program's units by their identities;
             a virtual module's implementation is part of the program *)
          val () = if !inBody then err (sp, "a dynamic module in a functor's body is not supported under --functors=functions")
                   else ()
          val () = case from of
                     DynamicFile _ => if isSome (!dynamicAt) then () else dynamicAt := SOME sp
                   | DynamicVirtual _ => ()
          val sigma = elabSigexp (env, sigexp)
          (* the signature's names made fresh (rule 65), and each datatype it
             specifies given its constructors under its fresh name -- from the
             specification's constructors, their schemes and tags -- which no
             structure's datatype realises here *)
          val fresh = List.map (fn c => (c, freshTycon (#name c, #arity c, #eq c))) (#bound sigma)
          val phi = List.foldl (fn ((c, c'), m) => IntMap.insert (m, #stamp c, TName c')) IntMap.empty fresh
          val inst = realizeEnv (phi, #env sigma)
          val specified = specDatatypes (fn c => List.exists (fn (_, c') => #stamp c' = #stamp c) fresh, inst)
          val via = dynamicVia (env, case from of DynamicFile _ => "load" | DynamicVirtual _ => "take", sp)
          val slots : (int * ty * bool) list ref = ref []
          fun restamp (Env {vals, tys, strs,origins}) : env =
            let
              fun slotOf v =
                case v of
                  Val {scheme, ...} =>
                    let val s = freshStamp ()
                    in Ty.bindVar (s, scheme); slots := (s, scheme, false) :: !slots;
                       Val {scheme = scheme, stamp = s, global = true}
                    end
                | Exn {ty = t, info} =>
                    let
                      val s = freshStamp ()
                      val arg = case prune t of TArrow (a, _) => SOME a | _ => NONE
                    in
                      Ty.bindExn (s, arg); slots := (s, t, true) :: !slots;
                      Exn {ty = t, info = {name = #name info, stamp = s, isGlobal = true, hasArg = #hasArg info, builtin = NONE}}
                    end
                | other => other
              val vals' = List.foldl (fn ((n, v), m) => StringMap.insert (m, n, slotOf v)) StringMap.empty
                                     (StringMap.listItemsi vals)
              val strs' = List.foldl (fn ((n, e), m) => StringMap.insert (m, n, restamp e)) StringMap.empty
                                     (StringMap.listItemsi strs)
            in Env {vals = vals', tys = tys, strs = strs',origins=origins} end
          val e = restamp inst
          val slots = List.rev (!slots)
          val temp = freshStamp ()
          val () = Ty.bindVar (temp, tupleTy (List.tabulate (Int.max (List.length slots, 2), fn _ => unitTy)))
          (* a module may be loaded again (Dynamic.reload) where the
             signature has no abstract type: a value the program holds of
             one could be of another representation in the new module *)
          val reloadable = List.all (fn (_, c') => List.exists (fn s => s = #stamp c') specified) fresh
        in
          slot := SOME {fingerprint = !sigFingerprint sigma, slots = slots, via = via, temp = temp, reloadable = reloadable};
          e
        end
    | StrExport (_, sigexp, body, slot, sp) =>
        (* a dynamic module's implementation (D17): its body elaborated with
           the signature's order of each datatype's constructors, ascribed
           to the signature opaquely, and its values and exceptions, in the
           ABI's order, what it exports *)
        let
          val sigma = elabSigexp (env, sigexp)
          fun orders (Env {tys, strs, ...}, m) =
            StringMap.foldli (fn (_, e, m) => orders (e, m))
                             (StringMap.foldli (fn (n, TyStr {cons = cs as _ :: _, ...}, m) =>
                                                   StringMap.insert (m, n, List.map #1 (List.foldl (fn (c, acc) =>
                                                     let fun tagOf (_, Con {info, ...}) = #tag info | tagOf _ = 0
                                                         fun ins [] = [c] | ins (d :: rest) = if tagOf c < tagOf d then c :: d :: rest else d :: ins rest
                                                     in ins acc end) [] cs))
                                               | (_, _, m) => m) m tys)
                             strs
          val saved = !exportTags
          val () = exportTags := orders (#env sigma, StringMap.empty)
          val e = elabStrexp (env, level, top, scope, body) handle x => (exportTags := saved; raise x)
          val () = exportTags := saved
          val ascribed = ElabStats.during ElabStats.Match (fn () => SigMatch.ascribe (sigma, e, true, sp))
          val via = dynamicVia (env, "export", sp)
          val slots : (int * ty * bool) list ref = ref []
          fun collect (Env {vals, strs, ...}) =
            (List.app (fn (n, v) =>
                         case v of
                           Val {stamp, scheme, ...} => slots := (stamp, scheme, false) :: !slots
                         | Exn {ty = t, info} => slots := (#stamp info, t, true) :: !slots
                         | ConAsVal _ => err (sp, "_export: a constructor given as the value " ^ n ^ " is not supported")
                         | ExnAsVal _ => err (sp, "_export: an exception given as the value " ^ n ^ " is not supported")
                         | _ => ())
                      (StringMap.listItemsi vals);
             List.app (fn (_, e) => collect e) (StringMap.listItemsi strs))
          val () = collect ascribed
        in
          slot := SOME {fingerprint = !sigFingerprint sigma, slots = List.rev (!slots), via = via, temp = 0, reloadable = false};
          ascribed
        end

  (* ------------------------------------------------------------------ *)
  (* Signature expressions and specifications (rules 62-84).             *)
  and elabSigexp (env, se : sigexp) : SigMatch.sigma =
    case se of
      SigId (n, sp) =>
        (Usage.use ("sig", n);
         case StringMap.find (!sigs, n) of
           SOME sg => (if !Env.tracking then Env.emit ("g",([],n),sp,#origin sg) else ();
             ElabStats.during ElabStats.Inst (fn () => SigMatch.instantiate sg))
         | NONE => err (sp, "unbound signature: " ^ n))
    | SigSig (specs, sp) => elabSpecs (env, specs)
    | SigWhere _ =>
        (* the clauses of a chain of where's, the innermost first, realised
           at once (SigMatch.whereStep) *)
        let
          fun chain (SigWhere (se, clauses, _), acc) = chain (se, clauses @ acc)
            | chain (se, acc) = (se, acc)
          val (base, clauses) = chain (se, [])
          val sigma = elabSigexp (env, base)
          fun clause ((tvs, longid, ty, csp), phi) =
            let
              val params = List.map paramVar tvs
              val scope = ref (StringMap.fromList (ListPair.zip (tvs, List.map #2 params)))
              val body = elabTy (env, scope, 0, ty)
            in SigMatch.whereStep (sigma, phi, longid, TAbbrev (List.map #1 params, body), csp) end
        in
          ElabStats.during ElabStats.Where (fn () => SigMatch.whereFinish (sigma, List.foldl clause IntMap.empty clauses))
        end

  and elabSpecs (env, specs : spec list) : SigMatch.sigma =
    let
      (* rule 77: later specifications see the earlier ones, in env plus the
         signature so far, which each specification extends by what it
         specifies (which names nothing the signature has) and a run of
         sharing realises *)
      val current = ref env
      fun add (sigma : SigMatch.sigma, bound', delta, sp) : SigMatch.sigma =
        let val sigma' = {bound = #bound sigma @ bound', env = plusDisjoint (#env sigma, delta, sp),origin= #origin sigma}
        in current := plus (!current, delta); sigma' end
      fun cur (_ : SigMatch.sigma) = !current
      fun one (spec, sigma) =
        case spec of
          SpecVal (descs, _) =>
            List.foldl (fn ((n, ty, dsp), sigma) =>
                           let
                             val () = checkBindable (n, dsp, true)
                             val scope = specScope (ty, 1)
                             val t = elabTy (cur sigma, scope, 1, ty)
                             val () = Unify.generalize (0, t)              (* rule 79: implicitly closed *)
                           in add (sigma, [], bindValAt (Env.empty, n, Val {scheme = t, stamp = freshStamp (), global = true},dsp), dsp) end)
                       sigma descs
        | SpecType (descs, _) =>
            List.foldl (fn ((tvs, n, dsp), sigma) =>
                           let val tc = freshTycon (n, List.length tvs, false)
                           in add (sigma, [tc], bindTyAt (Env.empty, n, TyStr {fcn = TName tc, cons = []},dsp), dsp) end)
                       sigma descs
        | SpecEqtype (descs, _) =>
            List.foldl (fn ((tvs, n, dsp), sigma) =>
                           let val tc = freshTycon (n, List.length tvs, true)
                           in add (sigma, [tc], bindTyAt (Env.empty, n, TyStr {fcn = TName tc, cons = []},dsp), dsp) end)
                       sigma descs
        | SpecDatatype (dbs, sp) =>
            let
              val delta = elabDec (cur sigma, 0, true, ref StringMap.empty, DDatatype (dbs, [], sp))
              val names = StringMap.foldri (fn (_, TyStr {fcn = TName c, ...}, acc) => c :: acc | (_, _, acc) => acc) [] (tys delta)
            in add (sigma, names, delta, sp) end
        | SpecDatatypeRepl (n, longid, sp) =>
            add (sigma, [], elabDec (cur sigma, 0, true, ref StringMap.empty, DDatatypeRepl (n, longid, sp)), sp)
        | SpecException (descs, _) =>
            List.foldl (fn ((n, tyopt, dsp), sigma) =>
                           let
                             val () = checkBindable (n, dsp, false)
                             val scope = ref StringMap.empty
                             val ty = case tyopt of
                                        NONE => exnTy
                                      | SOME t => TArrow (elabTy (cur sigma, scope, 0, t), exnTy)
                             val info = {name = n, stamp = freshStamp (), isGlobal = true, hasArg = isSome tyopt, builtin = NONE}
                           in add (sigma, [], bindValAt (Env.empty, n, Exn {ty = ty, info = info},dsp), dsp) end)
                       sigma descs
        | SpecStructure (descs, _) =>
            (* all descriptions of one specification are elaborated in the same basis (rule 84) *)
            let val elaborated = List.map (fn (n, sg, dsp) => (n, elabSigexp (cur sigma, sg), dsp)) descs
            in
              List.foldl (fn ((n, sg : SigMatch.sigma, dsp), sigma) =>
                             add (sigma, #bound sg, bindStrAt (Env.empty, n, #env sg,dsp), dsp)) sigma elaborated
            end
        | SpecInclude (sg, sp) =>
            let val sg' = elabSigexp (cur sigma, sg)
            in add (sigma, #bound sg', #env sg', sp) end
        | SpecSharingType _ => Error.bug "elabSpecs: sharing outside a run"
        | SpecSharing _ => Error.bug "elabSpecs: sharing outside a run"
      fun equation (SpecSharingType (ids, sp)) = SOME (SigMatch.ShareTypes (ids, sp))
        | equation (SpecSharing (ids, sp)) = SOME (SigMatch.ShareStructures (ids, sp))
        | equation _ = NONE
      (* a run of sharing specifications, realised at once (SigMatch.shareRun) *)
      fun run (acc, rest) =
        case rest of
          spec :: more => (case equation spec of SOME e => run (e :: acc, more) | NONE => (List.rev acc, rest))
        | [] => (List.rev acc, rest)
      fun loop (sigma, []) = sigma
        | loop (sigma, spec :: rest) =
          case equation spec of
            NONE => loop (one (spec, sigma), rest)
          | SOME e =>
              let
                val (eqns, rest') = run ([e], rest)
                val sigma' = ElabStats.during ElabStats.Share (fn () => SigMatch.shareRun (sigma, eqns))
              in current := plus (env, #env sigma'); loop (sigma', rest') end
    in
      ElabStats.during ElabStats.Specs (fn () => loop ({bound = [], env = Env.empty,origin=Env.Unknown}, specs))
    end

  (* ------------------------------------------------------------------ *)
  (* Elaborate top-level declarations, extending env in place. *)
  (* Rules 87-89: a top-level declaration may not leave free type variables
     in the basis, e.g. val r = ref nil. *)
  fun freeTyvar (t : ty) : ty option =
    case prune t of
      t as TVar (ref (Unbound {level, kind, ...})) =>
        (case kind of KFlex _ => NONE | _ => if level = genericLevel then NONE else SOME t)
    | TVar _ => NONE
    | TCon (_, args) => List.foldl (fn (a, NONE) => freeTyvar a | (_, r) => r) NONE args
    | TRecord fields => List.foldl (fn ((_, a), NONE) => freeTyvar a | (_, r) => r) NONE fields
    | TArrow (a, b) => (case freeTyvar a of NONE => freeTyvar b | r => r)

  fun checkClosed (delta : env, sp) : unit =
    (StringMap.appi (fn (n, v) =>
                        let val scheme = case v of Val {scheme, ...} => scheme | _ => unitTy
                        in
                          case freeTyvar scheme of
                            NONE => ()
                          | SOME _ =>
                              err (sp, "the type of " ^ n ^ ", " ^ toString scheme
                                       ^ ", contains a type variable that cannot be generalised "
                                       ^ "(a top-level declaration may not have free type variables)")
                        end) (vals delta);
     StringMap.app (fn e => checkClosed (e, sp)) (strs delta))

  (* What a top-level declaration may change of the elaborator's state
     besides the environment it extends, which elabTop changes only once
     the declaration has elaborated: put back after a declaration that
     fails, so that the next is elaborated as if it had not been there
     (recover; docs/units.md, Errors). The tables that are keyed by stamps
     (Ty.binders and the like) only grow, and no stamp is made twice, so
     what a failed declaration put in them names nothing after it. *)

  type snapshot = {sigs : SigMatch.sigma StringMap.map, funs : funinfo StringMap.map,
                   datatypes : Ty.datatypeInfo IntMap.map, overloads : Overload.entry IntMap.map,
                   dataCons : (string * valstatus) list IntMap.map,
                   pendingFlex : (tvar ref * span) list, pendingChecks : (unit -> unit) list,
                   pendingClosed : (env * span) list}
  fun snapshot () : snapshot =
    {sigs = !sigs, funs = !funs, datatypes = !Ty.datatypes, overloads = !Overload.table, dataCons = !dataCons,
     pendingFlex = !pendingFlex, pendingChecks = !pendingChecks, pendingClosed = !pendingClosed}
  (* also the declarations whose free variables wait for the topdec's end:
     the one that failed is not checked again at each end after it *)
  fun restore ({sigs = s, funs = f, datatypes = d, overloads = ov, dataCons = dc, pendingFlex = pf, pendingChecks = pc,
                pendingClosed = pcl} : snapshot) =
    (sigs := s; funs := f; Ty.datatypes := d; Ty.extras := Ty.Unknown; Overload.table := ov; dataCons := dc;
     pendingOverloads := []; pendingLiterals := []; pendingFlex := pf; pendingChecks := pc; pendingClosed := pcl)

  (* Whether a top-level declaration that fails to elaborate is reported
     (Error.report), undone and skipped, and the next one elaborated, so
     that a compile reports every independent error before it fails; the
     driver turns it on for the program, and the REPL will. *)
  val recover = ref false
  val () = CompilerState.cellRoot ("Elaborate.recover", recover)

  (* What the last elabTop added to the environment, its declarations' in
     one: what the REPL echoes of a declaration (src/repl/session.sml). *)
  val lastDelta : env ref = ref Env.empty
  val () = CompilerState.cellRoot ("Elaborate.lastDelta", lastDelta)

  (* --pass-stats=elab: the line of a top-level declaration elaborated *)
  fun stats (d : dec) : unit =
    let
      val (kind, name) =
        case d of
          DSignature ({name, ...} :: _, _) => ("signature", name)
        | DFunctor ({name, ...} :: _, _) => ("functor", name)
        | DStructure ({name, ...} :: _, _) => ("structure", name)
        | _ => ("core", "")
    in ElabStats.emit (Source.describe (spanOfDec d), kind, name, !Types.workLimit - !Types.workLeft) end

  fun elabTop (env : env ref, decs : dec list) : unit =
    let val scopeEnd=ref 0
    in (lastDelta := Env.empty;
     (* a type of a message is named as the top level names it *)
     Types.qualifier := (fn c => Env.qualifiedName (!env, c));
     List.app (fn d =>
                let
                  val span=spanOfDec d
                  val ()=Env.noteScope ({file= #file span,start= !scopeEnd,stop= #stop span},!env)
                  val ()=scopeEnd:= #stop span
                  val saved = if !recover then SOME (snapshot ()) else NONE
                  val () = ElabStats.reset ()
                  fun go () =
                    let
                      val () = inReach := StringMap.empty
                      val () = Types.startWork (spanOfDec d)
                      val () = Unify.flexHook := (fn r => pendingFlex := (r, spanOfDec d) :: !pendingFlex)
                      val delta = elabDec (!env, 0, true, ref StringMap.empty, d)
                      (* the modes that settle flexible records where a
                         top-level declaration ends check rules 87-89 there
                         too, as the Definition does: a variable a later
                         declaration of the same topdec determines is not
                         free (a flexible record not generalised under
                         topdec-monomorphic, or val r = ref nil) *)
                      val byTopdec = case !flexRecords of FlexDeclaration => false | FlexProgram => false | _ => true
                    in resolvePending ();
                       if byTopdec then pendingClosed := (delta, spanOfDec d) :: !pendingClosed
                       else checkClosed (delta, spanOfDec d);
                       env := plus (!env, delta);
                       lastDelta := plus (!lastDelta, delta);
                       if byTopdec andalso Parser.endsTopdec (spanOfDec d) then
                         (settleFlex ();
                          List.app checkClosed (List.rev (!pendingClosed));
                          pendingClosed := [])
                       else ();
                       if !ElabStats.on then stats d else ();
                       Types.stopWork () end
                in
                  case saved of
                    NONE => go ()
                  | SOME s =>
                      go () handle Error.CompileError e =>
                        (Types.stopWork (); restore s;
                         (* a failure where the topdec ends came from its checks, all made *)
                         if Parser.endsTopdec (spanOfDec d) then pendingClosed := [] else ();
                         Error.report e)
                end) decs;
     (* what is elaborated together ends a topdec (a file, a REPL's unit) *)
     List.app checkClosed (List.rev (!pendingClosed));
     pendingClosed := []) end

  fun elabProgram (decs : dec list) : env =
    let val env = ref Env.initial
    in elabTop (env, decs); finish (); !env end
end
