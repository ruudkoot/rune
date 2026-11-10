(* Implements: HS_PARSER *)
structure HsParser :> HS_PARSER =
struct
  structure T = HsToken
  structure A = HsAst
  structure L = HsLayout

  datatype annotations = Bare | Spans | Full
  type options = {lexer : HsLexer.options, annotations : annotations}
  val defaults : options = {lexer = HsLexer.defaults, annotations = Full}

  (* ---- the state of a parse ---- *)

  val mode = ref Full
  val file = ref ""
  (* tokens passed so far, which numbers them *)
  val seq = ref 0
  (* tokens passed that no node owns yet, the last first *)
  val pending : (int * A.tok) list ref = ref []
  val tracing = ref false
  val trace : T.token list ref = ref []

  val cur = L.current

  fun fail msg = L.fail msg

  (* where each token passed begins, by its number *)
  val starts : int array ref = ref (Array.array (0, 0))

  fun noteStart () =
    let val k = !seq val a = !starts
    in
      if k >= Array.length a then
        let val b = Array.array (2 * k + 64, 0)
        in Array.copy {src = a, dst = b, di = 0}; starts := b end
      else ();
      Array.update (!starts, k, L.currentStart ())
    end

  (* the token `t` passed, owned by the node to be, which `tok` makes *)
  fun note (t, tok : unit -> A.tok) =
    ((case !mode of
        Full => (pending := (!seq, tok ()) :: !pending; noteStart ())
      | Spans => noteStart ()
      | Bare => ());
     if !tracing then trace := t :: !trace else ();
     seq := !seq + 1)

  fun passed () =
    let val {start, stop, ...} = L.here ()
    in {trivia = L.trivia (), start = start, stop = stop} end

  fun advance () =
    ((case !mode of
        Full => (pending := (!seq, passed ()) :: !pending; noteStart ())
      | Spans => noteStart ()
      | Bare => ());
     if !tracing then trace := !cur :: !trace else ();
     seq := !seq + 1;
     L.advance ())

  (* the close of a layout block that parse-error(t) took *)
  fun noteClose () =
    note (T.VRBRACE, fn () => let val a = L.currentStart () in {trivia = [], start = a, stop = a} end)

  (* Where a node begins: the number of the next token. *)
  type mark = int

  fun mark () : mark = !seq

  (* where the token numbered `k` begins, or the current one if it is not
     passed yet *)
  fun startOf k = if k < !seq then Array.sub (!starts, k) else L.currentStart ()

  (* the tokens passed since the mark that no node below took, in order *)
  fun take s =
    let
      fun go ((e as (k, t)) :: r, acc) = if k >= s then go (r, t :: acc) else (pending := e :: r; acc)
        | go ([], acc) = (pending := []; acc)
    in
      go (!pending, [])
    end

  fun ann (s : mark) : A.ann =
    case !mode of
      Bare => A.noAnn
    | Spans => let val a = startOf s in {span = {file = !file, start = a, stop = Int.max (a, L.lastStop ())}, toks = []} end
    | Full => let val a = startOf s in {span = {file = !file, start = a, stop = Int.max (a, L.lastStop ())}, toks = take s} end

  (* the annotation of a node that ends at `stop`, before the last token passed *)
  fun annUpTo (s : mark, stop) : A.ann =
    case !mode of
      Bare => A.noAnn
    | Spans => {span = {file = !file, start = startOf s, stop = stop}, toks = []}
    | Full => {span = {file = !file, start = startOf s, stop = stop}, toks = take s}

  (* an annotation that holds the tokens of others besides its own *)
  fun mergeToks (a : A.tok list, b : A.tok list) =
    case (a, b) of
      ([], _) => b
    | (_, []) => a
    | (x :: r, y :: s) => if #start x <= #start y then x :: mergeToks (r, b) else y :: mergeToks (a, s)
  fun absorb ({span, toks} : A.ann, more : A.tok list) : A.ann = {span = span, toks = mergeToks (toks, more)}
  fun toksOf ({toks, ...} : A.ann) = toks
  fun spanOf ({span, ...} : A.ann) = span
  fun joinAnn (a : A.ann, b : A.ann) : A.ann =
    case !mode of
      Bare => A.noAnn
    | _ => {span = HsSource.join (spanOf a, spanOf b), toks = []}

  fun failAt (a : A.ann, msg) =
    case !mode of
      Bare => fail msg
    | _ => raise HsSource.Error (spanOf a, msg)

  (* an error over what was read since the mark `s` *)
  fun failFrom (s : mark, msg) =
    case !mode of
      Bare => fail msg
    | _ => let val a = startOf s in raise HsSource.Error ({file = !file, start = a, stop = Int.max (a, L.lastStop ())}, msg) end

  fun mkE s x = A.E (ann s, x)
  fun mkP s x = A.P (ann s, x)
  fun mkT s x = A.T (ann s, x)
  fun mkD s x = A.D (ann s, x)
  fun mkS s x = A.S (ann s, x)
  fun mkName s q = A.Name (ann s, q)
  fun mkC s x = A.C (ann s, x)
  fun mkEnt s x = A.Ent (ann s, x)

  fun q0 n : A.qname = {qual = "", name = n}

  fun expected (what, ctx) =
    fail ("expected " ^ what ^ (if ctx = "" then "" else " " ^ ctx) ^ ", found " ^ T.describe (!cur))

  fun expect (t, ctx) = if !cur = t then advance () else expected ("`" ^ T.show t ^ "`", ctx)

  (* ---- names ---- *)

  fun varid ctx =
    case !cur of
      T.VARID s => let val m = mark () in advance (); mkName m (q0 s) end
    | _ => expected ("a variable", ctx)

  fun conid ctx =
    case !cur of
      T.CONID s => let val m = mark () in advance (); mkName m (q0 s) end
    | _ => expected ("a constructor", ctx)

  val dotted = ref false

  fun modid ctx =
    case !cur of
      T.CONID s => let val m = mark () in advance (); mkName m (q0 s) end
    | T.QCONID (q, s) =>
        if !dotted then let val m = mark () in advance (); mkName m (q0 (q ^ "." ^ s)) end
        else fail ("a dotted module name" ^ (if ctx = "" then "" else " " ^ ctx) ^ ", `" ^ q ^ "." ^ s ^
                   "`, which Haskell 98 does not have")
    | _ => expected ("a module name", ctx)

  (* var: varid or ( varsym ) *)
  fun var ctx =
    case !cur of
      T.VARID s => let val m = mark () in advance (); mkName m (q0 s) end
    | T.LPAREN =>
        let val m = mark ()
        in
          advance ();
          case !cur of
            T.VARSYM s => (advance (); expect (T.RPAREN, "after an operator in parentheses"); mkName m (q0 s))
          | _ => expected ("an operator in parentheses", ctx)
        end
    | _ => expected ("a variable", ctx)

  fun qvar ctx =
    case !cur of
      T.VARID s => let val m = mark () in advance (); mkName m (q0 s) end
    | T.QVARID (q, s) => let val m = mark () in advance (); mkName m {qual = q, name = s} end
    | T.LPAREN =>
        let val m = mark ()
        in
          advance ();
          case !cur of
            T.VARSYM s => (advance (); expect (T.RPAREN, "after an operator in parentheses"); mkName m (q0 s))
          | T.QVARSYM (q, s) =>
              (advance (); expect (T.RPAREN, "after an operator in parentheses"); mkName m {qual = q, name = s})
          | _ => expected ("an operator in parentheses", ctx)
        end
    | _ => expected ("a variable", ctx)

  fun con ctx =
    case !cur of
      T.CONID s => let val m = mark () in advance (); mkName m (q0 s) end
    | T.LPAREN =>
        let val m = mark ()
        in
          advance ();
          case !cur of
            T.CONSYM s =>
              (advance (); expect (T.RPAREN, "after a constructor operator in parentheses"); mkName m (q0 s))
          | _ => expected ("a constructor operator in parentheses", ctx)
        end
    | _ => expected ("a constructor", ctx)

  fun isOpTok t =
    case t of
      T.VARSYM _ => true | T.QVARSYM _ => true | T.CONSYM _ => true | T.QCONSYM _ => true
    | T.COLON => true | T.BACKQUOTE => true
    | _ => false

  (* a qop, passed if there is one *)
  fun takeQop () : A.qop option =
    let val m = mark ()
    in
      case !cur of
        T.VARSYM s => (advance (); SOME (A.VarOp (mkName m (q0 s))))
      | T.QVARSYM (q, s) => (advance (); SOME (A.VarOp (mkName m {qual = q, name = s})))
      | T.CONSYM s => (advance (); SOME (A.ConOp (mkName m (q0 s))))
      | T.QCONSYM (q, s) => (advance (); SOME (A.ConOp (mkName m {qual = q, name = s})))
      | T.COLON => (advance (); SOME (A.ConOp (mkName m (q0 ":"))))
      | T.BACKQUOTE =>
          let
            val () = advance ()
            val r =
              case !cur of
                T.VARID s => (fn n => A.VarOp n, q0 s)
              | T.QVARID (q, s) => (fn n => A.VarOp n, {qual = q, name = s})
              | T.CONID s => (fn n => A.ConOp n, q0 s)
              | T.QCONID (q, s) => (fn n => A.ConOp n, {qual = q, name = s})
              | _ => expected ("a name", "in backquotes")
          in
            advance ();
            expect (T.BACKQUOTE, "to close a name in backquotes");
            SOME (#1 r (mkName m (#2 r)))
          end
      | _ => NONE
    end

  (* After the `(` of `(,,)`, at its first comma: the name of the tuple
     constructor. *)
  fun commaTuple () : string =
    let
      fun go k =
        case !cur of
          T.COMMA => (advance (); go (k + 1))
        | T.RPAREN => (advance (); k)
        | _ => expected ("`,` or `)`", "in a tuple constructor")
      val k = go 0
    in
      "(" ^ implode (List.tabulate (k, fn _ => #",")) ^ ")"
    end

  (* ---- types ---- *)

  fun startsAtype t =
    case t of
      T.VARID _ => true | T.CONID _ => true | T.QCONID _ => true
    | T.LPAREN => true | T.LBRACKET => true
    | _ => false

  (* A type of a guard of an alternative stops before an arrow outside
     brackets, which the alternative's is (3.13's note) *)
  val stopArrow = ref false

  fun inside f =
    let val old = !stopArrow
    in
      stopArrow := false;
      (f () before stopArrow := old) handle e => (stopArrow := old; raise e)
    end

  fun ty () : A.ty =
    let
      val s = mark ()
      val b = btype ()
    in
      case !cur of
        T.RARROW =>
          if !stopArrow then b
          else (advance (); let val r = ty () in mkT s (A.TFun (b, r)) end)
      | _ => b
    end

  and btype () =
    let
      val s = mark ()
      fun loop acc =
        if startsAtype (!cur) then let val a = atype () in loop (mkT s (A.TApp (acc, a))) end
        else acc
    in
      loop (atype ())
    end

  and atype () =
    let val s = mark ()
    in
      case !cur of
        T.VARID v => (advance (); mkT s (A.TVar (mkName s (q0 v))))
      | T.CONID c => (advance (); mkT s (A.TCon (mkName s (q0 c))))
      | T.QCONID (q, c) => (advance (); mkT s (A.TCon (mkName s {qual = q, name = c})))
      | T.LBRACKET =>
          (advance ();
           case !cur of
             T.RBRACKET => (advance (); mkT s (A.TCon (mkName s (q0 "[]"))))
           | _ => let val t = inside ty in expect (T.RBRACKET, "to close a list type"); mkT s (A.TList t) end)
      | T.LPAREN =>
          (advance ();
           inside (fn () =>
           case !cur of
             T.RPAREN => (advance (); mkT s (A.TCon (mkName s (q0 "()"))))
           | T.RARROW =>
               (advance (); expect (T.RPAREN, "after `(->`"); mkT s (A.TCon (mkName s (q0 "(->)"))))
           | T.COMMA => let val n = commaTuple () in mkT s (A.TCon (mkName s (q0 n))) end
           | _ =>
               let val t = ty ()
               in
                 case !cur of
                   T.RPAREN => (advance (); mkT s (A.TParen t))
                 | T.COMMA =>
                     let
                       fun more acc =
                         case !cur of
                           T.COMMA => (advance (); more (ty () :: acc))
                         | T.RPAREN => (advance (); List.rev acc)
                         | _ => expected ("`,` or `)`", "in a tuple type")
                     in
                       mkT s (A.TTuple (more [t]))
                     end
                 | _ => expected ("`,` or `)`", "in a type in parentheses")
               end))
      | _ => expected ("a type", "")
    end

  (* Is the type a class assertion? The Report's `class` is `qtycls tyvar`
     or `qtycls (tyvar atype ...)`; `simpleclass` the first alone, in the
     context of a class or an instance declaration. *)
  fun checkClass simple (A.T (a, x)) =
    case x of
      A.TApp (A.T (_, A.TCon _), A.T (_, A.TVar _)) => ()
    | A.TApp (A.T (_, A.TCon _), A.T (pa, A.TParen t)) =>
        if simple then
          failAt (pa, "a class assertion on other than a type variable, in the context of a class or an instance declaration")
        else
          let
            fun headVar (A.T (_, A.TVar _)) = true
              | headVar (A.T (_, A.TApp (h, _))) = headVar h
              | headVar _ = false
          in
            case t of
              A.T (_, A.TApp _) =>
                if headVar t then () else failAt (pa, "a class assertion on a type that a type variable does not head")
            | _ => failAt (pa, "a class assertion on a type that is neither a type variable nor one applied")
          end
    | A.TApp (A.T (_, A.TCon _), A.T (pa, _)) =>
        if simple then
          failAt (pa, "a class assertion on other than a type variable, in the context of a class or an instance declaration")
        else failAt (pa, "a class assertion on a type that is neither a type variable nor one applied, in parentheses")
    | _ => failAt (a, "a context that is not class assertions, a class applied to a type variable")

  fun checkContext simple (t as A.T (a, x)) =
    case x of
      A.TCon (A.Name (_, {qual = "", name = "()"})) => ()
    | A.TParen (t' as A.T (_, A.TApp _)) => checkClass simple t'
    | A.TTuple ts => List.app (checkClass simple) ts
    | A.TApp _ => checkClass simple t
    | _ => failAt (a, "a context that is not class assertions, a class applied to a type variable")

  (* [context =>] type *)
  fun ctype () : A.ty option * A.ty =
    let val t = ty ()
    in
      case !cur of
        T.DARROW => (checkContext false t; advance (); let val r = ty () in (SOME t, r) end)
      | _ => (NONE, t)
    end

  (* ---- patterns ---- *)

  fun startsApat t =
    case t of
      T.VARID _ => true | T.CONID _ => true | T.QCONID _ => true
    | T.INTEGER _ => true | T.FLOAT _ => true | T.CHAR _ => true | T.STRING _ => true
    | T.UNDERSCORE => true | T.LPAREN => true | T.LBRACKET => true | T.TILDE => true
    | _ => false

  fun isMinus t = case t of T.VARSYM "-" => true | _ => false

  fun literal ctx : A.lit =
    let
      val m = mark ()
      val l =
        case !cur of
          T.INTEGER (n, s) => A.LInt (n, s)
        | T.FLOAT s => A.LFloat s
        | T.CHAR (c, s) => A.LChar (c, s)
        | T.STRING (cs, s) => A.LString (cs, s)
        | _ => expected ("a literal", ctx)
    in
      advance (); A.Lit (ann m, l)
    end

  fun commaList (item, close, ctx) =
    let
      fun more acc =
        case !cur of
          T.COMMA => (advance (); more (item () :: acc))
        | t => if t = close then (advance (); List.rev acc) else expected ("`,` or `" ^ T.show close ^ "`", ctx)
    in
      more [item ()]
    end

  fun fieldPats s q =
    (* at its { *)
    let
      val () = advance ()
      fun fld () =
        let val f = qvar "as a field of a record pattern"
        in expect (T.EQUALS, "after a field of a record pattern"); (f, toPat true (lseq ())) end
      val fs =
        case !cur of
          T.RBRACE => (advance (); [])
        | _ => commaList (fld, T.RBRACE, "in a record pattern")
    in
      mkP s (A.PRec (q, fs))
    end

  and apat () : A.pat =
    let val s = mark ()
    in
      case !cur of
        T.VARID v =>
          (advance ();
           let val n = mkName s (q0 v)
           in
             case !cur of
               T.AT => (advance (); let val p = apat () in mkP s (A.PAs (n, p)) end)
             | _ => mkP s (A.PVar n)
           end)
      | T.CONID c => (advance (); conPat s (mkName s (q0 c)))
      | T.QCONID (q, c) => (advance (); conPat s (mkName s {qual = q, name = c}))
      | T.UNDERSCORE => (advance (); mkP s A.PWild)
      | T.TILDE => (advance (); let val p = apat () in mkP s (A.PLazy p) end)
      | T.LBRACKET =>
          (advance ();
           case !cur of
             T.RBRACKET => (advance (); mkP s (A.PCon (mkName s (q0 "[]"), [])))
           | _ => mkP s (A.PList (commaList (lseq, T.RBRACKET, "in a list pattern"))))
      | T.LPAREN =>
          (advance ();
           case !cur of
             T.RPAREN => (advance (); mkP s (A.PCon (mkName s (q0 "()"), [])))
           | T.COMMA => let val n = commaTuple () in mkP s (A.PCon (mkName s (q0 n), [])) end
           | T.VARSYM v =>
               (case L.peek 0 of
                  T.RPAREN => (advance (); advance (); mkP s (A.PVar (mkName s (q0 v))))
                | _ => parenPat s)
           | T.CONSYM c =>
               (case L.peek 0 of
                  T.RPAREN => (advance (); advance (); conPat s (mkName s (q0 c)))
                | _ => parenPat s)
           | T.QCONSYM (q, c) =>
               (case L.peek 0 of
                  T.RPAREN => (advance (); advance (); conPat s (mkName s {qual = q, name = c}))
                | _ => parenPat s)
           | T.COLON =>
               (case L.peek 0 of
                  T.RPAREN => (advance (); advance (); conPat s (mkName s (q0 ":")))
                | _ => parenPat s)
           | _ => parenPat s)
      | T.INTEGER _ => let val l = literal "" in mkP s (A.PLit l) end
      | T.FLOAT _ => let val l = literal "" in mkP s (A.PLit l) end
      | T.CHAR _ => let val l = literal "" in mkP s (A.PLit l) end
      | T.STRING _ => let val l = literal "" in mkP s (A.PLit l) end
      | _ => expected ("a pattern", "")
    end

  and conPat s n =
    case !cur of
      T.LBRACE => fieldPats s n
    | _ => mkP s (A.PCon (n, []))

  and parenPat s =
    let val p = lseq ()
    in
      case !cur of
        T.RPAREN => (advance (); mkP s (A.PParen p))
      | T.COMMA =>
          let
            fun more acc =
              case !cur of
                T.COMMA => (advance (); more (lseq () :: acc))
              | T.RPAREN => (advance (); List.rev acc)
              | _ => expected ("`,` or `)`", "in a tuple pattern")
          in
            mkP s (A.PTuple (more [p]))
          end
      | _ => expected ("`,` or `)`", "in a pattern in parentheses")
    end

  (* an operand: - and a numeric literal, or a run of apats *)
  and operand () : A.pat =
    let val s = mark ()
    in
      if isMinus (!cur) then
        (advance ();
         case !cur of
           T.INTEGER _ => let val l = literal "" in mkP s (A.PNegLit l) end
         | T.FLOAT _ => let val l = literal "" in mkP s (A.PNegLit l) end
         | _ => expected ("a number after `-`", "in a pattern"))
      else
        let
          val a = apat ()
          fun run acc = if startsApat (!cur) then run (apat () :: acc) else List.rev acc
        in
          case run [a] of
            [x] => x
          | xs => mkP s (A.PJux xs)
        end
    end

  and lseq () : A.pat =
    let
      val s = mark ()
      val a = operand ()
      fun loop acc =
        if isOpTok (!cur) then
          (case takeQop () of
             SOME oper => let val b = operand () in loop (A.PA b :: A.PO oper :: acc) end
           | NONE => List.rev acc)
        else List.rev acc
    in
      case loop [A.PA a] of
        [A.PA x] => x
      | items => mkP s (A.PSeq items)
    end

  (* The check that makes a relaxed pattern one of the Report's. `nk` says
     whether this is the level `pat`, where `var + integer` is. *)
  and toPat (nk : bool) (A.P (sp, x)) : A.pat =
    case x of
      A.PJux (A.P (ca, A.PCon (q, [])) :: args) => A.P (absorb (sp, toksOf ca), A.PCon (q, List.map (toPat false) args))
    | A.PJux (A.P (_, A.PVar (A.Name (na, {name, ...}))) :: _) =>
        failAt (na, "in a pattern, the variable `" ^ name ^ "` applied to arguments: only a constructor can be")
    | A.PJux _ => failAt (sp, "in a pattern, arguments applied to something other than a constructor")
    | A.PSeq [A.PA (A.P (va, A.PVar v)), A.PO (A.VarOp (A.Name (pa, {qual = "", name = "+"}))),
              A.PA (A.P (ka, A.PLit (k as A.Lit (_, A.LInt _))))] =>
        if nk then A.P (absorb (sp, mergeToks (toksOf va, mergeToks (toksOf pa, toksOf ka))), A.PNPlusK (v, k))
        else failAt (sp, "an n+k pattern where only an atomic pattern or a constructor's may stand")
    | A.PSeq items =>
        A.P (sp, A.PSeq (List.map
          (fn A.PA p => A.PA (toPat false p)
            | A.PO (oper as A.ConOp _) => A.PO oper
            | A.PO (A.VarOp (A.Name (na, q))) =>
                failAt (na, "the variable operator `" ^ A.nameText q ^ "` in a pattern: only a constructor operator can stand there"))
          items))
    | A.PParen p => A.P (sp, A.PParen (toPat true p))
    | A.PTuple ps => A.P (sp, A.PTuple (List.map (toPat true) ps))
    | A.PList ps => A.P (sp, A.PList (List.map (toPat true) ps))
    | A.PAs (v, p) => A.P (sp, A.PAs (v, toPat false p))
    | A.PLazy p => A.P (sp, A.PLazy (toPat false p))
    | A.PRec (c, fs) => A.P (sp, A.PRec (c, fs))
    | _ => A.P (sp, x)

  fun pat () = toPat true (lseq ())

  (* ---- declarations and expressions: one knot ---- *)

  datatype lhs = LFun of A.funlhs | LPat of A.pat

  (* What a left-hand side, read as a relaxed pattern, is. *)
  fun classify (p as A.P (pa, x)) : lhs =
    case x of
      A.PSeq items =>
        let
          fun split ([], _) = NONE
            | split (A.PO (oper as A.VarOp (A.Name (na, {qual, ...}))) :: rest, acc) =
                if qual = "" then SOME (List.rev acc, oper, rest)
                else failAt (na, "a qualified operator on the left of a definition: it cannot be defined here")
            | split (i :: rest, acc) = split (rest, i :: acc)
          fun spanOfItem (A.PA (A.P (a, _))) = a
            | spanOfItem (A.PO (A.VarOp (A.Name (a, _)))) = a
            | spanOfItem (A.PO (A.ConOp (A.Name (a, _)))) = a
          fun side [A.PA a] = toPat false a
            | side items = toPat false (A.P (joinAnn (spanOfItem (hd items), spanOfItem (List.last items)), A.PSeq items))
        in
          case split (items, []) of
            NONE => LPat (toPat false p)
          | SOME (l, oper, r) => LFun (A.F (pa, A.FInfix (side l, oper, side r)))
        end
    | A.PJux (A.P (va, A.PVar f) :: args) => LFun (A.F (absorb (pa, toksOf va), A.FPrefix (f, List.map (toPat false) args)))
    | A.PJux (A.P (qa, A.PParen inner) :: args) =>
        (case classify inner of
           LFun l => LFun (A.F (absorb (pa, toksOf qa), A.FParen (l, List.map (toPat false) args)))
         | LPat _ => failAt (qa, "a pattern applied to arguments on the left of a definition"))
    | _ => LPat (toPat false p)

  fun startsExp t =
    case t of
      T.VARID _ => true | T.QVARID _ => true | T.CONID _ => true | T.QCONID _ => true
    | T.INTEGER _ => true | T.FLOAT _ => true | T.CHAR _ => true | T.STRING _ => true
    | T.LPAREN => true | T.LBRACKET => true
    | T.LET => true | T.IF => true | T.CASE => true | T.DO => true | T.BACKSLASH => true
    | T.VARSYM "-" => true
    | _ => false

  fun startsAexp t =
    case t of
      T.VARID _ => true | T.QVARID _ => true | T.CONID _ => true | T.QCONID _ => true
    | T.INTEGER _ => true | T.FLOAT _ => true | T.CHAR _ => true | T.STRING _ => true
    | T.LPAREN => true | T.LBRACKET => true
    | _ => false

  fun startsDecl t =
    startsApat t orelse isMinus t orelse
    (case t of T.INFIX => true | T.INFIXL => true | T.INFIXR => true | _ => false)

  fun startsAlt t = startsApat t orelse isMinus t

  fun startsStmt t = startsExp t orelse (case t of T.UNDERSCORE => true | T.TILDE => true | _ => false)

  (* A block, its items each read by `item` once the next token can begin
     one. `what` names an item and `whose` the block, for a message. *)
  fun block (what : string, whose : string, starts : T.token -> bool, item : unit -> 'a) : 'a list =
    let
      fun items acc =
        case !cur of
          T.SEMI => (advance (); items acc)
        | T.VSEMI => (advance (); items acc)
        | t =>
            if starts t then
              let val x = item ()
              in
                case !cur of
                  T.SEMI => items (x :: acc)
                | T.VSEMI => items (x :: acc)
                | _ => List.rev (x :: acc)
              end
            else List.rev acc
    in
      case !cur of
        T.LBRACE =>
          (advance ();
           let val xs = items []
           in
             case !cur of
               T.RBRACE => (advance (); xs)
             | _ => expected ("`;` or `}`", "after " ^ what ^ " in " ^ whose)
           end)
      | T.VLBRACE =>
          (advance ();
           let val xs = items []
           in
             case !cur of
               T.VRBRACE => (advance (); xs)
             | _ =>
                 if L.closeImplicit () then (noteClose (); xs)
                 else expected ("the end of the layout block", "of " ^ whose)
           end)
      | _ => expected (whose, "")
    end

  fun exp () : A.exp =
    let
      val s = mark ()
      val e = opExp ()
    in
      case !cur of
        T.DCOLON => (advance (); let val (c, t) = ctype () in mkE s (A.ESig (e, c, t)) end)
      | _ => e
    end

  and seqItems (allowTrailing : bool) : A.expitem list * A.qop option =
    let
      fun operandAt acc =
        if isMinus (!cur) then (advance (); operand2 (A.ENeg :: acc))
        else operand2 acc
      and operand2 acc = let val e = exp10 () in afterOperand (A.EA e :: acc) end
      and afterOperand acc =
        if isOpTok (!cur) then
          (case takeQop () of
             SOME oper =>
               (case !cur of
                  T.RPAREN =>
                    if allowTrailing then (List.rev acc, SOME oper)
                    else expected ("an expression", "after an operator")
                | _ => operandAt (A.EO oper :: acc))
           | NONE => (List.rev acc, NONE))
        else (List.rev acc, NONE)
    in
      operandAt []
    end

  and seqToExp s (items : A.expitem list) =
    case items of
      [A.EA e] => e
    | _ => mkE s (A.ESeq items)

  and opExp () : A.exp =
    let
      val s = mark ()
      val (items, _) = seqItems false
    in
      seqToExp s items
    end

  and exp10 () : A.exp =
    let val s = mark ()
    in
      case !cur of
        T.BACKSLASH =>
          (advance ();
           let
             fun pats acc = if startsApat (!cur) then pats (toPat false (apat ()) :: acc) else List.rev acc
             val ps = pats []
           in
             if null ps then expected ("a pattern", "after the `\\` of a lambda") else ();
             expect (T.RARROW, "after the patterns of a lambda");
             let val b = exp () in mkE s (A.ELam (ps, b)) end
           end)
      | T.LET =>
          (advance ();
           let val ds = decls ("a declaration", "a `let` block")
           in
             expect (T.IN, "after the declarations of `let`");
             let val b = exp () in mkE s (A.ELet (ds, b)) end
           end)
      | T.IF =>
          (advance ();
           let
             val c = exp ()
             val () = expect (T.THEN, "after the condition of `if`")
             val a = exp ()
             val () = expect (T.ELSE, "after the `then` branch of `if`")
             val b = exp ()
           in
             mkE s (A.EIf (c, a, b))
           end)
      | T.CASE =>
          (advance ();
           let
             val e = exp ()
             val () = expect (T.OF, "after the scrutinee of `case`")
             val alts = block ("an alternative", "the alternatives of `case`", startsAlt, alt)
           in
             if null alts then failFrom (s, "a `case` with no alternatives") else ();
             mkE s (A.ECase (e, alts))
           end)
      | T.DO =>
          (advance ();
           let val ss = block ("a statement", "a `do` block", startsStmt, stmt)
           in
             (case List.rev ss of
                A.S (_, A.SExp _) :: _ => ()
              | A.S (a, A.SLet _) :: _ => failAt (a, "the last statement of a `do` block is a `let`, not an expression")
              | A.S (a, A.SBind _) :: _ => failAt (a, "the last statement of a `do` block is a binding `<-`, not an expression")
              | [] => failFrom (s, "a `do` block with no statements"));
             mkE s (A.EDo ss)
           end)
      | _ => fexp ()
    end

  and fexp () =
    let
      val s = mark ()
      (* what reaches to the right is no argument but in parentheses *)
      fun open' t =
        case t of
          T.BACKSLASH => SOME "a lambda" | T.LET => SOME "a `let` expression" | T.IF => SOME "an `if` expression"
        | T.CASE => SOME "a `case` expression" | T.DO => SOME "a `do` block"
        | _ => NONE
      fun loop acc =
        if startsAexp (!cur) then let val a = aexp () in loop (mkE s (A.EApp (acc, a))) end
        else
          case open' (!cur) of
            SOME what => fail (what ^ " as the argument of an application: Haskell 98 wants it in parentheses")
          | NONE => acc
    in
      loop (aexp ())
    end

  and fbinds () =
    (* at its { *)
    let
      val () = advance ()
      fun fld () =
        let val f = qvar "as a field"
        in expect (T.EQUALS, "after a field"); (f, exp ()) end
    in
      case !cur of
        T.RBRACE => (advance (); [])
      | _ => commaList (fld, T.RBRACE, "in the fields of a record")
    end

  and aexp () =
    let
      val s = mark ()
      fun recordSuffix (e as A.E (ea, x)) =
        case !cur of
          T.LBRACE =>
            let val fs = fbinds ()
            in
              case x of
                A.ECon q => recordSuffix (A.E (absorb (ann s, toksOf ea), A.ERecCon (q, fs)))
              | _ =>
                  if null fs then failFrom (s, "a record update with no fields")
                  else recordSuffix (mkE s (A.ERecUpd (e, fs)))
            end
        | _ => e
    in
      recordSuffix (aexp1 ())
    end

  and aexp1 () =
    let val s = mark ()
    in
      case !cur of
        T.VARID v => (advance (); mkE s (A.EVar (mkName s (q0 v))))
      | T.QVARID (q, v) => (advance (); mkE s (A.EVar (mkName s {qual = q, name = v})))
      | T.CONID c => (advance (); mkE s (A.ECon (mkName s (q0 c))))
      | T.QCONID (q, c) => (advance (); mkE s (A.ECon (mkName s {qual = q, name = c})))
      | T.LPAREN => (advance (); parenExp s)
      | T.LBRACKET => (advance (); listExp s)
      | T.INTEGER _ => let val l = literal "" in mkE s (A.ELit l) end
      | T.FLOAT _ => let val l = literal "" in mkE s (A.ELit l) end
      | T.CHAR _ => let val l = literal "" in mkE s (A.ELit l) end
      | T.STRING _ => let val l = literal "" in mkE s (A.ELit l) end
      | _ => expected ("an expression", "")
    end

  and parenExp s =
    case !cur of
      T.RPAREN => (advance (); mkE s (A.ECon (mkName s (q0 "()"))))
    | T.COMMA => let val n = commaTuple () in mkE s (A.ECon (mkName s (q0 n))) end
    | t =>
        if isOpTok t andalso not (isMinus t andalso (case L.peek 0 of T.RPAREN => false | _ => true)) then
          (* (op), or (op e) *)
          case (t, L.peek 0) of
            (T.BACKQUOTE, _) => rightSection s
          | (_, T.RPAREN) =>
              let
                val q =
                  case t of
                    T.VARSYM v => (q0 v, true) | T.QVARSYM (m, v) => ({qual = m, name = v}, true)
                  | T.CONSYM c => (q0 c, false) | T.QCONSYM (m, c) => ({qual = m, name = c}, false)
                  | _ => (q0 ":", false)
              in
                advance (); advance ();
                let val n = mkName s (#1 q)
                in mkE s (if #2 q then A.EVar n else A.ECon n) end
              end
          | _ => rightSection s
        else
          let
            val s2 = mark ()
            val (items, trailing) = seqItems true
          in
            case trailing of
              SOME oper =>
                let
                  (* the operand ends before the operator, which is read *)
                  val inner =
                    case items of
                      [A.EA e] => e
                    | _ =>
                        let
                          val stop =
                            case List.last items of
                              A.EA e => #stop (A.spanOfExp e)
                            | _ => L.lastStop ()
                        in
                          A.E (annUpTo (s2, stop), A.ESeq items)
                        end
                in
                  expect (T.RPAREN, "to close a left section"); mkE s (A.ELeftSec (inner, oper))
                end
            | NONE =>
                let
                  val e1 = seqToExp s2 items
                  val e =
                    case !cur of
                      T.DCOLON => (advance (); let val (c, ty') = ctype () in mkE s2 (A.ESig (e1, c, ty')) end)
                    | _ => e1
                in
                  case !cur of
                    T.RPAREN => (advance (); mkE s (A.EParen e))
                  | T.COMMA =>
                      let
                        fun more acc =
                          case !cur of
                            T.COMMA => (advance (); more (exp () :: acc))
                          | T.RPAREN => (advance (); List.rev acc)
                          | _ => expected ("`,` or `)`", "in a tuple")
                      in
                        mkE s (A.ETuple (more [e]))
                      end
                  | _ => expected ("`)`", "to close an expression in parentheses")
                end
          end

  and rightSection s =
    let val oper = case takeQop () of SOME x => x | NONE => expected ("an operator", "in a section")
    in
      case !cur of
        T.RPAREN => expected ("an expression", "after the operator of a right section")
      | _ =>
          let val e = opExp ()
          in expect (T.RPAREN, "to close a right section"); mkE s (A.ERightSec (oper, e)) end
    end

  and listExp s =
    case !cur of
      T.RBRACKET => (advance (); mkE s (A.ECon (mkName s (q0 "[]"))))
    | _ =>
        let
          val e1 = exp ()
          fun enumEnd e2 =
            (* at its .. *)
            (advance ();
             case !cur of
               T.RBRACKET => (advance (); mkE s (A.EEnum (e1, e2, NONE)))
             | _ =>
                 let val e3 = exp ()
                 in expect (T.RBRACKET, "to close an arithmetic sequence"); mkE s (A.EEnum (e1, e2, SOME e3)) end)
        in
          case !cur of
            T.RBRACKET => (advance (); mkE s (A.EList [e1]))
          | T.DOTDOT => enumEnd NONE
          | T.BAR =>
              (advance ();
               mkE s (A.EComp (e1, commaList (stmt, T.RBRACKET, "in the qualifiers of a list comprehension"))))
          | T.COMMA =>
              let
                val () = advance ()
                val e2 = exp ()
              in
                case !cur of
                  T.DOTDOT => enumEnd (SOME e2)
                | T.RBRACKET => (advance (); mkE s (A.EList [e1, e2]))
                | T.COMMA =>
                    let
                      fun more acc =
                        case !cur of
                          T.COMMA => (advance (); more (exp () :: acc))
                        | T.RBRACKET => (advance (); List.rev acc)
                        | _ => expected ("`,` or `]`", "in a list")
                    in
                      mkE s (A.EList (more [e2, e1]))
                    end
                | _ => expected ("`,`, `..` or `]`", "in a list")
              end
          | _ => expected ("`]`", "to close a list")
        end

  (* A statement or a qualifier: `let`, `p <- e` or `e`. The pattern is
     tried first; failing it, or with no `<-` after it, the stream goes
     back and an expression is read. A pattern holds no block, so no
     implicit close happens in the try. *)
  and stmt () : A.stmt =
    let val s = mark ()
    in
      case !cur of
        T.LET =>
          (advance ();
           let val ds = decls ("a declaration", "a `let` block")
           in
             case !cur of
               T.IN =>
                 (advance ();
                  let val b = exp () in mkS s (A.SExp (mkE s (A.ELet (ds, b)))) end)
             | _ => mkS s (A.SLet ds)
           end)
      | t =>
          let
            val canBePat = startsApat t orelse isMinus t
            val st = save ()
            val tried =
              if canBePat then
                ((let val p = lseq ()
                  in case !cur of T.LARROW => SOME p | _ => NONE end)
                 handle HsSource.Error _ => NONE)
              else NONE
          in
            case tried of
              SOME p =>
                let val q = toPat true p
                in advance (); let val e = exp () in mkS s (A.SBind (q, e)) end end
            | NONE => (restore st; let val e = exp () in mkS s (A.SExp e) end)
          end
    end

  and alt () : A.alt =
    let
      val s = mark ()
      val p = pat ()
      val r = rhsWith (T.RARROW, "an alternative")
    in
      A.Alt (ann s, p, r)
    end

  (* the right-hand side of an equation or of an alternative, which differ
     in the token, `=` or `->` *)
  and rhsWith (sep : T.token, whose : string) : A.rhs =
    let val s = mark ()
    in
      case !cur of
        T.BAR =>
          let
            fun gds acc =
              case !cur of
                T.BAR =>
                  let
                    val g = mark ()
                    val () = advance ()
                    (* In an alternative, a type in the guard that took the
                       alternative's arrow is read again stopping before it:
                       `| let b = not a in b :: Bool -> a` (3.13's note). *)
                    val st = save ()
                    val c =
                      if sep <> T.RARROW then opExp ()
                      else
                        case ((let val c = opExp () in if !cur = sep then SOME c else NONE end)
                              handle HsSource.Error _ => NONE) of
                          SOME c => c
                        | NONE =>
                            (restore st;
                             stopArrow := true;
                             (opExp () before stopArrow := false) handle e => (stopArrow := false; raise e))
                    val () = expect (sep, "after a guard of " ^ whose)
                    val e = exp ()
                  in
                    gds (A.Guard (ann g, c, e) :: acc)
                  end
              | _ => List.rev acc
            val gs = gds []
            val w = maybeWhere ()
          in
            A.Rhs (ann s, A.Guarded (gs, w))
          end
      | t =>
          if t = sep then
            (advance ();
             let
               val e = exp ()
               val w = maybeWhere ()
             in
               A.Rhs (ann s, A.Plain (e, w))
             end)
          else expected ("`" ^ T.show sep ^ "` or a guard", "in " ^ whose)
    end

  and maybeWhere () =
    case !cur of
      T.WHERE => (advance (); SOME (decls ("a declaration", "a `where` block")))
    | _ => NONE

  and decls (what, whose) : A.decl list = block (what, whose, startsDecl, decl)

  and fixityDecl s =
    let
      val f =
        case !cur of
          T.INFIX => A.Infix | T.INFIXL => A.Infixl | T.INFIXR => A.Infixr
        | _ => expected ("a fixity", "")
      val () = advance ()
      val prec =
        case !cur of
          T.INTEGER (n, _) =>
            if IntInf.> (n, IntInf.fromInt 9) then fail "a precedence above 9 in a fixity declaration"
            else SOME (literal "")
        | _ => NONE
      fun oneOp () =
        case !cur of
          T.COLON => fail "`:` in a fixity declaration: its fixity is fixed"
        | _ =>
            case takeQop () of
              SOME (oper as A.VarOp (A.Name (_, {qual = "", ...}))) => oper
            | SOME (oper as A.ConOp (A.Name (_, {qual = "", ...}))) => oper
            | SOME (A.VarOp (A.Name (a, q))) => failAt (a, "the qualified operator `" ^ A.nameText q ^ "` in a fixity declaration")
            | SOME (A.ConOp (A.Name (a, q))) => failAt (a, "the qualified operator `" ^ A.nameText q ^ "` in a fixity declaration")
            | NONE => expected ("an operator", "in a fixity declaration")
      fun more acc =
        case !cur of
          T.COMMA => (advance (); more (oneOp () :: acc))
        | _ => List.rev acc
    in
      mkD s (A.DFixity (f, prec, more [oneOp ()]))
    end

  and decl () : A.decl =
    let val s = mark ()
    in
      case !cur of
        T.INFIX => fixityDecl s
      | T.INFIXL => fixityDecl s
      | T.INFIXR => fixityDecl s
      | _ =>
          let val p = lseq ()
          in
            case !cur of
              T.DCOLON => sigDecl s p
            | T.COMMA => sigDecl s p
            | _ =>
                let
                  val lh = classify p
                  val r = rhsWith (T.EQUALS, "a declaration")
                in
                  case lh of
                    LFun f => mkD s (A.DFun (f, r))
                  | LPat q => mkD s (A.DPat (q, r))
                end
          end
    end

  and sigDecl s (A.P (pa, x)) =
    let
      val v =
        case x of
          A.PVar v => v
        | _ => failAt (pa, "a type signature whose left-hand side is not variables")
      fun more acc =
        case !cur of
          T.COMMA => (advance (); more (var "in a type signature" :: acc))
        | _ => List.rev acc
      val vs = more [v]
      val () = expect (T.DCOLON, "after the variables of a type signature")
      val (c, t) = ctype ()
    in
      A.D (absorb (ann s, toksOf pa), A.DSig (vs, c, t))
    end

  and save () = (L.save (), !seq, !pending, !trace)
  and restore (m, k, p, t) = (L.restore m; seq := k; pending := p; trace := t)

  (* ---- declarations of the top level ---- *)

  fun simpletype ctx =
    let
      val c = conid ctx
      fun tvs acc =
        case !cur of
          T.VARID v => let val m = mark () in advance (); tvs (mkName m (q0 v) :: acc) end
        | _ => List.rev acc
    in
      (c, tvs [])
    end

  fun isBang t = case t of T.VARSYM "!" => true | _ => false

  fun strictAtype () = if isBang (!cur) then (advance (); (true, atype ())) else (false, atype ())

  fun isConop t =
    case t of
      T.CONSYM _ => true
    | T.BACKQUOTE => (case L.peek 0 of T.CONID _ => true | _ => false)
    | _ => false

  fun conop () =
    let val m = mark ()
    in
      case !cur of
        T.CONSYM c => (advance (); mkName m (q0 c))
      | T.BACKQUOTE =>
          (advance ();
           case !cur of
             T.CONID c => (advance (); expect (T.BACKQUOTE, "to close a constructor in backquotes"); mkName m (q0 c))
           | _ => expected ("a constructor", "in backquotes"))
      | _ => expected ("a constructor operator", "")
    end

  fun fielddecl () =
    let
      val s = mark ()
      fun more acc =
        case !cur of
          T.COMMA => (advance (); more (var "as a field" :: acc))
        | _ => List.rev acc
      val vs = more [var "as a field"]
      val () = expect (T.DCOLON, "after the fields of a record declaration")
    in
      if isBang (!cur) then (advance (); let val t = atype () in A.Field (ann s, vs, true, t) end)
      else let val t = ty () in A.Field (ann s, vs, false, t) end
    end

  (* a side of an infix constructor: ! atype, or a btype *)
  fun conSide () = if isBang (!cur) then (advance (); (true, atype ())) else (false, btype ())

  fun isConsymParen () =
    case (!cur, L.peek 0, L.peek 1) of
      (T.LPAREN, T.CONSYM _, T.RPAREN) => true
    | _ => false

  fun args acc =
    if startsAtype (!cur) orelse isBang (!cur) then args (strictAtype () :: acc) else List.rev acc

  fun recordCon c =
    (* at its { *)
    let
      val () = advance ()
      val fs =
        case !cur of
          T.RBRACE => (advance (); [])
        | _ => commaList (fielddecl, T.RBRACE, "in a record declaration")
    in
      A.CRec (c, fs)
    end

  fun constr () : A.constr =
    let val s = mark ()
    in
      if isBang (!cur) then
        let
          val l = conSide ()
          val c = conop ()
          val r = conSide ()
        in
          mkC s (A.CInfix (l, c, r))
        end
      else if isConsymParen () then
        let val c = con "in a constructor declaration"
        in
          case !cur of
            T.LBRACE => mkC s (recordCon c)
          | _ => mkC s (A.CPlain (c, args []))
        end
      else
        let
          val st = save ()
          (* a constructor and its fields, or a btype before a conop: a btype first *)
          val b = btype ()
        in
          if isConop (!cur) then
            let
              val c = conop ()
              val r = conSide ()
            in
              mkC s (A.CInfix ((false, b), c, r))
            end
          else
            (restore st;
             let val c = conid "in a constructor declaration"
             in
               case !cur of
                 T.LBRACE => mkC s (recordCon c)
               | _ => mkC s (A.CPlain (c, args []))
             end)
        end
    end

  fun qtycls ctx =
    let val m = mark ()
    in
      case !cur of
        T.CONID c => (advance (); mkName m (q0 c))
      | T.QCONID (q, c) => (advance (); mkName m {qual = q, name = c})
      | _ => expected ("a class", ctx)
    end

  fun deriving () =
    case !cur of
      T.DERIVING =>
        let val m = mark ()
        in
          advance ();
          case !cur of
            T.LPAREN =>
              (advance ();
               case !cur of
                 T.RPAREN => (advance (); SOME (A.Deriv (ann m, true, [])))
               | _ =>
                   let val cs = commaList (fn () => qtycls "in a `deriving` clause", T.RPAREN, "in a `deriving` clause")
                   in SOME (A.Deriv (ann m, true, cs)) end)
          | _ => let val c = qtycls "after `deriving`" in SOME (A.Deriv (ann m, false, [c])) end
        end
    | _ => NONE

  (* [context =>] and what `head` reads, by reading a type and looking at
     the token after it *)
  fun contextThen (simple : bool) (head : unit -> 'a) : A.ty option * 'a =
    let
      val st = save ()
      val tried =
        ((let val t = btype ()
          in
            case !cur of
              T.DARROW => SOME t
            | _ => NONE
          end)
         handle HsSource.Error _ => NONE)
    in
      case tried of
        SOME c => (checkContext simple c; advance (); (SOME c, head ()))
      | NONE => (restore st; (NONE, head ()))
    end

  fun checkCdecl (d as A.D (a, x)) =
    case x of
      A.DPat (A.P (_, A.PVar _), _) => d
    | A.DPat _ => failAt (a, "a pattern binding in a class declaration")
    | _ => d

  fun checkIdecl (d as A.D (a, x)) =
    case x of
      A.DFun _ => d
    | A.DPat (A.P (_, A.PVar _), _) => d
    | A.DPat _ => failAt (a, "a pattern binding in an instance declaration")
    | A.DSig _ => failAt (a, "a type signature in an instance declaration")
    | A.DFixity _ => failAt (a, "a fixity declaration in an instance declaration")
    | _ => d

  (* Is the type a legal `inst`? *)
  fun checkInst (A.T (ia, x)) =
    let
      fun tv (A.T (_, A.TVar (A.Name (_, {name, ...})))) = name
        | tv (A.T (a, _)) = failAt (a, "an instance head whose arguments are not type variables")
      fun distinct vs =
        case vs of
          [] => ()
        | v :: rest =>
            if List.exists (fn w => w = v) rest then failAt (ia, "the type variable `" ^ v ^ "` twice in an instance head")
            else distinct rest
      fun spine (A.T (_, A.TApp (h, a)), acc) = spine (h, tv a :: acc)
        | spine (A.T (_, A.TCon _), acc) = acc
        | spine (A.T (a, _), _) = failAt (a, "an instance head that is not a type constructor applied to type variables")
    in
      case x of
        A.TCon _ => ()
      | A.TList t => ignore (tv t)
      | A.TParen (A.T (_, A.TFun (a, b))) => distinct [tv a, tv b]
      | A.TParen (h as A.T (_, A.TApp _)) => distinct (spine (h, []))
      | A.TParen (A.T (_, A.TCon _)) => ()
      | A.TTuple ts => distinct (List.map tv ts)
      | _ => failAt (ia, "an instance head that is not a type constructor applied to type variables")
    end

  fun classBody what =
    case !cur of
      T.WHERE => (advance (); SOME (block ("a declaration", what, startsDecl, decl)))
    | _ => NONE

  fun topdecl () : A.decl =
    let val s = mark ()
    in
      case !cur of
        T.TYPE =>
          (advance ();
           let
             val (c, vs) = simpletype "in a type synonym declaration"
             val () = expect (T.EQUALS, "in a type synonym declaration")
             val t = ty ()
           in
             mkD s (A.DType (c, vs, t))
           end)
      | T.DATA =>
          (advance ();
           let
             val (cx, (c, vs)) = contextThen false (fn () => simpletype "in a `data` declaration")
             val () = expect (T.EQUALS, "in a `data` declaration")
             fun more acc =
               case !cur of
                 T.BAR => (advance (); more (constr () :: acc))
               | _ => List.rev acc
             val cs = more [constr ()]
             val d = deriving ()
           in
             mkD s (A.DData (cx, c, vs, cs, d))
           end)
      | T.NEWTYPE =>
          (advance ();
           let
             val (cx, (c, vs)) = contextThen false (fn () => simpletype "in a `newtype` declaration")
             val () = expect (T.EQUALS, "in a `newtype` declaration")
             val k = constr ()
             val () =
               case k of
                 A.C (_, A.CPlain (_, [(false, _)])) => ()
               | A.C (_, A.CRec (_, [A.Field (_, [_], false, _)])) => ()
               | A.C (a, _) => failAt (a, "a `newtype` whose constructor has other than one field, or a strict one")
             val d = deriving ()
           in
             mkD s (A.DNewtype (cx, c, vs, k, d))
           end)
      | T.CLASS =>
          (advance ();
           let
             val (cx, (c, v)) =
               contextThen true (fn () =>
                 let val c = conid "in a class declaration" val v = varid "after the name of a class"
                 in (c, v) end)
             val body = Option.map (List.map checkCdecl) (classBody "the body of a class")
           in
             mkD s (A.DClass (cx, c, v, body))
           end)
      | T.INSTANCE =>
          (advance ();
           let
             val (cx, (c, t)) =
               contextThen true (fn () =>
                 let
                   val c = qtycls "in an instance declaration"
                   val t = atype ()
                 in
                   checkInst t; (c, t)
                 end)
             val body = Option.map (List.map checkIdecl) (classBody "the body of an instance")
           in
             mkD s (A.DInstance (cx, c, t, body))
           end)
      | T.DEFAULT =>
          (advance ();
           expect (T.LPAREN, "after `default`");
           case !cur of
             T.RPAREN => (advance (); mkD s (A.DDefault []))
           | _ => mkD s (A.DDefault (commaList (ty, T.RPAREN, "in a default declaration"))))
      | _ => decl ()
    end

  (* ---- modules ---- *)

  fun subList (name : unit -> A.name) =
    (* at its ( *)
    let val () = advance ()
    in
      case !cur of
        T.DOTDOT => (advance (); expect (T.RPAREN, "after `(..`"); A.SubAll)
      | T.RPAREN => (advance (); A.SubList [])
      | _ => A.SubList (commaList (name, T.RPAREN, "in the list of an entity"))
    end

  fun cname () =
    case !cur of
      T.VARID _ => var ""
    | T.CONID _ => con ""
    | T.LPAREN => (case L.peek 0 of T.CONSYM _ => con "" | _ => var "")
    | _ => expected ("a name", "in the list of an entity")

  fun entity (inExport : bool) : A.entity =
    let val s = mark ()
    in
      case !cur of
        T.MODULE =>
          if inExport then (advance (); mkEnt s (A.EntModule (modid "after `module` in an export list")))
          else fail "`module` in an import list: only an export list names a module"
      | T.CONID c =>
          (advance ();
           let val n = mkName s (q0 c)
           in
             case !cur of
               T.LPAREN => mkEnt s (A.EntType (n, SOME (subList cname)))
             | _ => mkEnt s (A.EntType (n, NONE))
           end)
      | T.QCONID (q, c) =>
          if inExport then
            (advance ();
             let val n = mkName s {qual = q, name = c}
             in
               case !cur of
                 T.LPAREN => mkEnt s (A.EntType (n, SOME (subList cname)))
               | _ => mkEnt s (A.EntType (n, NONE))
             end)
          else fail "a qualified name in an import list"
      | _ =>
          if inExport then mkEnt s (A.EntVar (qvar "in an export list"))
          else mkEnt s (A.EntVar (var "in an import list"))
    end

  fun entityList (inExport : bool) : A.entity list =
    (* at its ( *)
    let
      val ctx = if inExport then "in an export list" else "in an import list"
      val () = advance ()
      fun more acc =
        case !cur of
          T.RPAREN => (advance (); List.rev acc)
        | T.COMMA =>
            (advance ();
             case !cur of
               T.RPAREN => (advance (); List.rev acc)
             | _ => more (entity inExport :: acc))
        | _ => expected ("`,` or `)`", ctx)
    in
      case !cur of
        T.RPAREN => (advance (); [])
      | T.COMMA => (advance (); expect (T.RPAREN, ctx); [])
      | _ => more [entity inExport]
    end

  fun impdecl () : A.import =
    let
      val s = mark ()
      val () = expect (T.IMPORT, "")
      val qualified = case !cur of T.VARID "qualified" => (advance (); true) | _ => false
      val name = modid "after `import`"
      val as_ = case !cur of T.VARID "as" => (advance (); SOME (modid "after `as`")) | _ => NONE
      val hiding = case !cur of T.VARID "hiding" => (advance (); true) | _ => false
      val spec =
        case !cur of
          T.LPAREN => SOME (entityList false)
        | _ => if hiding then expected ("`(`", "after `hiding`") else NONE
    in
      A.Import (ann s, {qualified = qualified, module = name, as_ = as_, hiding = hiding, spec = spec})
    end

  datatype top = TImp of A.import | TDec of A.decl

  fun startsTop t =
    startsDecl t orelse
    (case t of
       T.IMPORT => true | T.TYPE => true | T.DATA => true | T.NEWTYPE => true
     | T.CLASS => true | T.INSTANCE => true | T.DEFAULT => true
     | _ => false)

  fun body () : A.import list * A.decl list =
    let
      fun item () = case !cur of T.IMPORT => TImp (impdecl ()) | _ => TDec (topdecl ())
      val tops = block ("a declaration", "the body of the module", startsTop, item)
      fun split ([], is, ds) = (List.rev is, List.rev ds)
        | split (TImp i :: r, is, []) = split (r, i :: is, [])
        | split (TImp (A.Import (a, _)) :: _, _, _ :: _) = failAt (a, "an import after a declaration of the module")
        | split (TDec d :: r, is, ds) = split (r, is, d :: ds)
    in
      split (tops, [], [])
    end

  (* the end of the input, whose trivia the module's last token holds *)
  fun theEnd () =
    case !cur of
      T.EOF => note (T.EOF, fn () => let val a = L.currentStart () in {trivia = L.trivia (), start = a, stop = a} end)
    | T.RBRACE => fail "a `}` that no `{` opened"
    | _ => expected ("the end of the module", "")

  fun moduleTop () : A.module =
    let val s = mark ()
    in
      case !cur of
        T.MODULE =>
          (advance ();
           let
             val name = modid "after `module`"
             val exports = case !cur of T.LPAREN => SOME (entityList true) | _ => NONE
             val () = expect (T.WHERE, "after the header of the module")
             val (imports, decls) = body ()
           in
             theEnd ();
             A.Module (ann s, {name = SOME name, exports = exports, imports = imports, decls = decls})
           end)
      | T.EOF => (theEnd (); A.Module (ann s, {name = NONE, exports = NONE, imports = [], decls = []}))
      | _ =>
          let val (imports, decls) = body ()
          in theEnd (); A.Module (ann s, {name = NONE, exports = NONE, imports = imports, decls = decls}) end
    end

  fun run ({lexer = {hierarchical}, annotations} : options, f, items, traced) =
    (mode := annotations; file := (if f = "" then "<input>" else f); dotted := hierarchical;
     seq := 0; pending := []; tracing := traced; trace := []; stopArrow := false;
     starts := (case annotations of Bare => Array.array (0, 0) | _ => Array.array (2 * Vector.length items + 64, 0));
     L.start (!file, items);
     let val m = moduleTop ()
     in
       pending := []; starts := Array.array (0, 0);
       (m, List.rev (!trace) before trace := [])
     end)

  fun parse (opts, f, items) = #1 (run (opts, f, items, false))
  fun parseTraced (opts, f, items) = run (opts, f, items, true)

  fun parseFile (opts : options, f, bytes) =
    let
      val text = if HsLiterate.isLiterate f then HsLiterate.unlit (f, bytes) else bytes
    in
      parse (opts, f, HsLexer.tokens (#lexer opts, f, text))
    end
end
