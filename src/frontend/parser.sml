(* Recursive-descent parser for Standard ML '97 with precedence-climbing
   resolution of user-defined infix operators. *)
structure Parser =
struct
  open Token Ast

  (* Items of an infix expression/pattern before fixity resolution. *)
  datatype 'a item = Atom of 'a | Oper of string * Fixity.fixity * Source.span

  (* Where a declaration list occurs: at top level (topdecs), inside a
     structure-level declaration (strdecs), or inside an expression (core
     decs only). *)
  datatype ctx = Top | Str | Let

  (* Parse a file starting from the given fixity environment; returns the
     program and the fixity environment in effect at the end (so that infix
     declarations carry over to later files of the same program). *)
  (* Parse the tokens of a file (Lexer.tokenize), so that the driver can look
     at them before it decides what else to parse. *)
  fun parseTokensWith (toks : Lexer.item vector, initialFixity : Fixity.env) : program * Fixity.env =
    let
      val ntoks = Vector.length toks
      val pos = ref 0
      val fixenv : Fixity.env ref = ref initialFixity

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
          if peek () = ARROW then (advance (); TyArrow (t, parseTy (), spanFrom start)) else t
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
          | ts => TyTuple (ts, spanFrom start)
        end

      and parseAppTy () =
        let
          val start = peekSpan ()
          fun loop t =
            case peek () of
              ID s => if s = "*" then t else (advance (); loop (TyCon ([t], ([], s), spanFrom start)))
            | LONGID (p, s) => (advance (); loop (TyCon ([t], (p, s), spanFrom start)))
            | _ => t
        in
          loop (parseAtTy ())
        end

      and parseAtTy () =
        let val start = peekSpan ()
        in
          case peek () of
            TYVAR v => (advance (); TyVar (v, start))
          | ID s => if s = "*" then err "expected type" else (advance (); TyCon ([], ([], s), start))
          | LONGID (p, s) => (advance (); TyCon ([], (p, s), start))
          | LBRACE =>
              let
                val () = advance ()
                fun field () =
                  let val lab = parseLabel ()
                  in expect COLON; (lab, parseTy ()) end
                fun loop acc =
                  if peek () = RBRACE then List.rev acc
                  else let val f = field ()
                       in if peek () = COMMA then (advance (); loop (f :: acc)) else List.rev (f :: acc) end
                val fields = loop []
              in expect RBRACE; TyRecord (fields, spanFrom start) end
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
                  in TyCon (ts, con, spanFrom start) end
                else (expect RPAREN; t)
              end
          | _ => err ("expected type but found '" ^ toString (peek ()) ^ "'")
        end

      and parseLabel () : string =
        case next () of
          ID s => s
        | INT i => if IntInf.> (i, IntInf.fromInt 0) then IntInf.toString i else err "record label must be a positive integer"
        | t => errAt (prevSpan (), "expected record label but found '" ^ toString t ^ "'")

      fun parseTyvarSeq () : string list =
        let
          val start = peekSpan ()
          val vs =
            case peek () of
              TYVAR v => (advance (); [v])
            | LPAREN =>
                (case peekAt 1 of
                   TYVAR _ =>
                     let
                       val () = advance ()
                       fun loop acc =
                         case next () of
                           TYVAR v => if peek () = COMMA then (advance (); loop (v :: acc)) else List.rev (v :: acc)
                         | _ => err "expected type variable"
                       val vs = loop []
                     in expect RPAREN; vs end
                 | _ => [])
            | _ => []
          (* Section 2.9: no tyvarseq may contain the same type variable twice *)
          fun dups [] = ()
            | dups (v :: rest) = if List.exists (fn w => w = v) rest then errAt (start, "duplicate type variable " ^ v ^ " in type variable sequence") else dups rest
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
          fun typed p = if peek () = COLON then (advance (); typed (PTyped (p, parseTy (), spanFrom start))) else p
          val p = typed p
        in
          if peek () = AS then
            let
              val () = advance ()
              fun asVar (PVar (([], v), _, _)) = SOME (v, NONE)
                | asVar (PTyped (PVar (([], v), _, _), t, _)) = SOME (v, SOME t)
                | asVar _ = NONE
            in
              case asVar p of
                SOME (v, t) => PLayered (v, t, parsePat (), ref NONE, spanFrom start)
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
              PVar (id, _, sp) => PApp (id, ref NONE, a, Source.join (sp, spanOfPat a))
            | _ => errAt (spanOfPat f, "only a constructor can be applied in a pattern")
          fun binop (s, sp, l, r) =
            PApp (([], s), ref NONE, PTuple ([l, r], Source.join (spanOfPat l, spanOfPat r)),
                  Source.join (spanOfPat l, spanOfPat r))
        in
          resolve (items, app, binop, "pattern")
        end

      and parseAtPat () : pat =
        let val start = peekSpan ()
        in
          case peek () of
            UNDERSCORE => (advance (); PWild start)
          | INT i => (advance (); PScon (SInt i, ref NONE, start))
          | WORD w => (advance (); PScon (SWord w, ref NONE, start))
          | STRING s => (advance (); PScon (SString s, ref NONE, start))
          | WIDESTRING s => (advance (); PScon (SWideString s, ref NONE, start))
          | CHAR c => (advance (); PScon (SChar c, ref NONE, start))
          | REAL _ => err "real constants are not allowed in patterns"
          | ID s => (advance (); PVar (([], s), ref NONE, start))
          | LONGID (p, s) => (advance (); PVar ((p, s), ref NONE, start))
          | OP =>
              (advance ();
               case next () of
                 ID s => PVar (([], s), ref NONE, spanFrom start)
               | LONGID (p, s) => PVar ((p, s), ref NONE, spanFrom start)
               | EQUALS => PVar (([], "="), ref NONE, spanFrom start)
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
                      if peek () = EQUALS then (advance (); SOME (lab, parsePat ()))
                      else
                        let
                          val tyopt = if peek () = COLON then (advance (); SOME (parseTy ())) else NONE
                          val var = case tyopt of
                                      NONE => PVar (([], lab), ref NONE, fstart)
                                    | SOME t => PTyped (PVar (([], lab), ref NONE, fstart), t, spanFrom fstart)
                        in
                          if peek () = AS then (advance (); SOME (lab, PLayered (lab, tyopt, parsePat (), ref NONE, spanFrom fstart)))
                          else SOME (lab, var)
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
                expect RBRACE; PRecord (fields, flex, ref NONE, spanFrom start)
              end
          | LPAREN =>
              let val () = advance ()
              in
                if peek () = RPAREN then (advance (); PTuple ([], spanFrom start))
                else
                  let val p = parsePat ()
                  in
                    if peek () = COMMA then
                      let fun loop acc = if peek () = COMMA then (advance (); loop (parsePat () :: acc)) else List.rev acc
                          val ps = loop [p]
                      in expect RPAREN; PTuple (ps, spanFrom start) end
                    else (expect RPAREN; p)
                  end
              end
          | LBRACKET =>
              let val () = advance ()
              in
                if peek () = RBRACKET then (advance (); PList ([], spanFrom start))
                else
                  let fun loop acc = if peek () = COMMA then (advance (); loop (parsePat () :: acc)) else List.rev acc
                      val ps = loop [parsePat ()]
                  in expect RBRACKET; PList (ps, spanFrom start) end
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
            RAISE => (advance (); let val e = parseExp () in ERaise (e, spanFrom start) end)
          | IF =>
              let
                val () = advance ()
                val c = parseExp ()
                val () = expect THEN
                val t = parseExp ()
                val () = expect ELSE
                val e = parseExp ()
              in EIf (c, t, e, spanFrom start) end
          | WHILE =>
              let
                val () = advance ()
                val c = parseExp ()
                val () = expect DO
                val b = parseExp ()
              in EWhile (c, b, spanFrom start) end
          | CASE =>
              let
                val () = advance ()
                val e = parseExp ()
                val () = expect OF
                val m = parseMatch ()
              in ECase (e, m, spanFrom start) end
          | FN => (advance (); let val m = parseMatch () in EFn (m, spanFrom start) end)
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
            if peek () = HANDLE then (advance (); EHandle (e, parseMatch (), spanFrom start)) else e
          end

      and parseOrelseExp () =
        if isPrefixStart (peek ()) then parseExp ()
        else
          let
            val start = peekSpan ()
            fun loop e =
              if peek () = ORELSE then (advance (); loop (EOrelse (e, parseAndalsoExp (), spanFrom start))) else e
          in loop (parseAndalsoExp ()) end

      and parseAndalsoExp () =
        if isPrefixStart (peek ()) then parseExp ()
        else
          let
            val start = peekSpan ()
            fun loop e =
              if peek () = ANDALSO then (advance (); loop (EAndalso (e, parseTypedExp (), spanFrom start))) else e
          in loop (parseTypedExp ()) end

      and parseTypedExp () =
        if isPrefixStart (peek ()) then parseExp ()
        else
          let
            val start = peekSpan ()
            fun loop e =
              if peek () = COLON then (advance (); loop (ETyped (e, parseTy (), spanFrom start))) else e
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
          fun app (f, a) = EApp (f, a, Source.join (spanOfExp f, spanOfExp a))
          fun binop (s, sp, l, r) =
            let val whole = Source.join (spanOfExp l, spanOfExp r)
            in EApp (EVar (([], s), ref NONE, sp), ETuple ([l, r], whole), whole) end
        in
          resolve (items, app, binop, "expression")
        end

      and parseAtExp () : exp =
        let val start = peekSpan ()
        in
          case peek () of
            INT i => (advance (); EScon (SInt i, ref NONE, start))
          | WORD w => (advance (); EScon (SWord w, ref NONE, start))
          | REAL r => (advance (); EScon (SReal r, ref NONE, start))
          | STRING s => (advance (); EScon (SString s, ref NONE, start))
          | WIDESTRING s => (advance (); EScon (SWideString s, ref NONE, start))
          | CHAR c => (advance (); EScon (SChar c, ref NONE, start))
          | ID s => (advance (); EVar (([], s), ref NONE, start))
          | LONGID (p, s) => (advance (); EVar ((p, s), ref NONE, start))
          | EQUALS => err "infix operator '=' used without arguments; use 'op ='"
          | OP =>
              (advance ();
               case next () of
                 ID s => EVar (([], s), ref NONE, spanFrom start)
               | LONGID (p, s) => EVar ((p, s), ref NONE, spanFrom start)
               | EQUALS => EVar (([], "="), ref NONE, spanFrom start)
               | _ => err "expected identifier after 'op'")
          | LBRACE =>
              let
                val () = advance ()
                fun field () =
                  let val lab = parseLabel ()
                  in expect EQUALS; (lab, parseExp ()) end
                fun loop acc =
                  if peek () = RBRACE then List.rev acc
                  else let val f = field ()
                       in if peek () = COMMA then (advance (); loop (f :: acc)) else List.rev (f :: acc) end
                val fields = loop []
              in
                expect RBRACE;
                (case fields of [] => ETuple ([], spanFrom start) | _ => ERecord (fields, spanFrom start))
              end
          | HASH =>
              let
                val () = advance ()
                val lab = parseLabel ()
              in ESelect (lab, ref NONE, spanFrom start) end
          | LPAREN =>
              let val () = advance ()
              in
                if peek () = RPAREN then (advance (); ETuple ([], spanFrom start))
                else
                  let val e = parseExp ()
                  in
                    case peek () of
                      COMMA =>
                        let fun loop acc = if peek () = COMMA then (advance (); loop (parseExp () :: acc)) else List.rev acc
                            val es = loop [e]
                        in expect RPAREN; ETuple (es, spanFrom start) end
                    | SEMI =>
                        let fun loop acc = if peek () = SEMI then (advance (); loop (parseExp () :: acc)) else List.rev acc
                            val es = loop [e]
                        in expect RPAREN; ESeq (es, spanFrom start) end
                    | _ => (expect RPAREN; e)
                  end
              end
          | LBRACKET =>
              let val () = advance ()
              in
                if peek () = RBRACKET then (advance (); EList ([], spanFrom start))
                else
                  let fun loop acc = if peek () = COMMA then (advance (); loop (parseExp () :: acc)) else List.rev acc
                      val es = loop [parseExp ()]
                  in expect RBRACKET; EList (es, spanFrom start) end
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
                val body = case es of [e] => e | _ => ESeq (es, spanFrom start)
              in ELet (decs, body, spanFrom start) end
          | PRIM =>
              let
                val () = advance ()
                val name = case next () of STRING s => s | _ => err "expected string literal after _prim"
                val () = expect COLON
                val t = parseTy ()
              in EPrim (name, t, spanFrom start) end
          | t => err ("expected expression but found '" ^ toString t ^ "'")
        end

      (* ---------------------------------------------------------------- *)
      (* Declarations                                                      *)
      and parseDecs (ctx : ctx) : dec list =
        let
          fun loop acc =
            case peek () of
              SEMI => (advance (); loop acc)
            | IN => List.rev acc
            | END => List.rev acc
            | RPAREN => List.rev acc
            | EOF => List.rev acc
            | _ => loop (parseDec ctx :: acc)
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
                  List.map (fn (v, vsp) => (PVar (([], v), ref NONE, vsp), EVar (([], v), ref NONE, vsp)))
                           (List.concat (List.map (fn (p, _) => recVars p) recBinds))
              in
                if isRec then DValRec (tvs, plainBinds @ recBinds, sp)
                else if List.null recBinds then DVal (tvs, plainBinds, sp)
                else DLocal ([DValRec (tvs, recBinds, sp)], [DVal (tvs, plainBinds @ reexport, sp)], sp)
              end
          | FUN =>
              let
                val () = advance ()
                val tvs = parseTyvarSeq ()
                fun loop acc = if peek () = AND then (advance (); loop (parseFundef () :: acc)) else List.rev acc
                val fs = loop [parseFundef ()]
              in DFun (tvs, fs, spanFrom start) end
          | TYPE => (advance (); DType (parseTypbinds (), spanFrom start))
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
                  in DDatatypeRepl (name, rhs, spanFrom start) end
                else
                  let
                    fun loop acc = if peek () = AND then (advance (); loop (parseDatbind () :: acc)) else List.rev acc
                    val dbs = loop [parseDatbind ()]
                    val tbs = if peek () = WITHTYPE then (advance (); parseTypbinds ()) else []
                  in DDatatype (dbs, tbs, spanFrom start) end
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
                      OF => (advance (); ExnDecl (name, SOME (parseTy ()), ref NONE, spanFrom estart))
                    | EQUALS =>
                        (advance ();
                         if peek () = OP then advance () else ();
                         case next () of
                           ID s => ExnRepl (name, ([], s), ref NONE, spanFrom estart)
                         | LONGID (p, s) => ExnRepl (name, (p, s), ref NONE, spanFrom estart)
                         | _ => err "expected exception constructor")
                    | _ => ExnDecl (name, NONE, ref NONE, spanFrom estart)
                  end
                fun loop acc = if peek () = AND then (advance (); loop (exbind () :: acc)) else List.rev acc
              in DException (loop [exbind ()], spanFrom start) end
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
                val added = List.take (env2, List.length env2 - List.length env1)
                val () = fixenv := added @ env0
              in DLocal (d1, d2, spanFrom start) end
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
                case ids of [] => err "expected structure name after 'open'" | _ => DOpen (ids, spanFrom start)
              end
          | INFIX => parseFixityDec (start, fn p => Fixity.Infix p, fn (p, ids, sp) => DInfix (p, ids, sp))
          | INFIXR => parseFixityDec (start, fn p => Fixity.Infixr p, fn (p, ids, sp) => DInfixr (p, ids, sp))
          | NONFIX =>
              let
                val () = advance ()
                val ids = parseFixityIds ()
                val () = fixenv := List.map (fn id => (id, Fixity.Nonfix)) ids @ !fixenv
              in DNonfix (ids, spanFrom start) end
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
              in DOverload {kind = kind, strid = strid, literal = literal, span = spanFrom start} end
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
                      val body = parseStrexp ()
                      (* derived forms: structure S : SIG = e  ==>  structure S = e : SIG  (and :>) *)
                      val body = case ascription of
                                   NONE => body
                                 | SOME (sg, opaque) => StrAscribe (body, sg, opaque, spanFrom bstart)
                    in {name = name, strexp = body, span = spanFrom bstart} end
                  fun loop acc = if peek () = AND then (advance (); loop (bind () :: acc)) else List.rev acc
                  val binds = loop [bind ()]
                in
                  checkDistinct (List.map (fn b : strbind => (#name b, #span b)) binds, "structure");
                  DStructure (binds, spanFrom start)
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
                    in {name = name, sigexp = sg, span = spanFrom bstart} end
                  fun loop acc = if peek () = AND then (advance (); loop (bind () :: acc)) else List.rev acc
                  val binds = loop [bind ()]
                in
                  checkDistinct (List.map (fn b : sigbind => (#name b, #span b)) binds, "signature");
                  DSignature (binds, spanFrom start)
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
                          in (NONE, SigSig (specs, spanFrom sstart)) end
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
                                 | SOME (sg, opaque) => StrAscribe (body, sg, opaque, spanFrom bstart)
                    in {name = name, param = param, paramSig = paramSig, body = body, span = spanFrom bstart} end
                  fun loop acc = if peek () = AND then (advance (); loop (bind () :: acc)) else List.rev acc
                  val binds = loop [bind ()]
                in
                  checkDistinct (List.map (fn b : funbind => (#name b, #span b)) binds, "functor");
                  DFunctor (binds, spanFrom start)
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
              in DAbstype (dbs, tbs, decs, spanFrom start) end
          | t =>
              if ctx = Top andalso (startsAtExp t orelse isPrefixStart t) then
                (* derived form of programs (Appendix A):  exp ;  ==>  val it = exp ; *)
                let val e = parseExp ()
                in DVal ([], [(PVar (([], "it"), ref NONE, spanOfExp e), e)], spanFrom start) end
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
                in StrStruct (decs, spanFrom start) end
            | LET =>
                let
                  val () = advance ()
                  val saved = !fixenv
                  val decs = parseDecs Str
                  val () = expect IN
                  val body = parseStrexp ()
                  val () = expect END
                  val () = fixenv := saved
                in StrLet (decs, body, spanFrom start) end
            | ID s =>
                if peekAt 1 = LPAREN then
                  let
                    val () = advance ()
                    val () = advance ()
                    val arg = parseFunctorArg ()
                    val () = expect RPAREN
                  in StrApp (s, arg, ref NONE, spanFrom start) end
                else (advance (); StrId (([], s), start))
            | LONGID (p, s) => (advance (); StrId ((p, s), start))
            | t => err ("expected structure expression but found '" ^ toString t ^ "'")
          fun ascribe e =
            case peek () of
              COLON => (advance (); ascribe (StrAscribe (e, parseSigexp (), false, spanFrom start)))
            | COLONGT => (advance (); ascribe (StrAscribe (e, parseSigexp (), true, spanFrom start)))
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
              in StrStruct (decs, spanFrom start) end
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
                in SigSig (specs, spanFrom start) end
            | ID n => (advance (); SigId (n, start))
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
                val tvs = parseTyvarSeq ()
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
          in parseWhere (SigWhere (sg, clauses, spanFrom start), start) end
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
                in loop ((if isType then SpecSharingType (ids, sp) else SpecSharing (ids, sp)) :: acc) end
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
                                     in (n, t, spanFrom s) end), spanFrom start)])
          | TYPE =>
              let
                val () = advance ()
                fun desc () =
                  let
                    val s = peekSpan ()
                    val tvs = parseTyvarSeq ()
                    val n = tyconName ()
                  in
                    if peek () = EQUALS then (advance (); (tvs, n, SOME (parseTy ()), spanFrom s))
                    else (tvs, n, NONE, spanFrom s)
                  end
                val descs = andList desc
              in
                if List.all (fn (_, _, NONE, _) => true | _ => false) descs then
                  [SpecType (List.map (fn (tvs, n, _, sp) => (tvs, n, sp)) descs, spanFrom start)]
                else if List.all (fn (_, _, SOME _, _) => true | _ => false) descs then
                  (* derived form:  type tyvarseq tycon = ty  ==>
                     include sig type tyvarseq tycon end where type tyvarseq tycon = ty *)
                  List.map (fn (tvs, n, SOME t, sp) =>
                               SpecInclude (SigWhere (SigSig ([SpecType ([(tvs, n, sp)], sp)], sp), [(tvs, ([], n), t, sp)], sp), sp)
                             | (_, _, NONE, _) => Error.bug "parseSpec: type description") descs
                else err "type specification mixes descriptions with and without definitions"
              end
          | EQTYPE =>
              (advance ();
               [SpecEqtype (andList (fn () =>
                                        let
                                          val s = peekSpan ()
                                          val tvs = parseTyvarSeq ()
                                          val n = tyconName ()
                                        in (tvs, n, spanFrom s) end), spanFrom start)])
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
                  in [SpecDatatypeRepl (name, rhs, spanFrom start)] end
                else
                  let val dbs = andList parseDatbind
                  in
                    if peek () = WITHTYPE then err "withtype is not allowed in a signature" else ();
                    [SpecDatatype (dbs, spanFrom start)]
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
                                           end), spanFrom start)])
          | STRUCTURE =>
              (advance ();
               [SpecStructure (andList (fn () =>
                                           let
                                             val s = peekSpan ()
                                             val n = case next () of ID s => s | _ => err "expected structure name"
                                             val () = expect COLON
                                             val sg = parseSigexp ()
                                           in (n, sg, spanFrom s) end), spanFrom start)])
          | INCLUDE =>
              let val () = advance ()
              in
                case peek () of
                  SIG => [SpecInclude (parseSigexp (), spanFrom start)]
                | ID _ =>
                    (* include sigid1 ... sigidn (derived form), or one signature identifier with where clauses *)
                    let
                      fun ids acc = case peek () of ID n => (advance (); ids (n :: acc)) | _ => List.rev acc
                      val names = ids []
                    in
                      case names of
                        [n] => [SpecInclude (parseWhere (SigId (n, start), start), spanFrom start)]
                      | _ => List.map (fn n => SpecInclude (SigId (n, start), start)) names
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
          val () = fixenv := List.map (fn id => (id, mkFix prec)) ids @ !fixenv
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
            in {tyvars = tvs, name = name, ty = t, span = spanFrom start} end
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
        in {tyvars = tvs, name = name, cons = loop [conbind ()], span = spanFrom start} end

      (* One `fun` binding: clauses separated by '|'. *)
      and parseFundef () : fundef =
        let
          val start = peekSpan ()
          fun clause () : string * Source.span * {pats : pat list, resty : ty option, body : exp} =
            let
              val cstart = peekSpan ()
              val (name, args) = parseFunHead ()
              val resty = if peek () = COLON then (advance (); SOME (parseTy ())) else NONE
              val () = expect EQUALS
              val body = parseExp ()
            in (name, cstart, {pats = args, resty = resty, body = body}) end
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
        in {name = name, clauses = clauses, info = ref NONE, span = spanFrom start} end

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
                        val first = PTuple ([a, b], spanFrom start)
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
                [Atom a, Oper (s, _, _), Atom b] => (s, [PTuple ([a, b], Source.join (spanOfPat a, spanOfPat b))])
              | Atom (PVar (([], f), _, _)) :: rest =>
                  (case rest of
                     [] => err "function clause needs at least one argument pattern"
                   | _ => (f, atoms rest))
              | Atom p :: _ => errAt (spanOfPat p, "expected function name")
              | Oper (s, _, sp) :: _ => errAt (sp, "infix identifier '" ^ s ^ "' must be prefixed with 'op' here")
              | [] => err "expected function clause"
            end
        end

      val program = parseDecs Top
    in
      if peek () <> EOF then err ("unexpected '" ^ toString (peek ()) ^ "'") else (program, !fixenv)
    end

  fun parseFileWith (file : Source.file, initialFixity : Fixity.env) : program * Fixity.env =
    parseTokensWith (Lexer.tokenize file, initialFixity)

  fun parseFile (file : Source.file) : program = #1 (parseFileWith (file, Fixity.initial))
end
