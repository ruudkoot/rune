(* Implements: HS_DUMP *)
structure HsDump :> HS_DUMP =
struct
  structure A = HsAst

  val spans = ref false
  val out : string list ref = ref []
  val depth = ref 0

  fun spanText ({span = {start, stop, file}, ...} : A.ann) =
    if !spans andalso file <> "" then " @" ^ Int.toString start ^ "-" ^ Int.toString stop else ""

  (* a node's line, and the nodes below it *)
  fun line (a : A.ann, text : string, below : unit -> unit) =
    (out := "\n" :: spanText a :: text :: CharVector.tabulate (2 * !depth, fn _ => #" ") :: !out;
     depth := !depth + 1;
     below ();
     depth := !depth - 1)

  fun leafLine (a, text) = line (a, text, fn () => ())
  fun group (label, f, xs) = line (A.noAnn, label, fn () => List.app f xs)
  fun opt (label, f, x) = case x of NONE => () | SOME y => line (A.noAnn, label, fn () => f y)

  fun nameText (A.Name (_, q)) = A.nameText q
  fun name label (n as A.Name (a, _)) = leafLine (a, label ^ " " ^ nameText n)

  fun litText l =
    case l of
      A.LInt (_, s) => "LInt " ^ s
    | A.LFloat s => "LFloat " ^ s
    | A.LChar (_, s) => "LChar " ^ s
    | A.LString (_, s) => "LString " ^ s

  fun lit (A.Lit (a, l)) = leafLine (a, litText l)

  fun qop (A.VarOp n) = name "VarOp" n
    | qop (A.ConOp n) = name "ConOp" n

  fun ty (A.T (a, x)) =
    case x of
      A.TVar v => leafLine (a, "TVar " ^ nameText v)
    | A.TCon c => leafLine (a, "TCon " ^ nameText c)
    | A.TApp (f, b) => line (a, "TApp", fn () => (ty f; ty b))
    | A.TFun (f, b) => line (a, "TFun", fn () => (ty f; ty b))
    | A.TList t => line (a, "TList", fn () => ty t)
    | A.TTuple ts => line (a, "TTuple", fn () => List.app ty ts)
    | A.TParen t => line (a, "TParen", fn () => ty t)

  fun context c = opt ("context", ty, c)

  fun pat (A.P (a, x)) =
    case x of
      A.PVar v => leafLine (a, "PVar " ^ nameText v)
    | A.PWild => leafLine (a, "PWild")
    | A.PLit l => line (a, "PLit", fn () => lit l)
    | A.PNegLit l => line (a, "PNegLit", fn () => lit l)
    | A.PCon (c, ps) => line (a, "PCon " ^ nameText c, fn () => List.app pat ps)
    | A.PRec (c, fs) => line (a, "PRec " ^ nameText c, fn () => List.app (fn (f, p) => line (A.noAnn, "field " ^ nameText f, fn () => pat p)) fs)
    | A.PTuple ps => line (a, "PTuple", fn () => List.app pat ps)
    | A.PList ps => line (a, "PList", fn () => List.app pat ps)
    | A.PParen p => line (a, "PParen", fn () => pat p)
    | A.PAs (v, p) => line (a, "PAs " ^ nameText v, fn () => pat p)
    | A.PLazy p => line (a, "PLazy", fn () => pat p)
    | A.PNPlusK (v, k) => line (a, "PNPlusK " ^ nameText v, fn () => lit k)
    | A.PSeq items => line (a, "PSeq", fn () => List.app (fn A.PA p => pat p | A.PO q => qop q) items)
    | A.PJux ps => line (a, "PJux", fn () => List.app pat ps)

  fun exp (A.E (a, x)) =
    case x of
      A.EVar v => leafLine (a, "EVar " ^ nameText v)
    | A.ECon c => leafLine (a, "ECon " ^ nameText c)
    | A.ELit l => line (a, "ELit", fn () => lit l)
    | A.EApp (f, b) => line (a, "EApp", fn () => (exp f; exp b))
    | A.ESeq items =>
        line (a, "ESeq", fn () => List.app (fn A.EA e => exp e | A.EO q => qop q | A.ENeg => leafLine (A.noAnn, "ENeg")) items)
    | A.ELam (ps, b) => line (a, "ELam", fn () => (group ("patterns", pat, ps); exp b))
    | A.ELet (ds, b) => line (a, "ELet", fn () => (group ("decls", decl, ds); exp b))
    | A.EIf (c, t, e) => line (a, "EIf", fn () => (exp c; exp t; exp e))
    | A.ECase (e, alts) => line (a, "ECase", fn () => (exp e; List.app alt alts))
    | A.EDo ss => line (a, "EDo", fn () => List.app stmt ss)
    | A.ETuple es => line (a, "ETuple", fn () => List.app exp es)
    | A.EParen e => line (a, "EParen", fn () => exp e)
    | A.EList es => line (a, "EList", fn () => List.app exp es)
    | A.EEnum (f, t, u) =>
        line (a, "EEnum", fn () => (exp f; opt ("then", exp, t); opt ("to", exp, u)))
    | A.EComp (e, qs) => line (a, "EComp", fn () => (exp e; List.app stmt qs))
    | A.ELeftSec (e, q) => line (a, "ELeftSec", fn () => (exp e; qop q))
    | A.ERightSec (q, e) => line (a, "ERightSec", fn () => (qop q; exp e))
    | A.ERecCon (c, fs) => line (a, "ERecCon " ^ nameText c, fn () => fields fs)
    | A.ERecUpd (e, fs) => line (a, "ERecUpd", fn () => (exp e; fields fs))
    | A.ESig (e, c, t) => line (a, "ESig", fn () => (exp e; context c; ty t))

  and fields fs = List.app (fn (f, e) => line (A.noAnn, "field " ^ nameText f, fn () => exp e)) fs

  and stmt (A.S (a, x)) =
    case x of
      A.SBind (p, e) => line (a, "SBind", fn () => (pat p; exp e))
    | A.SLet ds => line (a, "SLet", fn () => List.app decl ds)
    | A.SExp e => line (a, "SExp", fn () => exp e)

  and alt (A.Alt (a, p, r)) = line (a, "Alt", fn () => (pat p; rhs r))

  and rhs (A.Rhs (a, x)) =
    case x of
      A.Plain (e, w) => line (a, "Plain", fn () => (exp e; opt ("where", fn ds => List.app decl ds, w)))
    | A.Guarded (gs, w) =>
        line (a, "Guarded", fn () =>
          (List.app (fn A.Guard (ga, g, e) => line (ga, "Guard", fn () => (exp g; exp e))) gs;
           opt ("where", fn ds => List.app decl ds, w)))

  and funlhs (A.F (a, x)) =
    case x of
      A.FPrefix (f, ps) => line (a, "FPrefix " ^ nameText f, fn () => List.app pat ps)
    | A.FInfix (l, q, r) => line (a, "FInfix", fn () => (pat l; qop q; pat r))
    | A.FParen (l, ps) => line (a, "FParen", fn () => (funlhs l; List.app pat ps))

  and strict (b, t) = if b then line (A.noAnn, "strict", fn () => ty t) else ty t

  and constr (A.C (a, x)) =
    case x of
      A.CPlain (c, args) => line (a, "CPlain " ^ nameText c, fn () => List.app strict args)
    | A.CInfix (l, c, r) => line (a, "CInfix " ^ nameText c, fn () => (strict l; strict r))
    | A.CRec (c, fs) =>
        line (a, "CRec " ^ nameText c, fn () =>
          List.app (fn A.Field (fa, vs, b, t) =>
                      line (fa, "Field " ^ String.concatWith " " (List.map nameText vs), fn () => strict (b, t))) fs)

  and deriving NONE = ()
    | deriving (SOME (A.Deriv (a, paren, cs))) =
        leafLine (a, "Deriv" ^ (if paren then " (" else " ") ^ String.concatWith " " (List.map nameText cs) ^ (if paren then ")" else ""))

  and simple (c, vs) = String.concatWith " " (List.map nameText (c :: vs))

  and decl (A.D (a, x)) =
    case x of
      A.DSig (vs, c, t) => line (a, "DSig " ^ String.concatWith " " (List.map nameText vs), fn () => (context c; ty t))
    | A.DFixity (f, p, ops) =>
        line (a, (case f of A.Infix => "DFixity infix" | A.Infixl => "DFixity infixl" | A.Infixr => "DFixity infixr"),
              fn () => (opt ("precedence", lit, p); List.app qop ops))
    | A.DFun (l, r) => line (a, "DFun", fn () => (funlhs l; rhs r))
    | A.DPat (p, r) => line (a, "DPat", fn () => (pat p; rhs r))
    | A.DType (c, vs, t) => line (a, "DType " ^ simple (c, vs), fn () => ty t)
    | A.DData (cx, c, vs, cs, d) =>
        line (a, "DData " ^ simple (c, vs), fn () => (context cx; List.app constr cs; deriving d))
    | A.DNewtype (cx, c, vs, k, d) =>
        line (a, "DNewtype " ^ simple (c, vs), fn () => (context cx; constr k; deriving d))
    | A.DClass (cx, c, v, b) =>
        line (a, "DClass " ^ simple (c, [v]), fn () => (context cx; opt ("where", fn ds => List.app decl ds, b)))
    | A.DInstance (cx, c, t, b) =>
        line (a, "DInstance " ^ nameText c, fn () => (context cx; ty t; opt ("where", fn ds => List.app decl ds, b)))
    | A.DDefault ts => line (a, "DDefault", fn () => List.app ty ts)

  fun entity (A.Ent (a, x)) =
    case x of
      A.EntVar v => leafLine (a, "EntVar " ^ nameText v)
    | A.EntType (c, NONE) => leafLine (a, "EntType " ^ nameText c)
    | A.EntType (c, SOME A.SubAll) => leafLine (a, "EntType " ^ nameText c ^ " (..)")
    | A.EntType (c, SOME (A.SubList ns)) =>
        leafLine (a, "EntType " ^ nameText c ^ " (" ^ String.concatWith ", " (List.map nameText ns) ^ ")")
    | A.EntModule m => leafLine (a, "EntModule " ^ nameText m)

  fun import (A.Import (a, {qualified, module = m, as_, hiding, spec})) =
    line (a, "Import" ^ (if qualified then " qualified " else " ") ^ nameText m ^
             (case as_ of SOME n => " as " ^ nameText n | NONE => "") ^ (if hiding then " hiding" else ""),
          fn () => opt ("entities", fn es => List.app entity es, spec))

  fun module' (A.Module (a, {name = n, exports, imports, decls})) =
    line (a, "Module" ^ (case n of SOME m => " " ^ nameText m | NONE => ""),
          fn () => (opt ("exports", fn es => List.app entity es, exports);
                    List.app import imports;
                    List.app decl decls))

  fun run (f, x, {spans = s}) =
    (spans := s; out := []; depth := 0;
     f x;
     String.concat (List.rev (!out)) before out := [])

  fun module opts m = run (module', m, opts)
  fun exp' opts e = run (exp, e, opts)
  val exp = exp'
end
