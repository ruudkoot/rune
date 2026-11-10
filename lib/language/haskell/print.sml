(* Implements: HS_PRINT *)
structure HsPrint :> HS_PRINT =
struct
  structure A = HsAst

  (* ---- the emitter ---- *)

  datatype mode = Explicit | Implicit | Exact

  (* how a token of the explicit and implicit prints stands to its
     neighbours: `Word` apart from both, `Open` joined to the one after,
     `Close` to the one before, `Prefix` to the one after, `Tight` to both *)
  datatype kind = Word | Open | Close | Prefix | Tight

  val mode = ref Explicit
  val out : string list ref = ref []
  val lineStart = ref true
  val last = ref #" "
  val lastKind = ref Word
  (* the column, less one, of the items of the block being printed *)
  val indent = ref 0
  (* in the implicit print, a block has ended and the item it was in goes
     on: on a line of its own, at this column less one *)
  val cont : int option ref = ref NONE

  (* the exact print: the file, and a frame for each node being printed
     with the tokens of its own it has yet to print *)
  val src = ref ""
  datatype frame = Frame of {owns : bool, queue : A.tok list ref}
  val frames : frame list ref = ref []

  fun raw s =
    if s = "" then () else (out := s :: !out; last := String.sub (s, size s - 1))

  fun newline k =
    (raw "\n"; raw (CharVector.tabulate (k, fn _ => #" ")); lineStart := true)

  fun isIdentChar c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'" orelse Char.ord c >= 128
  fun isSymChar c = CharVector.exists (fn d => d = c) "!#$%&*+./<=>?@\\^|-~:" orelse Char.ord c >= 128

  (* would the two characters run into one token? *)
  fun merges (p, c) = (isIdentChar p andalso isIdentChar c) orelse (isSymChar p andalso isSymChar c)

  fun emitA (s, k) =
    let
      val () = case !cont of SOME n => (cont := NONE; newline n) | NONE => ()
      val ruleSpace =
        not (!lineStart) andalso
        (case (!lastKind, k) of
           (Open, _) => false
         | (Prefix, _) => false
         | (Tight, _) => false
         | (_, Close) => false
         | (_, Tight) => false
         | _ => true)
      val hazard = not (!lineStart) andalso merges (!last, String.sub (s, 0))
    in
      if ruleSpace orelse hazard then raw " " else ();
      raw s;
      lineStart := false;
      lastKind := k
    end

  fun slice (a, b) = if b > a then raw (String.substring (!src, a, b - a)) else ()
  fun printTrivia ts = List.app (fn {start, stop, ...} : HsToken.trivium => slice (start, stop)) ts
  fun printTok ({trivia, start, stop} : A.tok) = (printTrivia trivia; slice (start, stop))

  (* the tokens of the node being printed that stand before `pos`, and
     those of layout's at it *)
  fun flushTo pos =
    case !frames of
      Frame {queue, ...} :: _ =>
        let
          fun go (t :: r) =
                if #start t < pos orelse (#start t = pos andalso #stop t = pos) then (printTok t; go r)
                else queue := t :: r
            | go [] = queue := []
        in
          go (!queue)
        end
    | [] => ()

  fun flushAll () =
    case !frames of
      Frame {queue, ...} :: _ => (List.app printTok (!queue); queue := [])
    | [] => ()

  fun hasSpan ({span = {file, ...}, ...} : A.ann) = file <> ""

  (* A node: in the exact print, its own tokens stand where the source
     had them, between its children; one with a span and no tokens of its
     own, or none, prints its tokens as the explicit print does. *)
  fun node (a : A.ann) (f : unit -> unit) =
    case !mode of
      Exact =>
        (if hasSpan a then flushTo (#start (#span a)) else ();
         frames := Frame {owns = hasSpan a andalso not (null (#toks a)), queue = ref (#toks a)} :: !frames;
         f ();
         flushAll ();
         frames := tl (!frames))
    | _ => f ()

  (* a token that the node being printed stands for *)
  fun tk (s, k) =
    case !mode of
      Exact => (case !frames of Frame {owns = true, ...} :: _ => () | _ => raw (" " ^ s))
    | _ => emitA (s, k)

  fun kw s = tk (s, Word)

  (* A leaf, a name or a literal, whose text is the tree's: in the exact
     print each token of the text after the trivia of the source's. *)
  (* Is `s` the bytes [start, stop) of the file, but that where the file
     has a literate program line's `>`, `s` has its space? A string gap
     in a literate file crosses lines. *)
  fun asWritten (s, start, stop) =
    let
      val f = !src
      fun go k =
        k >= size s orelse
        (let val c = String.sub (f, start + k) val d = String.sub (s, k)
         in (c = d orelse (c = #">" andalso d = #" " andalso start + k > 0 andalso String.sub (f, start + k - 1) = #"\n"))
            andalso go (k + 1)
         end)
    in
      stop - start = size s andalso go 0
    end

  fun leaf (a : A.ann, ts : (string * kind) list) =
    case !mode of
      Exact =>
        (if hasSpan a then flushTo (#start (#span a)) else ();
         if hasSpan a andalso length (#toks a) = length ts then
           ListPair.app
             (fn (t as {trivia, start, stop} : A.tok, (s, _)) =>
                if asWritten (s, start, stop) then printTok t else (printTrivia trivia; raw s))
             (#toks a, ts)
         else if hasSpan a andalso not (null (#toks a)) then List.app printTok (#toks a)
         else raw (" " ^ String.concat (List.map #1 ts)))
    | _ => List.app emitA ts

  fun sepBy (f, sep) xs =
    case xs of
      [] => ()
    | [x] => f x
    | x :: r => (f x; sep (); sepBy (f, sep) r)

  fun commas f xs = sepBy (f, fn () => tk (",", Close)) xs

  (* A block: in braces in the explicit print, by layout in the implicit
     one, and in the exact print as the source wrote it, which its owner
     has among its own tokens. *)
  fun block (items, pr : 'a -> unit) =
    case !mode of
      Exact => (kw "{"; sepBy (pr, fn () => kw ";") items; kw "}")
    | Explicit =>
        let val outer = !indent
        in
          kw "{";
          indent := outer + 2;
          sepBy (fn x => (newline (!indent); pr x), fn () => tk (";", Close)) items;
          indent := outer;
          newline outer;
          kw "}"
        end
    | Implicit =>
        if null items then (kw "{"; kw "}")
        else
          let val outer = !indent
          in
            indent := outer + 4;
            List.app (fn x => (cont := NONE; newline (!indent); pr x)) items;
            indent := outer;
            cont := SOME (outer + 2)
          end

  (* ---- names and literals ---- *)

  datatype form = VarForm | OpForm | PlainForm

  fun specialTexts n =
    case n of
      "()" => [("(", Open), (")", Close)]
    | "[]" => [("[", Open), ("]", Close)]
    | "(->)" => [("(", Open), ("->", Word), (")", Close)]
    | _ => ("(", Open) :: List.tabulate (size n - 2, fn _ => (",", Close)) @ [(")", Close)]

  fun texts (form, q : A.qname) =
    if A.isSpecial q then specialTexts (#name q)
    else
      let val t = A.nameText q
      in
        case form of
          VarForm => if A.isSymbolic q then [("(", Open), (t, Word), (")", Close)] else [(t, Word)]
        | OpForm => if A.isSymbolic q then [(t, Word)] else [("`", Open), (t, Word), ("`", Close)]
        | PlainForm => [(t, Word)]
      end

  fun name form (A.Name (a, q)) = leaf (a, texts (form, q))
  val var = name VarForm
  val plain = name PlainForm
  fun qop (A.VarOp n) = name OpForm n
    | qop (A.ConOp n) = name OpForm n

  fun litText l =
    case l of
      A.LInt (_, s) => s
    | A.LFloat s => s
    | A.LChar (_, s) => s
    | A.LString (_, s) => s

  fun lit (A.Lit (a, l)) = leaf (a, [(litText l, Word)])

  (* ---- types ---- *)

  fun ty (A.T (a, x)) =
    node a (fn () =>
      case x of
        A.TVar v => plain v
      | A.TCon c => plain c
      | A.TApp (f, b) => (ty f; ty b)
      | A.TFun (f, b) => (ty f; kw "->"; ty b)
      | A.TList t => (tk ("[", Open); ty t; tk ("]", Close))
      | A.TTuple ts => (tk ("(", Open); commas ty ts; tk (")", Close))
      | A.TParen t => (tk ("(", Open); ty t; tk (")", Close)))

  fun context NONE = ()
    | context (SOME c) = (ty c; kw "=>")

  (* ---- patterns ---- *)

  fun pat (A.P (a, x)) =
    node a (fn () =>
      case x of
        A.PVar v => var v
      | A.PWild => kw "_"
      | A.PLit l => lit l
      | A.PNegLit l => (kw "-"; lit l)
      | A.PCon (c, ps) => (var c; List.app pat ps)
      | A.PRec (c, fs) =>
          (var c; kw "{"; commas (fn (f, p) => (var f; kw "="; pat p)) fs; kw "}")
      | A.PTuple ps => (tk ("(", Open); commas pat ps; tk (")", Close))
      | A.PList ps => (tk ("[", Open); commas pat ps; tk ("]", Close))
      | A.PParen p => (tk ("(", Open); pat p; tk (")", Close))
      | A.PAs (v, p) => (var v; tk ("@", Tight); pat p)
      | A.PLazy p => (tk ("~", Prefix); pat p)
      | A.PNPlusK (v, k) => (var v; kw "+"; lit k)
      | A.PSeq items => List.app (fn A.PA p => pat p | A.PO q => qop q) items
      | A.PJux ps => List.app pat ps)

  (* ---- expressions and declarations ---- *)

  fun exp (A.E (a, x)) =
    node a (fn () =>
      case x of
        A.EVar v => var v
      | A.ECon c => var c
      | A.ELit l => lit l
      | A.EApp (f, b) => (exp f; exp b)
      | A.ESeq items => List.app (fn A.EA e => exp e | A.EO q => qop q | A.ENeg => kw "-") items
      | A.ELam (ps, b) => (tk ("\\", Prefix); List.app pat ps; kw "->"; exp b)
      | A.ELet (ds, b) => (kw "let"; block (ds, decl); kw "in"; exp b)
      | A.EIf (c, t, e) => (kw "if"; exp c; kw "then"; exp t; kw "else"; exp e)
      | A.ECase (e, alts) => (kw "case"; exp e; kw "of"; block (alts, alt))
      | A.EDo ss => (kw "do"; block (ss, stmt))
      | A.ETuple es => (tk ("(", Open); commas exp es; tk (")", Close))
      | A.EParen e => (tk ("(", Open); exp e; tk (")", Close))
      | A.EList es => (tk ("[", Open); commas exp es; tk ("]", Close))
      | A.EEnum (f, t, u) =>
          (tk ("[", Open); exp f;
           (case t of SOME e => (tk (",", Close); exp e) | NONE => ());
           kw "..";
           (case u of SOME e => exp e | NONE => ());
           tk ("]", Close))
      | A.EComp (e, qs) => (tk ("[", Open); exp e; kw "|"; commas stmt qs; tk ("]", Close))
      | A.ELeftSec (e, q) => (tk ("(", Open); exp e; qop q; tk (")", Close))
      | A.ERightSec (q, e) => (tk ("(", Open); qop q; exp e; tk (")", Close))
      | A.ERecCon (c, fs) => (var c; fields fs)
      | A.ERecUpd (e, fs) => (exp e; fields fs)
      | A.ESig (e, c, t) => (exp e; kw "::"; context c; ty t))

  and fields fs = (kw "{"; commas (fn (f, e) => (var f; kw "="; exp e)) fs; kw "}")

  and stmt (A.S (a, x)) =
    node a (fn () =>
      case x of
        A.SBind (p, e) => (pat p; kw "<-"; exp e)
      | A.SLet ds => (kw "let"; block (ds, decl))
      | A.SExp e => exp e)

  and alt (A.Alt (a, p, r)) = node a (fn () => (pat p; rhs "->" r))

  and rhs sep (A.Rhs (a, x)) =
    node a (fn () =>
      case x of
        A.Plain (e, w) => (kw sep; exp e; wheres w)
      | A.Guarded (gs, w) =>
          (List.app (fn A.Guard (ga, g, e) => node ga (fn () => (kw "|"; exp g; kw sep; exp e))) gs;
           wheres w))

  and wheres NONE = ()
    | wheres (SOME ds) = (kw "where"; block (ds, decl))

  and funlhs (A.F (a, x)) =
    node a (fn () =>
      case x of
        A.FPrefix (f, ps) => (var f; List.app pat ps)
      | A.FInfix (l, q, r) => (pat l; qop q; pat r)
      | A.FParen (l, ps) => (tk ("(", Open); funlhs l; tk (")", Close); List.app pat ps))

  and strict (b, t) = (if b then tk ("!", Prefix) else (); ty t)

  and constr (A.C (a, x)) =
    node a (fn () =>
      case x of
        A.CPlain (c, args) => (var c; List.app strict args)
      | A.CInfix (l, c, r) => (strict l; name OpForm c; strict r)
      | A.CRec (c, fs) =>
          (var c; kw "{";
           commas (fn A.Field (fa, vs, b, t) => node fa (fn () => (commas var vs; kw "::"; strict (b, t)))) fs;
           kw "}"))

  and deriving NONE = ()
    | deriving (SOME (A.Deriv (a, paren, cs))) =
        node a (fn () =>
          (kw "deriving";
           if paren then (tk ("(", Open); commas plain cs; tk (")", Close)) else commas plain cs))

  and simple (c, vs) = (plain c; List.app plain vs)

  and body what NONE = ()
    | body what (SOME ds) = (kw "where"; block (ds, decl))

  and decl (A.D (a, x)) =
    node a (fn () =>
      case x of
        A.DSig (vs, c, t) => (commas var vs; kw "::"; context c; ty t)
      | A.DFixity (f, p, ops) =>
          (kw (case f of A.Infix => "infix" | A.Infixl => "infixl" | A.Infixr => "infixr");
           (case p of SOME n => lit n | NONE => ());
           commas qop ops)
      | A.DFun (l, r) => (funlhs l; rhs "=" r)
      | A.DPat (p, r) => (pat p; rhs "=" r)
      | A.DType (c, vs, t) => (kw "type"; simple (c, vs); kw "="; ty t)
      | A.DData (cx, c, vs, cs, d) =>
          (kw "data"; context cx; simple (c, vs); kw "="; sepBy (constr, fn () => kw "|") cs; deriving d)
      | A.DNewtype (cx, c, vs, k, d) =>
          (kw "newtype"; context cx; simple (c, vs); kw "="; constr k; deriving d)
      | A.DClass (cx, c, v, b) => (kw "class"; context cx; plain c; plain v; body "class" b)
      | A.DInstance (cx, c, t, b) => (kw "instance"; context cx; plain c; ty t; body "instance" b)
      | A.DDefault ts => (kw "default"; tk ("(", Open); commas ty ts; tk (")", Close)))

  (* ---- modules ---- *)

  fun sub NONE = ()
    | sub (SOME A.SubAll) = (tk ("(", Open); kw ".."; tk (")", Close))
    | sub (SOME (A.SubList ns)) = (tk ("(", Open); commas var ns; tk (")", Close))

  fun entity (A.Ent (a, x)) =
    node a (fn () =>
      case x of
        A.EntVar v => var v
      | A.EntType (c, s) => (plain c; sub s)
      | A.EntModule m => (kw "module"; plain m))

  fun import (A.Import (a, {qualified, module = m, as_, hiding, spec})) =
    node a (fn () =>
      (kw "import";
       if qualified then kw "qualified" else ();
       plain m;
       (case as_ of SOME n => (kw "as"; plain n) | NONE => ());
       if hiding then kw "hiding" else ();
       case spec of
         SOME es => (tk ("(", Open); commas entity es; tk (")", Close))
       | NONE => ()))

  datatype top = TImp of A.import | TDec of A.decl

  fun topItem (TImp i) = import i
    | topItem (TDec d) = decl d

  fun module (A.Module (a, {name = n, exports, imports, decls})) =
    node a (fn () =>
      let
        val items = List.map TImp imports @ List.map TDec decls
      in
        (case n of
           SOME m =>
             (kw "module"; plain m;
              (case exports of
                 SOME es => (tk ("(", Open); commas entity es; tk (")", Close))
               | NONE => ());
              kw "where")
         | NONE => ());
        case (n, items, !mode) of
          (NONE, [], Explicit) => ()
        | (NONE, [], Implicit) => ()
        | (_, _ :: _, Implicit) =>
            (* the items of the top level at the first column *)
            (List.app (fn x => (cont := NONE; if null (!out) then () else newline 0; topItem x)) items;
             cont := NONE)
        | _ => block (items, topItem)
      end)

  fun run (m, f) =
    (mode := m; out := []; lineStart := true; last := #" "; lastKind := Word; indent := 0; cont := NONE;
     frames := [];
     f ();
     (case m of Exact => () | _ => raw "\n");
     let val s = String.concat (List.rev (!out)) in out := []; frames := []; src := ""; s end)

  fun explicit m = run (Explicit, fn () => module m)
  fun implicit m = run (Implicit, fn () => module m)
  fun exact (bytes, m) = (src := bytes; run (Exact, fn () => module m))

  fun fragment f x =
    let val s = run (Explicit, fn () => f x)
    in String.substring (s, 0, size s - 1) end

  val exp = fragment exp
  val pat = fragment pat
  val ty = fragment ty
  val decl = fragment decl
end
