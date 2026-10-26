(* Separate editor parser, initially derived from the batch parser at
   3760da885. Keep differential structural checks when either grammar changes.
   This module owns no global mutable compiler state. *)
structure SyntaxParser =
struct
  open Token Ast
  structure Fixity =
  struct
    open Fixity
    (* Editor parsing records its own dependencies, without mutating Usage. *)
    fun lookup ({table,...}:env,name)=getOpt (StringMap.find (table,name),Nonfix)
    fun isInfix (env,name)=case lookup (env,name) of Nonfix => false | _ => true
  end

  (* Items of an infix expression/pattern before fixity resolution. *)
  datatype 'a item = Atom of 'a | Oper of string * Fixity.fixity * Source.span

  (* Where a declaration list occurs: at top level (topdecs), inside a
     structure-level declaration (strdecs), or inside an expression (core
     decs only). *)
  datatype ctx = Top | Str | Let

  fun parseChunk (toks : Lexer.item vector, initialFixity : Fixity.env,
                  first : int, orPatterns : bool, reuse, remember) =
    let
      val ntoks = Vector.length toks
      val pos = ref first
      val topdecEnds = ref [] : int list ref
      val problems = ref [] : (Source.span * string) list ref
      val problemCount = ref 0
      val fixenv : Fixity.env ref = ref initialFixity
      val groupedPatHeads : bool IntTable.table = IntTable.table 32
      (* the ids of this parse's nodes, in the order it makes them, from a
         count of its own, as this module keeps no state of the compiler's:
         a tree is given the session's ids where it is copied for the
         elaborator (SyntaxAst.copy, CompilerSyntax.bridge) *)
      val nodes = ref 0
      fun freshId () = let val n = !nodes in nodes := n + 1; n end

      fun tokAt i = if i < ntoks then Vector.sub (toks, i) else Vector.sub (toks, ntoks - 1)
      fun peek () = #1 (tokAt (!pos))
      fun peekAt k = #1 (tokAt (!pos + k))
      fun peekSpan () = #2 (tokAt (!pos))
      fun prevSpan () = #2 (tokAt (Int.max (0, !pos - 1)))
      fun advance () = pos := !pos + 1
      fun next () = let val t = peek () in advance (); t end

      fun err msg = Error.error (peekSpan (), msg)
      fun errAt (sp, msg) = Error.error (sp, msg)

      fun expect t =
        if peek () = t then advance ()
        else err ("expected '" ^ toString t ^ "' but found '" ^ toString (peek ()) ^ "'")

      fun spanFrom (start : Source.span) = Source.join (start, prevSpan ())

      fun checkDistinct (names : (string * Source.span) list, what : string) =
        let
          fun go [] = ()
            | go ((n, sp) :: rest) =
              if List.exists (fn (m, _) => m = n) rest then errAt (sp, "duplicate " ^ what ^ " '" ^ n ^ "' in one declaration")
              else go rest
        in go names end

      fun isInfixId s = Fixity.isInfix (!fixenv, s)

      (* ---------------------------------------------------------------- *)
      (* Fixity resolution shared by expressions and patterns.            *)
      (* app: combine two adjacent operands; binop: combine lhs op rhs.  *)
      fun resolve (items : 'a item list, app : 'a * 'a -> 'a,
                   binop : string * Source.span * 'a * 'a -> 'a, what : string) : 'a =
        let
          (* 1. group adjacent atoms into applications *)
          fun group ([], acc) = List.rev acc
            | group (Atom a :: rest, Atom b :: acc) = group (rest, Atom (app (b, a)) :: acc)
            | group (x :: rest, acc) = group (rest, x :: acc)
          val grouped = group (items, [])
          fun operErr (s, sp) = errAt (sp, "infix operator '" ^ s ^ "' used without arguments in " ^ what ^ "; use 'op " ^ s ^ "'")
          (* 2. precedence climbing over alternating operand/operator list *)
          fun climb (lhs, minPrec, rest) =
            case rest of
              Oper (s, fx, sp) :: rest' =>
                if Fixity.precedence fx < minPrec then (lhs, rest)
                else
                  (case rest' of
                     Atom rhs :: rest'' =>
                       let
                         fun loop (rhs, rest) =
                           case rest of
                             Oper (_, fx2, _) :: _ =>
                               let val p2 = Fixity.precedence fx2 and p1 = Fixity.precedence fx
                               in
                                 if p2 > p1 orelse (p2 = p1 andalso Fixity.isRight fx2 andalso Fixity.isRight fx) then
                                   let val (rhs', rest') = climb (rhs, if p2 > p1 then p1 + 1 else p1, rest)
                                   in loop (rhs', rest') end
                                 else (rhs, rest)
                               end
                           | _ => (rhs, rest)
                         val (rhs', rest3) = loop (rhs, rest'')
                       in climb (binop (s, sp, lhs, rhs'), minPrec, rest3) end
                   | Oper (s2, _, sp2) :: _ => operErr (s2, sp2)
                   | [] => operErr (s, sp))
            | Atom _ :: _ => Error.bug "resolve: adjacent atoms after grouping"
            | [] => (lhs, [])
        in
          case grouped of
            [] => err ("expected " ^ what)
          | Oper (s, _, sp) :: _ => operErr (s, sp)
          | Atom a :: rest =>
              (case climb (a, 0, rest) of
                 (r, []) => r
               | (_, Oper (s, _, sp) :: _) => operErr (s, sp)
               | _ => Error.bug "resolve: leftover items")
        end

      (* ---------------------------------------------------------------- *)
      (* Types                                                             *)
      fun parseTy () : ty =
        let
          val start = peekSpan ()
          val t = parseTupleTy ()
        in
          if peek () = ARROW then (advance (); TyArrow (t, parseTy (), spanFrom start, freshId ())) else t
        end

      and parseTupleTy () =
        let
          val start = peekSpan ()
          val t = parseAppTy ()
          fun loop acc =
            if peek () = ID "*" then (advance (); loop (parseAppTy () :: acc)) else List.rev acc
        in
          case loop [t] of
            [t] => t
          | ts => TyTuple (ts, spanFrom start, freshId ())
        end

      and parseAppTy () =
        let
          val start = peekSpan ()
          fun loop t =
            case peek () of
              ID s => if s = "*" then t else (advance (); loop (TyCon ([t], ([], s), spanFrom start, freshId ())))
            | LONGID (p, s) => (advance (); loop (TyCon ([t], (p, s), spanFrom start, freshId ())))
            | _ => t
        in
          loop (parseAtTy ())
        end

      and parseAtTy () =
        let val start = peekSpan ()
        in
          case peek () of
            TYVAR v => (advance (); TyVar (v, start, freshId ()))
          | ID s => if s = "*" then err "expected type" else (advance (); TyCon ([], ([], s), start, freshId ()))
          | LONGID (p, s) => (advance (); TyCon ([], (p, s), start, freshId ()))
          | PRIM =>
              (* `_prim "name"` as a type: a type of the VM's that has no
                 name in the initial basis (Int64.int, Word64.word) *)
              (advance ();
               case next () of
                 STRING s => TyCon ([], ([], "_" ^ s), spanFrom start, freshId ())
               | _ => err "expected string literal after _prim")
          | LBRACE =>
              let
                val () = advance ()
                fun field () =
                  let val lsp = peekSpan () val lab = parseLabel ()
                  in expect COLON; (lab, parseTy (), lsp) end
                fun loop acc =
                  if peek () = RBRACE then List.rev acc
                  else let val f = field ()
                       in if peek () = COMMA then (advance (); loop (f :: acc)) else List.rev (f :: acc) end
                val fields = loop []
              in expect RBRACE; TyRecord (fields, spanFrom start, freshId ()) end
          | LPAREN =>
              let
                val () = advance ()
                val t = parseTy ()
              in
                if peek () = COMMA then
                  let
                    fun loop acc = if peek () = COMMA then (advance (); loop (parseTy () :: acc)) else List.rev acc
                    val ts = loop [t]
                    val () = expect RPAREN
                    val con = case next () of
                                ID s => ([], s)
                              | LONGID (p, s) => (p, s)
                              | _ => err "expected type constructor after type argument list"
                  in TyCon (ts, con, spanFrom start, freshId ()) end
                else (expect RPAREN; t)
              end
          | _ => err ("expected type but found '" ^ toString (peek ()) ^ "'")
        end

      and parseLabel () : string =
        case next () of
          ID s => if CharVector.all (fn c => Char.ord c < 128) s then s
                  else errAt (prevSpan (), "a record label is ASCII, and " ^ s ^ " is not")
        | INT i => if IntInf.> (i, IntInf.fromInt 0) then IntInf.toString i else err "record label must be a positive integer"
        | t => errAt (prevSpan (), "expected record label but found '" ^ toString t ^ "'")

      (* a sequence of type variables, each with its span *)
      fun parseTyvarSeq () : (string * Source.span) list =
        let
          val start = peekSpan ()
          val vs =
            case peek () of
              TYVAR v => (advance (); [(v, prevSpan ())])
            | LPAREN =>
                (case peekAt 1 of
                   TYVAR _ =>
                     let
                       val () = advance ()
                       fun loop acc =
                         case next () of
                           TYVAR v => let val v = (v, prevSpan ())
                                      in if peek () = COMMA then (advance (); loop (v :: acc)) else List.rev (v :: acc) end
                         | _ => err "expected type variable"
                       val vs = loop []
                     in expect RPAREN; vs end
                 | _ => [])
            | _ => []
          (* Section 2.9: no tyvarseq may contain the same type variable twice *)
          fun dups [] = ()
            | dups ((v, _) :: rest) =
              if List.exists (fn (w, _) => w = v) rest then errAt (start, "duplicate type variable " ^ v ^ " in type variable sequence")
              else dups rest
        in dups vs; vs end

      (* ---------------------------------------------------------------- *)
      (* Patterns                                                          *)
      fun startsAtPat t =
        case t of
          UNDERSCORE => true | INT _ => true | WORD _ => true | STRING _ => true | WIDESTRING _ => true | CHAR _ => true
        | REAL _ => true | ID _ => true | LONGID _ => true | OP => true | LBRACE => true
        | LPAREN => true | LBRACKET => true | _ => false

      fun parsePat () : pat =
        let
          val start = peekSpan ()
          val p = parseInfPat ()
          fun typed p = if peek () = COLON then (advance (); typed (PTyped (p, parseTy (), spanFrom start, freshId ()))) else p
          val p = typed p
        in
          if peek () = AS then
            let
              val () = advance ()
              fun asVar (PVar (([], v), _, _, _)) = SOME (v, NONE)
                | asVar (PTyped (PVar (([], v), _, _, _), t, _, _)) = SOME (v, SOME t)
                | asVar _ = NONE
            in
              case asVar p of
                SOME (v, t) => PLayered (v, t, parsePat (), ref NONE, spanFrom start, freshId ())
              | NONE => errAt (spanOfPat p, "left side of 'as' must be a variable")
            end
          else p
        end

      and parseInfPat () : pat =
        let
          fun collect acc =
            case peek () of
              ID s =>
                if isInfixId s then
                  let val sp = peekSpan ()
                  in advance (); collect (Oper (s, Fixity.lookup (!fixenv, s), sp) :: acc) end
                else collect (Atom (parseAtPat ()) :: acc)
            | t => if startsAtPat t then collect (Atom (parseAtPat ()) :: acc) else List.rev acc
          val items = collect []
          fun app (f, a) =
            case f of
              PVar (id, _, sp, _) =>
                if Option.isSome (IntTable.find (groupedPatHeads, #start sp)) then
                  errAt (sp, "only an unparenthesized constructor identifier can be applied in a pattern")
                else PApp (id, ref NONE, a, Source.join (sp, spanOfPat a), freshId ())
            | _ => errAt (spanOfPat f, "only a constructor can be applied in a pattern")
          fun binop (s, sp, l, r) =
            PApp (([], s), ref NONE, PTuple ([l, r], Source.join (spanOfPat l, spanOfPat r), freshId ()),
                  Source.join (spanOfPat l, spanOfPat r), freshId ())
        in
          resolve (items, app, binop, "pattern")
        end

      and parseAtPat () : pat =
        let val start = peekSpan ()
        in
          case peek () of
            UNDERSCORE => (advance (); PWild (start, freshId ()))
          | INT i => (advance (); PScon (SInt i, ref NONE, start, freshId ()))
          | WORD w => (advance (); PScon (SWord w, ref NONE, start, freshId ()))
          | STRING s => (advance (); PScon (SString s, ref NONE, start, freshId ()))
          | WIDESTRING s => (advance (); PScon (SWideString s, ref NONE, start, freshId ()))
          | CHAR c => (advance (); PScon (SChar c, ref NONE, start, freshId ()))
          | REAL _ => err "real constants are not allowed in patterns"
          | ID s => (advance (); PVar (([], s), ref NONE, start, freshId ()))
          | LONGID (p, s) => (advance (); PVar ((p, s), ref NONE, start, freshId ()))
          | OP =>
              (advance ();
               case next () of
                 ID s => PVar (([], s), ref NONE, spanFrom start, freshId ())
               | LONGID (p, s) => PVar ((p, s), ref NONE, spanFrom start, freshId ())
               | EQUALS => PVar (([], "="), ref NONE, spanFrom start, freshId ())
               | _ => err "expected identifier after 'op'")
          | LBRACE =>
              let
                val () = advance ()
                fun field () =
                  case peek () of
                    DOTS => (advance (); NONE)
                  | _ =>
                    let
                      val fstart = peekSpan ()
                      val lab = parseLabel ()
                    in
                      if peek () = EQUALS then (advance (); SOME (lab, parsePat (), fstart))
                      else
                        let
                          val tyopt = if peek () = COLON then (advance (); SOME (parseTy ())) else NONE
                          val var = case tyopt of
                                      NONE => PVar (([], lab), ref NONE, fstart, freshId ())
                                    | SOME t => PTyped (PVar (([], lab), ref NONE, fstart, freshId ()), t, spanFrom fstart, freshId ())
                        in
                          if peek () = AS then (advance (); SOME (lab, PLayered (lab, tyopt, parsePat (), ref NONE, spanFrom fstart, freshId ()), fstart))
                          else SOME (lab, var, fstart)
                        end
                    end
                fun loop (acc, flex) =
                  if peek () = RBRACE then (List.rev acc, flex)
                  else
                    case field () of
                      NONE => if peek () = RBRACE then (List.rev acc, true) else err "'...' must be the last field of a record pattern"
                    | SOME f => if peek () = COMMA then (advance (); loop (f :: acc, flex)) else (List.rev (f :: acc), flex)
                val (fields, flex) = loop ([], false)
              in
                expect RBRACE; PRecord (fields, flex, ref NONE, spanFrom start, freshId ())
              end
          | LPAREN =>
              let val () = advance ()
              in
                if peek () = RPAREN then (advance (); PTuple ([], spanFrom start, freshId ()))
                else
                  let val p = parsePat ()
                  in
                    if peek () = COMMA then
                      let fun loop acc = if peek () = COMMA then (advance (); loop (parsePat () :: acc)) else List.rev acc
                          val ps = loop [p]
                      in expect RPAREN; PTuple (ps, spanFrom start, freshId ()) end
                    else if peek () = BAR then
                      if not (orPatterns) then err "or-patterns (p1 | p2) are not Standard ML; --or-patterns allows them"
                      else
                        let fun loop acc = if peek () = BAR then (advance (); loop (parsePat () :: acc)) else List.rev acc
                            val ps = loop [p]
                        in expect RPAREN; POr (ps, spanFrom start, freshId ()) end
                    else (expect RPAREN;
                          (case p of PVar (_, _, sp, _) => IntTable.insert (groupedPatHeads, #start sp, true) | _ => ()); p)
                  end
              end
          | LBRACKET =>
              let val () = advance ()
              in
                if peek () = RBRACKET then (advance (); PList ([], spanFrom start, freshId ()))
                else
                  let fun loop acc = if peek () = COMMA then (advance (); loop (parsePat () :: acc)) else List.rev acc
                      val ps = loop [parsePat ()]
                  in expect RBRACKET; PList (ps, spanFrom start, freshId ()) end
              end
          | t => err ("expected pattern but found '" ^ toString t ^ "'")
        end

      (* ---------------------------------------------------------------- *)
      (* Expressions                                                       *)
      fun isPrefixStart t =
        case t of RAISE => true | IF => true | WHILE => true | CASE => true | FN => true | _ => false

      fun startsAtExp t =
        case t of
          INT _ => true | WORD _ => true | REAL _ => true | STRING _ => true | WIDESTRING _ => true | CHAR _ => true
        | ID _ => true | LONGID _ => true | OP => true | LBRACE => true | HASH => true
        | LPAREN => true | LBRACKET => true | LET => true | PRIM => true | EQUALS => true
        | _ => false

      fun parseExp () : exp =
        let val start = peekSpan ()
        in
          case peek () of
            RAISE => (advance (); let val e = parseExp () in ERaise (e, spanFrom start, freshId ()) end)
          | IF =>
              let
                val () = advance ()
                val c = parseExp ()
                val () = expect THEN
                val t = parseExp ()
                val () = expect ELSE
                val e = parseExp ()
              in EIf (c, t, e, spanFrom start, freshId ()) end
          | WHILE =>
              let
                val () = advance ()
                val c = parseExp ()
                val () = expect DO
                val b = parseExp ()
              in EWhile (c, b, spanFrom start, freshId ()) end
          | CASE =>
              let
                val () = advance ()
                val e = parseExp ()
                val () = expect OF
                val m = parseMatch ()
              in ECase (e, m, spanFrom start, freshId ()) end
          | FN => (advance (); let val m = parseMatch () in EFn (m, ref NONE, spanFrom start, freshId ()) end)
          | _ => parseHandleExp ()
        end

      and parseMatch () : mrule list =
        let
          fun rule () =
            let val p = parsePat ()
            in expect DARROW; (p, parseExp ()) end
          fun loop acc = if peek () = BAR then (advance (); loop (rule () :: acc)) else List.rev acc
        in loop [rule ()] end

      and parseHandleExp () =
        if isPrefixStart (peek ()) then parseExp ()
        else
          let
            val start = peekSpan ()
            val e = parseOrelseExp ()
          in
            if peek () = HANDLE then (advance (); EHandle (e, parseMatch (), spanFrom start, freshId ())) else e
          end

      and parseOrelseExp () =
        if isPrefixStart (peek ()) then parseExp ()
        else
          let
            val start = peekSpan ()
            fun loop e =
              if peek () = ORELSE then (advance (); loop (EOrelse (e, parseAndalsoExp (), spanFrom start, freshId ()))) else e
          in loop (parseAndalsoExp ()) end

      and parseAndalsoExp () =
        if isPrefixStart (peek ()) then parseExp ()
        else
          let
            val start = peekSpan ()
            fun loop e =
              if peek () = ANDALSO then (advance (); loop (EAndalso (e, parseTypedExp (), spanFrom start, freshId ()))) else e
          in loop (parseTypedExp ()) end

      and parseTypedExp () =
        if isPrefixStart (peek ()) then parseExp ()
        else
          let
            val start = peekSpan ()
            fun loop e =
              if peek () = COLON then (advance (); loop (ETyped (e, parseTy (), spanFrom start, freshId ()))) else e
          in loop (parseInfExp ()) end

      and parseInfExp () : exp =
        let
          fun collect acc =
            case peek () of
              ID s =>
                if isInfixId s then
                  let val sp = peekSpan ()
                  in advance (); collect (Oper (s, Fixity.lookup (!fixenv, s), sp) :: acc) end
                else collect (Atom (parseAtExp ()) :: acc)
            | EQUALS =>
                let val sp = peekSpan ()
                in advance (); collect (Oper ("=", Fixity.lookup (!fixenv, "="), sp) :: acc) end
            | t => if startsAtExp t then collect (Atom (parseAtExp ()) :: acc) else List.rev acc
          val items = collect []
          fun app (f, a) = EApp (f, a, Source.join (spanOfExp f, spanOfExp a), freshId ())
          fun binop (s, sp, l, r) =
            let val whole = Source.join (spanOfExp l, spanOfExp r)
            in EApp (EVar (([], s), ref NONE, sp, freshId ()), ETuple ([l, r], whole, freshId ()), whole, freshId ()) end
        in
          resolve (items, app, binop, "expression")
        end

      and parseAtExp () : exp =
        let val start = peekSpan ()
        in
          case peek () of
            INT i => (advance (); EScon (SInt i, ref NONE, start, freshId ()))
          | WORD w => (advance (); EScon (SWord w, ref NONE, start, freshId ()))
          | REAL r => (advance (); EScon (SReal r, ref NONE, start, freshId ()))
          | STRING s => (advance (); EScon (SString s, ref NONE, start, freshId ()))
          | WIDESTRING s => (advance (); EScon (SWideString s, ref NONE, start, freshId ()))
          | CHAR c => (advance (); EScon (SChar c, ref NONE, start, freshId ()))
          | ID s => (advance (); EVar (([], s), ref NONE, start, freshId ()))
          | LONGID (p, s) => (advance (); EVar ((p, s), ref NONE, start, freshId ()))
          | EQUALS => err "infix operator '=' used without arguments; use 'op ='"
          | OP =>
              (advance ();
               case next () of
                 ID s => EVar (([], s), ref NONE, spanFrom start, freshId ())
               | LONGID (p, s) => EVar ((p, s), ref NONE, spanFrom start, freshId ())
               | EQUALS => EVar (([], "="), ref NONE, spanFrom start, freshId ())
               | _ => err "expected identifier after 'op'")
          | LBRACE =>
              let
                val () = advance ()
                fun field () =
                  let val lsp = peekSpan () val lab = parseLabel ()
                  in expect EQUALS; (lab, parseExp (), lsp) end
                fun loop acc =
                  if peek () = RBRACE then List.rev acc
                  else let val f = field ()
                       in if peek () = COMMA then (advance (); loop (f :: acc)) else List.rev (f :: acc) end
                val fields = loop []
              in
                expect RBRACE;
                (case fields of [] => ETuple ([], spanFrom start, freshId ()) | _ => ERecord (fields, spanFrom start, freshId ()))
              end
          | HASH =>
              let
                val () = advance ()
                val lab = parseLabel ()
              in ESelect (lab, ref NONE, spanFrom start, freshId ()) end
          | LPAREN =>
              let val () = advance ()
              in
                if peek () = RPAREN then (advance (); ETuple ([], spanFrom start, freshId ()))
                else
                  let val e = parseExp ()
                  in
                    case peek () of
                      COMMA =>
                        let fun loop acc = if peek () = COMMA then (advance (); loop (parseExp () :: acc)) else List.rev acc
                            val es = loop [e]
                        in expect RPAREN; ETuple (es, spanFrom start, freshId ()) end
                    | SEMI =>
                        let fun loop acc = if peek () = SEMI then (advance (); loop (parseExp () :: acc)) else List.rev acc
                            val es = loop [e]
                        in expect RPAREN; ESeq (es, spanFrom start, freshId ()) end
                    | _ => (expect RPAREN; e)
                  end
              end
          | LBRACKET =>
              let val () = advance ()
              in
                if peek () = RBRACKET then (advance (); EList ([], ref NONE, spanFrom start, freshId ()))
                else
                  let fun loop acc = if peek () = COMMA then (advance (); loop (parseExp () :: acc)) else List.rev acc
                      val es = loop [parseExp ()]
                  in expect RBRACKET; EList (es, ref NONE, spanFrom start, freshId ()) end
              end
          | LET =>
              let
                val () = advance ()
                val saved = !fixenv
                val decs = parseDecs Let
                val () = expect IN
                val e = parseExp ()
                fun loop acc = if peek () = SEMI then (advance (); loop (parseExp () :: acc)) else List.rev acc
                val es = loop [e]
                val () = expect END
                val () = fixenv := saved
                val body = case es of [e] => e | _ => ESeq (es, spanFrom start, freshId ())
              in ELet (decs, body, spanFrom start, freshId ()) end
          | PRIM =>
              let
                val () = advance ()
                val name = case next () of STRING s => s | _ => err "expected string literal after _prim"
                val () = expect COLON
                val t = parseTy ()
              in EPrim (name, t, ref NONE, spanFrom start, freshId ()) end
          | t => err ("expected expression but found '" ^ toString t ^ "'")
        end

      (* ---------------------------------------------------------------- *)
      (* Declarations                                                      *)
      and parseDecs (ctx : ctx) : dec list =
        let
          (* at the top level, a `;` or the end ends a topdec *)
          fun ends (d :: _) =
                if ctx = Top then
                  topdecEnds:= #stop (spanOfDec d) :: !topdecEnds
                else ()
            | ends [] = ()
          fun endsAtBoundary acc=if peek ()=SEMI orelse peek ()=EOF then ends acc else ()
          fun declaration token=case token of
            VAL => true | FUN => true | TYPE => true | DATATYPE => true | ABSTYPE => true
          | EXCEPTION => true | LOCAL => true | OPEN => true | INFIX => true | INFIXR => true
          | NONFIX => true | STRUCTURE => true | SIGNATURE => true | FUNCTOR => true
          | OVERLOAD => true | EXPORT => true | _ => false
          (* Restart at a declaration in this lexical scope; nested scopes and
             delimiters are skipped. An unmatched opener can consume to EOF,
             which is preferable to inventing a successfully parsed binding. *)
          fun recoverFrom start =
            let fun opens token=case token of LPAREN => true | LBRACKET => true | LBRACE => true
                  | LET => true | LOCAL => true | STRUCT => true | SIG => true | ABSTYPE => true | _ => false
                fun closes token=case token of RPAREN => true | RBRACKET => true | RBRACE => true | END => true | _ => false
                fun scan (i,depth)=
                  let val token= #1 (tokAt i)
                  in if token=EOF then pos:=i
                     else if i>start andalso depth=0 andalso
                       (declaration token orelse token=SEMI orelse token=IN orelse closes token) then pos:=i
                     else scan (i+1,if opens token then depth+1 else if closes token then Int.max (0,depth-1) else depth) end
            in scan (start,0) end
          fun loop acc =
            case peek () of
              SEMI => (ends acc; advance (); loop acc)
            | IN => List.rev acc
            | END => List.rev acc
            | RPAREN => List.rev acc
            | EOF => (ends acc; List.rev acc)
            | _ => if ctx=Top andalso not (null acc) then (endsAtBoundary acc;List.rev acc) else
                let val start= !pos
                    val incoming= !fixenv
                    val beforeProblems= !problemCount
                    fun fresh () =
                      let val dec=parseDec ctx
                          val ()=if !problemCount=beforeProblems then remember (ctx,start,!pos,incoming,!fixenv,dec) else ()
                      in dec end
                    val parsed=(SOME (case reuse (ctx,start,incoming) of
                        SOME (dec,outgoing,next) => (pos:=next;fixenv:=outgoing;dec)
                      | NONE => fresh ())) handle Error.CompileError problem =>
                      (problems:=problem :: !problems;problemCount:= !problemCount+1;
                       fixenv:=incoming;recoverFrom start;NONE)
                in case parsed of SOME dec => loop (dec :: acc)
                 | NONE => if ctx=Top then List.rev acc else loop acc end
        in loop [] end

      and parseDec (ctx : ctx) : dec =
        let val start = peekSpan ()
        in
          case peek () of
            VAL =>
              let
                val () = advance ()
                val tvs = parseTyvarSeq ()
                fun skipRecs () = if peek () = REC then (advance (); skipRecs (); true) else false
                val isRec = skipRecs ()
                fun bind () =
                  let val p = parsePat ()
                  in expect EQUALS; (p, parseExp ()) end
                (* valbind ::= pat = exp <and valbind> | rec valbind: a `rec` after
                   `and` makes the rest of the bindings recursive *)
                val first = bind ()
                val plain = ref [first]
                val recs = ref []
                fun collect () =
                  if peek () = AND then
                    (advance ();
                     if peek () = REC orelse not (List.null (!recs)) then
                       (ignore (skipRecs ()); recs := bind () :: !recs)
                     else plain := bind () :: !plain;
                     collect ())
                  else ()
                val () = collect ()
                val plainBinds = List.rev (!plain)
                val recBinds = List.rev (!recs)
                val sp = spanFrom start
                (* val pat = exp and rec valbind: the recursive bindings are
                   elaborated before the others (they see the outer environment),
                   then both are exported *)
                fun recVars p =
                  case recBindVars p of
                    SOME (vs, _) => List.map (fn (v, _, vsp) => (v, vsp)) vs
                  | NONE => errAt (spanOfPat p, "val rec requires a variable on the left-hand side")
                val reexport =
                  List.map (fn (v, vsp) => (PVar (([], v), ref NONE, vsp, freshId ()), EVar (([], v), ref NONE, vsp, freshId ())))
                           (List.concat (List.map (fn (p, _) => recVars p) recBinds))
              in
                if isRec then DValRec (tvs, plainBinds @ recBinds, sp, freshId ())
                else if List.null recBinds then DVal (tvs, plainBinds, sp, freshId ())
                else DLocal ([DValRec (tvs, recBinds, sp, freshId ())], [DVal (tvs, plainBinds @ reexport, sp, freshId ())], sp, freshId ())
              end
          | FUN =>
              let
                val () = advance ()
                val tvs = parseTyvarSeq ()
                fun loop acc = if peek () = AND then (advance (); loop (parseFundef () :: acc)) else List.rev acc
                val fs = loop [parseFundef ()]
              in DFun (tvs, fs, spanFrom start, freshId ()) end
          | TYPE => (advance (); DType (parseTypbinds (), spanFrom start, freshId ()))
          | DATATYPE =>
              let val () = advance ()
              in
                if peekAt 1 = EQUALS andalso peekAt 2 = DATATYPE then
                  let
                    val name = case next () of ID s => s | _ => err "expected type constructor name"
                    val () = expect EQUALS
                    val () = expect DATATYPE
                    val rhs = case next () of
                                ID s => ([], s)
                              | LONGID (p, s) => (p, s)
                              | _ => err "expected type constructor"
                  in DDatatypeRepl (name, rhs, spanFrom start, freshId ()) end
                else
                  let
                    fun loop acc = if peek () = AND then (advance (); loop (parseDatbind () :: acc)) else List.rev acc
                    val dbs = loop [parseDatbind ()]
                    val tbs = if peek () = WITHTYPE then (advance (); parseTypbinds ()) else []
                  in DDatatype (dbs, tbs, spanFrom start, freshId ()) end
              end
          | EXCEPTION =>
              let
                val () = advance ()
                fun exbind () =
                  let
                    val estart = peekSpan ()
                    val () = if peek () = OP then advance () else ()
                    val name = case next () of ID s => s | _ => err "expected exception constructor name"
                  in
                    case peek () of
                      OF => (advance (); ExnDecl (name, SOME (parseTy ()), ref NONE, spanFrom estart, freshId ()))
                    | EQUALS =>
                        (advance ();
                         if peek () = OP then advance () else ();
                         case next () of
                           ID s => ExnRepl (name, ([], s), ref NONE, spanFrom estart, freshId ())
                         | LONGID (p, s) => ExnRepl (name, (p, s), ref NONE, spanFrom estart, freshId ())
                         | _ => err "expected exception constructor")
                    | _ => ExnDecl (name, NONE, ref NONE, spanFrom estart, freshId ())
                  end
                fun loop acc = if peek () = AND then (advance (); loop (exbind () :: acc)) else List.rev acc
              in DException (loop [exbind ()], spanFrom start, freshId ()) end
          | LOCAL =>
              let
                val () = advance ()
                val inner = case ctx of Top => Str | c => c
                val env0 = !fixenv
                val d1 = parseDecs inner
                val () = expect IN
                val env1 = !fixenv
                val d2 = parseDecs inner
                val () = expect END
                val env2 = !fixenv
                (* keep fixity directives from d2 but drop those from d1 *)
                val () = fixenv := Fixity.afterLocal (env0, env1, env2)
              in DLocal (d1, d2, spanFrom start, freshId ()) end
          | OPEN =>
              let
                val () = advance ()
                fun loop acc =
                  case peek () of
                    ID s => (advance (); loop (([], s) :: acc))
                  | LONGID (p, s) => (advance (); loop ((p, s) :: acc))
                  | _ => List.rev acc
                val ids = loop []
              in
                case ids of [] => err "expected structure name after 'open'" | _ => DOpen (ids, spanFrom start, freshId ())
              end
          | INFIX => parseFixityDec (start, fn p => Fixity.Infix p, fn (p, ids, sp) => DInfix (p, ids, sp, freshId ()))
          | INFIXR => parseFixityDec (start, fn p => Fixity.Infixr p, fn (p, ids, sp) => DInfixr (p, ids, sp, freshId ()))
          | NONFIX =>
              let
                val () = advance ()
                val ids = parseFixityIds ()
                val () = fixenv := Fixity.extend (!fixenv, List.map (fn id => (id, Fixity.Nonfix)) ids)
              in DNonfix (ids, spanFrom start, freshId ()) end
          | OVERLOAD =>
              (* _overload <kind> <longstrid> [<bits> | via <longvid>] *)
              let
                val () = advance ()
                val kind = case next () of
                             ID s => s
                           | _ => err "expected a kind (int, word, real, char or string) after _overload"
                val strid = case next () of
                              ID s => [s]
                            | LONGID (p, s) => p @ [s]
                            | _ => err "expected a structure name in _overload"
                val literal =
                  case peek () of
                    INT i => (advance (); OvBits (IntInf.toInt i))
                  | ID "via" =>
                      (advance ();
                       case next () of
                         ID s => OvVia ([], s)
                       | LONGID (p, s) => OvVia (p, s)
                       | _ => err "expected a function name after via")
                  | _ => OvBits 64
              in DOverload {kind = kind, strid = strid, literal = literal, span = spanFrom start, id = freshId ()} end
          (* _export structure Name : SIG = strexp: a dynamic module's
             implementation (docs/units.md, Dynamic modules) *)
          | EXPORT =>
              if ctx <> Top then err "_export declares a structure at the top level only"
              else
                let
                  val () = advance ()
                  val () = expect STRUCTURE
                  val name = case next () of ID s => s | _ => err "expected structure name"
                  val () = expect COLON
                  val sg = parseSigexp ()
                  val () = expect EQUALS
                  val body = parseStrexp ()
                in
                  DStructure ([{name = name, strexp = StrExport (name, sg, body, ref NONE, spanFrom start, freshId ()), span = spanFrom start,
                                id = freshId ()}],
                              spanFrom start, freshId ())
                end
          | STRUCTURE =>
              if ctx = Let then err "structure declarations are not allowed inside expressions"
              else
                let
                  val () = advance ()
                  fun bind () : strbind =
                    let
                      val bstart = peekSpan ()
                      val name = case next () of ID s => s | _ => err "expected structure name"
                      val ascription =
                        case peek () of
                          COLON => (advance (); SOME (parseSigexp (), false))
                        | COLONGT => (advance (); SOME (parseSigexp (), true))
                        | _ => NONE
                      val () = expect EQUALS
                      (* structure S = _virtual : SIG, a virtual module: its
                         implementation is the module of the program that
                         exports S (docs/build.md, Virtual modules) *)
                      val body =
                        if peek () = VIRTUAL then
                          let val vstart = peekSpan ()
                              val () = advance ()
                              val () = expect COLON
                          in StrDynamic (DynamicVirtual name, parseSigexp (), ref NONE, spanFrom vstart, freshId ()) end
                        else parseStrexp ()
                      (* derived forms: structure S : SIG = e  ==>  structure S = e : SIG  (and :>) *)
                      val body = case ascription of
                                   NONE => body
                                 | SOME (sg, opaque) => StrAscribe (body, sg, opaque, spanFrom bstart, freshId ())
                    in {name = name, strexp = body, span = spanFrom bstart, id = freshId ()} end
                  fun loop acc = if peek () = AND then (advance (); loop (bind () :: acc)) else List.rev acc
                  val binds = loop [bind ()]
                in
                  checkDistinct (List.map (fn b : strbind => (#name b, #span b)) binds, "structure");
                  DStructure (binds, spanFrom start, freshId ())
                end
          | SIGNATURE =>
              if ctx <> Top then err "signature declarations are only allowed at top level"
              else
                let
                  val () = advance ()
                  fun bind () : sigbind =
                    let
                      val bstart = peekSpan ()
                      val name = case next () of ID s => s | _ => err "expected signature name"
                      val () = expect EQUALS
                      val sg = parseSigexp ()
                    in {name = name, sigexp = sg, span = spanFrom bstart, id = freshId ()} end
                  fun loop acc = if peek () = AND then (advance (); loop (bind () :: acc)) else List.rev acc
                  val binds = loop [bind ()]
                in
                  checkDistinct (List.map (fn b : sigbind => (#name b, #span b)) binds, "signature");
                  DSignature (binds, spanFrom start, freshId ())
                end
          | FUNCTOR =>
              if ctx <> Top then err "functor declarations are only allowed at top level"
              else
                let
                  val () = advance ()
                  fun bind () : funbind =
                    let
                      val bstart = peekSpan ()
                      val name = case next () of ID s => s | _ => err "expected functor name"
                      val () = expect LPAREN
                      val (param, paramSig) =
                        case (peek (), peekAt 1) of
                          (ID s, COLON) => (advance (); advance (); (SOME s, parseSigexp ()))
                        | _ =>
                          (* derived form: functor F (spec) = e  ==>  functor F (X : sig spec end) = let open X in e end *)
                          let
                            val sstart = peekSpan ()
                            val specs = parseSpecs ()
                          in (NONE, SigSig (specs, spanFrom sstart, freshId ())) end
                      val () = expect RPAREN
                      val result =
                        case peek () of
                          COLON => (advance (); SOME (parseSigexp (), false))
                        | COLONGT => (advance (); SOME (parseSigexp (), true))
                        | _ => NONE
                      val () = expect EQUALS
                      val body = parseStrexp ()
                      (* derived form: functor F (X : S) : R = e  ==>  functor F (X : S) = e : R *)
                      val body = case result of
                                   NONE => body
                                 | SOME (sg, opaque) => StrAscribe (body, sg, opaque, spanFrom bstart, freshId ())
                    in {name = name, param = param, paramSig = paramSig, body = body, span = spanFrom bstart, id = freshId ()} end
                  fun loop acc = if peek () = AND then (advance (); loop (bind () :: acc)) else List.rev acc
                  val binds = loop [bind ()]
                in
                  checkDistinct (List.map (fn b : funbind => (#name b, #span b)) binds, "functor");
                  DFunctor (binds, spanFrom start, freshId ())
                end
          | ABSTYPE =>
              let
                val () = advance ()
                fun loop acc = if peek () = AND then (advance (); loop (parseDatbind () :: acc)) else List.rev acc
                val dbs = loop [parseDatbind ()]
                val tbs = if peek () = WITHTYPE then (advance (); parseTypbinds ()) else []
                val () = expect WITH
                val saved = !fixenv
                val decs = parseDecs Let
                val () = expect END
                val () = fixenv := saved
              in DAbstype (dbs, tbs, decs, spanFrom start, freshId ()) end
          | t =>
              if ctx = Top andalso (startsAtExp t orelse isPrefixStart t) then
                (* derived form of programs (Appendix A):  exp ;  ==>  val it = exp ; *)
                let val e = parseExp ()
                in DVal ([], [(PVar (([], "it"), ref NONE, spanOfExp e, freshId ()), e)], spanFrom start, freshId ()) end
              else err ("expected declaration but found '" ^ toString t ^ "'")
        end

      (* ---------------------------------------------------------------- *)
      (* Modules                                                           *)
      and parseStrexp () : strexp =
        let
          val start = peekSpan ()
          val e =
            case peek () of
              STRUCT =>
                let
                  val () = advance ()
                  val saved = !fixenv
                  val decs = parseDecs Str
                  val () = expect END
                  val () = fixenv := saved
                in StrStruct (decs, spanFrom start, freshId ()) end
            | LET =>
                let
                  val () = advance ()
                  val saved = !fixenv
                  val decs = parseDecs Str
                  val () = expect IN
                  val body = parseStrexp ()
                  val () = expect END
                  val () = fixenv := saved
                in StrLet (decs, body, spanFrom start, freshId ()) end
            | ID s =>
                if peekAt 1 = LPAREN then
                  let
                    val () = advance ()
                    val () = advance ()
                    val arg = parseFunctorArg ()
                    val () = expect RPAREN
                  in StrApp (s, arg, spanFrom start, freshId ()) end
                else (advance (); StrId (([], s), start, freshId ()))
            | LONGID (p, s) => (advance (); StrId ((p, s), start, freshId ()))
            (* _dynamic "path" : SIG, a structure loaded when the program runs
               (docs/units.md, Dynamic modules) *)
            | DYNAMIC =>
                let
                  val () = advance ()
                  val path = case peek () of
                               STRING s => (advance (); s)
                             | t => err ("expected the path of a dynamic module but found '" ^ toString t ^ "'")
                  val () = expect COLON
                in StrDynamic (DynamicFile path, parseSigexp (), ref NONE, spanFrom start, freshId ()) end
            | t => err ("expected structure expression but found '" ^ toString t ^ "'")
          fun ascribe e =
            case peek () of
              COLON => (advance (); ascribe (StrAscribe (e, parseSigexp (), false, spanFrom start, freshId ())))
            | COLONGT => (advance (); ascribe (StrAscribe (e, parseSigexp (), true, spanFrom start, freshId ())))
            | _ => e
        in ascribe e end

      (* The argument of a functor application: a structure expression, or
         the derived form  funid ( strdec )  ==>  funid ( struct strdec end ). *)
      and parseFunctorArg () : strexp =
        let val start = peekSpan ()
        in
          case peek () of
            STRUCT => parseStrexp ()
          | LET => parseStrexp ()
          | ID _ => parseStrexp ()
          | LONGID _ => parseStrexp ()
          | _ =>
              let
                val saved = !fixenv
                val decs = parseDecs Str
                val () = fixenv := saved
              in StrStruct (decs, spanFrom start, freshId ()) end
        end

      and parseSigexp () : sigexp =
        let
          val start = peekSpan ()
          val sg =
            case peek () of
              SIG =>
                let
                  val () = advance ()
                  val specs = parseSpecs ()
                  val () = expect END
                in SigSig (specs, spanFrom start, freshId ()) end
            | ID n => (advance (); SigId (n, start, freshId ()))
            | t => err ("expected signature expression but found '" ^ toString t ^ "'")
        in parseWhere (sg, start) end

      (* sigexp where type tyvarseq longtycon = ty <and type ...> *)
      and parseWhere (sg : sigexp, start) : sigexp =
        if peek () = WHERE then
          let
            val () = advance ()
            fun clause () =
              let
                val cstart = peekSpan ()
                val () = expect TYPE
                val tvs = List.map #1 (parseTyvarSeq ())
                val id = case next () of
                           ID n => ([], n)
                         | LONGID (p, n) => (p, n)
                         | _ => err "expected type constructor after 'where type'"
                val () = expect EQUALS
                val t = parseTy ()
              in (tvs, id, t, spanFrom cstart) end
            fun loop acc =
              if peek () = AND andalso peekAt 1 = TYPE then (advance (); loop (clause () :: acc)) else List.rev acc
            val clauses = loop [clause ()]
          in parseWhere (SigWhere (sg, clauses, spanFrom start, freshId ()), start) end
        else sg

      and parseSpecs () : spec list =
        let
          fun loop acc =
            case peek () of
              SEMI => (advance (); loop acc)
            | END => List.rev acc
            | RPAREN => List.rev acc
            | EOF => List.rev acc
            | SHARING =>
                let
                  val start = peekSpan ()
                  val () = advance ()
                  val isType = if peek () = TYPE then (advance (); true) else false
                  val ids = parseEqualPaths ()
                  val sp = spanFrom start
                in loop ((if isType then SpecSharingType (ids, sp, freshId ()) else SpecSharing (ids, sp, freshId ())) :: acc) end
            | _ => loop (List.revAppend (parseSpec (), acc))
        in loop [] end

      and parseEqualPaths () : longid list =
        let
          fun path () =
            case next () of
              ID s => ([], s)
            | LONGID (p, s) => (p, s)
            | _ => err "expected identifier in sharing specification"
          fun loop acc = if peek () = EQUALS then (advance (); loop (path () :: acc)) else List.rev acc
          val ids = loop [path ()]
        in
          if List.length ids < 2 then err "sharing specification needs at least two identifiers" else ids
        end

      (* One specification; a list because some derived forms expand to several. *)
      and parseSpec () : spec list =
        let
          val start = peekSpan ()
          fun vid () =
            case next () of
              ID s => s
            | OP => (case next () of ID s => s | EQUALS => "=" | _ => err "expected identifier after 'op'")
            | t => errAt (prevSpan (), "expected identifier but found '" ^ toString t ^ "'")
          fun tyconName () = case next () of ID s => s | t => errAt (prevSpan (), "expected type constructor name but found '" ^ toString t ^ "'")
          fun andList f = let fun loop acc = if peek () = AND then (advance (); loop (f () :: acc)) else List.rev acc in loop [f ()] end
        in
          case peek () of
            VAL =>
              (advance ();
               [SpecVal (andList (fn () =>
                                     let
                                       val s = peekSpan ()
                                       val n = vid ()
                                       val () = expect COLON
                                       val t = parseTy ()
                                     in (n, t, spanFrom s) end), spanFrom start, freshId ())])
          | TYPE =>
              let
                val () = advance ()
                fun desc () =
                  let
                    val s = peekSpan ()
                    val tvs = List.map #1 (parseTyvarSeq ())
                    val n = tyconName ()
                  in
                    if peek () = EQUALS then (advance (); (tvs, n, SOME (parseTy ()), spanFrom s))
                    else (tvs, n, NONE, spanFrom s)
                  end
                val descs = andList desc
              in
                if List.all (fn (_, _, NONE, _) => true | _ => false) descs then
                  [SpecType (List.map (fn (tvs, n, _, sp) => (tvs, n, sp)) descs, spanFrom start, freshId ())]
                else if List.all (fn (_, _, SOME _, _) => true | _ => false) descs then
                  (* derived form:  type tyvarseq tycon = ty  ==>
                     include sig type tyvarseq tycon end where type tyvarseq tycon = ty *)
                  List.map (fn (tvs, n, SOME t, sp) =>
                               SpecInclude (SigWhere (SigSig ([SpecType ([(tvs, n, sp)], sp, freshId ())], sp, freshId ()), [(tvs, ([], n), t, sp)], sp, freshId ()), sp, freshId ())
                             | (_, _, NONE, _) => Error.bug "parseSpec: type description") descs
                else err "type specification mixes descriptions with and without definitions"
              end
          | EQTYPE =>
              (advance ();
               [SpecEqtype (andList (fn () =>
                                        let
                                          val s = peekSpan ()
                                          val tvs = List.map #1 (parseTyvarSeq ())
                                          val n = tyconName ()
                                        in (tvs, n, spanFrom s) end), spanFrom start, freshId ())])
          | DATATYPE =>
              let val () = advance ()
              in
                if peekAt 1 = EQUALS andalso peekAt 2 = DATATYPE then
                  let
                    val name = tyconName ()
                    val () = expect EQUALS
                    val () = expect DATATYPE
                    val rhs = case next () of
                                ID s => ([], s)
                              | LONGID (p, s) => (p, s)
                              | _ => err "expected type constructor"
                  in [SpecDatatypeRepl (name, rhs, spanFrom start, freshId ())] end
                else
                  let val dbs = andList parseDatbind
                  in
                    if peek () = WITHTYPE then err "withtype is not allowed in a signature" else ();
                    [SpecDatatype (dbs, spanFrom start, freshId ())]
                  end
              end
          | EXCEPTION =>
              (advance ();
               [SpecException (andList (fn () =>
                                           let
                                             val s = peekSpan ()
                                             val n = vid ()
                                           in
                                             if peek () = OF then (advance (); (n, SOME (parseTy ()), spanFrom s))
                                             else (n, NONE, spanFrom s)
                                           end), spanFrom start, freshId ())])
          | STRUCTURE =>
              (advance ();
               [SpecStructure (andList (fn () =>
                                           let
                                             val s = peekSpan ()
                                             val n = case next () of ID s => s | _ => err "expected structure name"
                                             val () = expect COLON
                                             val sg = parseSigexp ()
                                           in (n, sg, spanFrom s) end), spanFrom start, freshId ())])
          | INCLUDE =>
              let val () = advance ()
              in
                case peek () of
                  SIG => [SpecInclude (parseSigexp (), spanFrom start, freshId ())]
                | ID _ =>
                    (* include sigid1 ... sigidn (derived form), or one signature identifier with where clauses *)
                    let
                      fun ids acc =
                        case peek () of
                          ID n => let val sp = peekSpan () in advance (); ids ((n, sp) :: acc) end
                        | _ => List.rev acc
                      val names = ids []
                    in
                      (* Each signature identifier has the span of its name,
                         and the first specification begins at `include`. *)
                      case names of
                        [(n, sp)] => [SpecInclude (parseWhere (SigId (n, sp, freshId ()), sp), spanFrom start, freshId ())]
                      | (n, sp) :: rest =>
                          SpecInclude (SigId (n, sp, freshId ()), Source.join (start, sp), freshId ())
                          :: List.map (fn (n, sp) => SpecInclude (SigId (n, sp, freshId ()), sp, freshId ())) rest
                      | [] => []
                    end
                | t => err ("expected signature after 'include' but found '" ^ toString t ^ "'")
              end
          | t => err ("expected specification but found '" ^ toString t ^ "'")
        end

      and parseFixityIds () : string list =
        let
          fun loop acc =
            case peek () of
              ID s => (advance (); loop (s :: acc))
            | EQUALS => (advance (); loop ("=" :: acc))
            | _ => List.rev acc
          val ids = loop []
        in
          case ids of [] => err "expected identifiers in fixity declaration" | _ => ids
        end

      and parseFixityDec (start, mkFix, mkDec) =
        let
          val () = advance ()
          val prec = case peek () of
                       INT i => (advance ();
                                 if IntInf.< (i, IntInf.fromInt 0) orelse IntInf.> (i, IntInf.fromInt 9) then err "infix precedence must be between 0 and 9"
                                 else IntInf.toInt i)
                     | _ => 0
          val ids = parseFixityIds ()
          val () = fixenv := Fixity.extend (!fixenv, List.map (fn id => (id, mkFix prec)) ids)
        in mkDec (prec, ids, spanFrom start) end

      and parseTypbinds () : typbind list =
        let
          fun bind () =
            let
              val start = peekSpan ()
              val tvs = parseTyvarSeq ()
              val name = case next () of ID s => s | _ => err "expected type constructor name"
              val () = expect EQUALS
              val t = parseTy ()
            in {tyvars = tvs, name = name, ty = t, span = spanFrom start, id = freshId ()} end
          fun loop acc = if peek () = AND then (advance (); loop (bind () :: acc)) else List.rev acc
        in loop [bind ()] end

      and parseDatbind () : datbind =
        let
          val start = peekSpan ()
          val tvs = parseTyvarSeq ()
          val name = case next () of ID s => s | _ => err "expected type constructor name"
          val () = expect EQUALS
          val () = if peek () = BAR then advance () else ()
          fun conbind () =
            let
              val cstart = peekSpan ()
              val () = if peek () = OP then advance () else ()
              val cname = case next () of ID s => s | _ => err "expected constructor name"
              val arg = if peek () = OF then (advance (); SOME (parseTy ())) else NONE
            in (cname, arg, spanFrom cstart) end
          fun loop acc = if peek () = BAR then (advance (); loop (conbind () :: acc)) else List.rev acc
        in {tyvars = tvs, name = name, cons = loop [conbind ()], span = spanFrom start, id = freshId ()} end

      (* One `fun` binding: clauses separated by '|'. *)
      and parseFundef () : fundef =
        let
          val start = peekSpan ()
          fun clause () : string * Source.span * clause =
            let
              val cstart = peekSpan ()
              val (name, args) = parseFunHead ()
              val resty = if peek () = COLON then (advance (); SOME (parseTy ())) else NONE
              val () = expect EQUALS
              val body = parseExp ()
            in (name, cstart, {pats = args, resty = resty, body = body, span = spanFrom cstart, id = freshId ()}) end
          val (name, _, c1) = clause ()
          val arity = List.length (#pats c1)
          fun loop acc =
            if peek () = BAR then
              let
                val () = advance ()
                val (n, sp, c) = clause ()
              in
                if n <> name then errAt (sp, "clauses of '" ^ name ^ "' and '" ^ n ^ "' mixed in one function definition")
                else if List.length (#pats c) <> arity then errAt (sp, "clauses of '" ^ name ^ "' have different numbers of arguments")
                else loop (c :: acc)
              end
            else List.rev acc
          val clauses = loop [c1]
        in {name = name, clauses = clauses, info = ref NONE, span = spanFrom start, id = freshId ()} end

      (* Returns the function name and its argument patterns. Handles the
         three clause head forms:  f p1 ... pn  |  p1 f p2  |  (p1 f p2) p3 ... pn *)
      and parseFunHead () : string * pat list =
        let
          val save = !pos
          fun tryParenInfix () =
            if peek () <> LPAREN then NONE
            else
              let
                val start = peekSpan ()
                val () = advance ()
                val a = parseAtPat ()
              in
                case peek () of
                  ID s =>
                    if isInfixId s then
                      let
                        val () = advance ()
                        val b = parseAtPat ()
                        val () = expect RPAREN
                        val first = PTuple ([a, b], spanFrom start, freshId ())
                        fun rest acc = if startsAtPat (peek ()) then rest (parseAtPat () :: acc) else List.rev acc
                      in
                        (* `(p1 op p2) op2 p3` is the infix form with a parenthesized first argument *)
                        case peek () of
                          ID s2 => if isInfixId s2 then NONE else SOME (s, first :: rest [])
                        | _ => SOME (s, first :: rest [])
                      end
                    else NONE
                | _ => NONE
              end
          val attempt = (tryParenInfix ()) handle Error.CompileError _ => NONE
        in
          case attempt of
            SOME r => r
          | NONE =>
            let
              val () = pos := save
              fun collect acc =
                case peek () of
                  ID s =>
                    if isInfixId s then
                      let val sp = peekSpan ()
                      in advance (); collect (Oper (s, Fixity.lookup (!fixenv, s), sp) :: acc) end
                    else collect (Atom (parseAtPat ()) :: acc)
                | t => if startsAtPat t then collect (Atom (parseAtPat ()) :: acc) else List.rev acc
              val items = collect []
              fun atoms [] = []
                | atoms (Atom p :: rest) = p :: atoms rest
                | atoms (Oper (s, _, sp) :: _) = errAt (sp, "unexpected infix operator '" ^ s ^ "' in function clause")
            in
              case items of
                [Atom a, Oper (s, _, _), Atom b] => (s, [PTuple ([a, b], Source.join (spanOfPat a, spanOfPat b), freshId ())])
              | Atom (PVar (([], f), _, _, _)) :: rest =>
                  (case rest of
                     [] => err "function clause needs at least one argument pattern"
                   | _ => (f, atoms rest))
              | Atom p :: _ => errAt (spanOfPat p, "expected function name")
              | Oper (s, _, sp) :: _ => errAt (sp, "infix identifier '" ^ s ^ "' must be prefixed with 'op' here")
              | [] => err "expected function clause"
            end
        end

      val program = parseDecs Top
    in (program,!fixenv,!pos,List.rev (!topdecEnds),List.rev (!problems)) end
end
