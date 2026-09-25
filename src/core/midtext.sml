(* Mid as text, and back (docs/ir.md): `show` prints a program for a dump
   (--dump-after=mid) or a test (tests/ir), and `parse` reads what it
   prints, so that a pass can be tested on a small input written by hand.

   Variables, globals, join points and type variables are numbered afresh
   in the order they appear (v1, g1, j1, 'a), so that a dump does not
   change with stamps made elsewhere. A type name is written as it is,
   with /N where names would clash; one that is not built in is declared at
   the head, a datatype with its constructors. Positions are written only
   where asked for (`at`).

     (X ... : zero or more X; [X] : X or nothing)
     program := decl ... def ...
     decl    := (datatype NAME (TYVAR ...) (TAG STRING [: TYPE]) ...) | (abstract NAME ARITY)
     def     := (val GLOBAL : SCHEME EXP) | (funs FUNDEF FUNDEF ...)
              | (do ((GLOBAL : SCHEME) ...) EXP)
     fundef  := (fn VAR [TYVARS] ((VAR : TYPE) ...) : TYPE EXP)
     exp     := (let (VAR : SCHEME) RHS EXP) | (fun FUNDEF FUNDEF ... EXP)
              | (join LABEL ((VAR : TYPE) ...) EXP EXP) | (jump LABEL ATOM ...)
              | (if ATOM EXP EXP) | (handle VAR EXP EXP) | (raise ATOM)
              | (return RHS) | (at STRING INT INT FRAME ... EXP)
     frame   := (in STRING STRING INT INT)   an inlined function's name, and
                                             where it was called from
              | (in STRING)                  one called in tail position
     rhs     := ATOM | (app ATOM ATOM ...) | (prim NAME ATOM ... : TYPE) | (tuple ATOM ...)
              | (select INT ATOM) | (con TAG ATOM : TYPE) | (decon TAG ATOM) | (tag ATOM)
              | (newexn STRING) | (builtinexn INT) | (mkexn ATOM ATOM) | (exncon ATOM)
              | (exnarg ATOM : TYPE) | (setglobal GLOBAL ATOM)
     atom    := VAR[TYARGS] | GLOBAL[TYARGS] | CONST | (CONST : TYPE) | (con0 TAG : TYPE) | ()
     scheme  := [TYVARS] TYPE
     tyvars  := [TYVAR TYVAR ...]      tyargs := [TYPE, TYPE, ...]
   A constant of the type its kind gives it (int, word, real, string, char)
   is written bare; a record of one field, {TYPE}. Comments are SML's. *)
structure MidText =
struct
  open Mid

  (* ---- printing ---- *)

  val builtinNames = List.map (fn (c : Types.tycon) => (#stamp c, #name c)) Types.builtinTycons
  fun isBuiltin stamp = List.exists (fn (s, _) => s = stamp) builtinNames
  val reserved = "unit" :: "exncon" :: List.map #2 builtinNames

  fun defaultTy (c : Lambda.const) : Ty.ty =
    case c of
      Lambda.CInt _ => Ty.int
    | Lambda.CWord _ => Ty.Con (#stamp Types.wordTycon, "word", [])
    | Lambda.CReal _ => Ty.Con (#stamp Types.realTycon, "real", [])
    | Lambda.CString _ => Ty.string
    | Lambda.CChar _ => Ty.Con (#stamp Types.charTycon, "char", [])

  fun show' (marks : bool) (p : program) : string =
    let
      val out : string list ref = ref []
      fun emit s = out := s :: !out
      fun nl n = emit ("\n" ^ CharVector.tabulate (n, fn _ => #" "))

      (* numbering *)
      fun counter () = (ref IntMap.empty, ref 0)
      fun number ((m, c), x) =
        case IntMap.find (!m, x) of
          SOME n => n
        | NONE => (c := !c + 1; m := IntMap.insert (!m, x, !c); !c)
      val vars = counter ()
      val globals = counter ()
      val labels = counter ()
      val gens = counter ()
      val frees = counter ()
      fun v x = "v" ^ Int.toString (number (vars, x))
      fun g x = "g" ^ Int.toString (number (globals, x))
      fun j x = "j" ^ Int.toString (number (labels, x))
      fun letters n = if n <= 26 then String.str (Char.chr (Char.ord #"a" + n - 1)) else "t" ^ Int.toString n
      fun gen x = "'" ^ letters (number (gens, x))
      fun free x = "'_" ^ letters (number (frees, x))

      (* the type names: every one the program uses, and those the
         datatypes it uses use; a name that is not built in is declared *)
      val tycons : (string * int) IntMap.map ref = ref IntMap.empty   (* stamp -> name, arity *)
      val order : int list ref = ref []
      fun sanitize n =
        if n <> "" andalso CharVector.all (fn c => Char.isAlphaNum c orelse c = #"_") n
           andalso Char.isAlpha (String.sub (n, 0)) then n
        else "t"
      val bases : int StringMap.map ref = ref StringMap.empty
      fun nameFor (stamp, name) =
        let
          val base = sanitize name
          val used = case StringMap.find (!bases, base) of SOME k => k | NONE => 0
          val () = bases := StringMap.insert (!bases, base, used + 1)
        in
          if used = 0 andalso not (List.exists (fn r => r = base) reserved) then base
          else base ^ "/" ^ Int.toString (used + 1)
        end
      fun collect (t : Ty.ty) : unit =
        case t of
          Ty.Con (stamp, name, args) =>
            (List.app collect args;
             if isBuiltin stamp orelse IntMap.member (!tycons, stamp) then ()
             else
               (tycons := IntMap.insert (!tycons, stamp, (nameFor (stamp, name), List.length args));
                order := stamp :: !order;
                case Ty.datatypeOf stamp of
                  SOME {cons, ...} => List.app (fn (_, _, SOME a) => collect a | _ => ()) cons
                | NONE => ()))
        | Ty.Tuple ts => List.app collect ts
        | Ty.Arrow (a, b) => (collect a; collect b)
        | _ => ()
      fun collectAtom a =
        case a of
          Var (_, ts) => List.app collect ts
        | Global (_, ts) => List.app collect ts
        | Const (_, t) => collect t
        | Con0 (_, t) => collect t
        | Unit => ()
      fun collectRhs r =
        case r of
          Atom a => collectAtom a
        | App (f, xs) => List.app collectAtom (f :: xs)
        | Prim (_, t, xs) => (collect t; List.app collectAtom xs)
        | Tuple xs => List.app collectAtom xs
        | Select (_, a) => collectAtom a
        | Con (_, t, a) => (collect t; collectAtom a)
        | Decon (_, t, a) => (collect t; collectAtom a)
        | ConTag a => collectAtom a
        | MkExn (c, a) => (collectAtom c; collectAtom a)
        | ExnCon a => collectAtom a
        | ExnArg (t, a) => (collect t; collectAtom a)
        | SetGlobal (_, a) => collectAtom a
        | _ => ()
      fun collectExp e =
        case e of
          Let (_, (_, t), r, b) => (collect t; collectRhs r; collectExp b)
        | Fun (fs, b) => (List.app collectFun fs; collectExp b)
        | Join (_, ps, body, s) => (List.app (collect o #2) ps; collectExp body; collectExp s)
        | Jump (_, xs) => List.app collectAtom xs
        | If (c, t, f) => (collectAtom c; collectExp t; collectExp f)
        | Handle (a, _, h) => (collectExp a; collectExp h)
        | Raise a => collectAtom a
        | Return r => collectRhs r
        | Mark (_, a) => collectExp a
      and collectFun ({params, result, body, ...} : fundef) =
        (List.app (collect o #2) params; collect result; collectExp body)
      val () =
        List.app (fn Val (_, (_, t), e) => (collect t; collectExp e)
                   | Funs fs => List.app collectFun fs
                   | Do (gs, e) => (List.app (collect o #2 o #2) gs; collectExp e)) p

      val ty =
        Ty.format (gen, free)
        o (let
             fun rename t =
               case t of
                 Ty.Con (stamp, name, args) =>
                   Ty.Con (stamp, case IntMap.find (!tycons, stamp) of SOME (n, _) => n | NONE => name,
                           List.map rename args)
               | Ty.Tuple ts => Ty.Tuple (List.map rename ts)
               | Ty.Arrow (a, b) => Ty.Arrow (rename a, rename b)
               | _ => t
           in rename end)
      fun tyvarList [] = ""
        | tyvarList tvs = "[" ^ String.concatWith " " (List.map gen tvs) ^ "] "
      fun scheme (tvs, t) = let val l = tyvarList tvs in l ^ ty t end

      fun constText c =
        case c of
          Lambda.CString s => "\"" ^ String.toString s ^ "\""
        | Lambda.CChar c => "#\"" ^ Char.toString (Char.chr c) ^ "\""
        | _ => Lambda.constToString c
      fun args [] = ""
        | args ts = "[" ^ String.concatWith ", " (List.map ty ts) ^ "]"
      fun atom a =
        case a of
          Var (x, ts) => let val n = v x in n ^ args ts end
        | Global (x, ts) => let val n = g x in n ^ args ts end
        | Const (c, t) => if Ty.equal (t, defaultTy c) then constText c else "(" ^ constText c ^ " : " ^ ty t ^ ")"
        | Con0 (tag, t) => "(con0 " ^ Int.toString tag ^ " : " ^ ty t ^ ")"
        | Unit => "()"
      fun atoms xs = String.concat (List.map (fn a => " " ^ atom a) xs)
      fun rhs r =
        case r of
          Atom a => atom a
        | App (f, xs) => let val f = atom f in "(app " ^ f ^ atoms xs ^ ")" end
        | Prim (name, t, xs) => let val xs = atoms xs in "(prim " ^ name ^ xs ^ " : " ^ ty t ^ ")" end
        | Tuple xs => "(tuple" ^ atoms xs ^ ")"
        | Select (i, a) => "(select " ^ Int.toString i ^ " " ^ atom a ^ ")"
        | Con (tag, t, a) => let val a = atom a in "(con " ^ Int.toString tag ^ " " ^ a ^ " : " ^ ty t ^ ")" end
        | Decon (tag, t, a) => let val a = atom a in "(decon " ^ Int.toString tag ^ " " ^ a ^ " : " ^ ty t ^ ")" end
        | ConTag a => "(tag " ^ atom a ^ ")"
        | NewExn n => "(newexn \"" ^ String.toString n ^ "\")"
        | BuiltinExn k => "(builtinexn " ^ Int.toString k ^ ")"
        | MkExn (c, a) => let val c = atom c in "(mkexn " ^ c ^ " " ^ atom a ^ ")" end
        | ExnCon a => "(exncon " ^ atom a ^ ")"
        | ExnArg (t, a) => let val a = atom a in "(exnarg " ^ a ^ " : " ^ ty t ^ ")" end
        | SetGlobal (x, a) => let val x = g x in "(setglobal " ^ x ^ " " ^ atom a ^ ")" end
      fun params ps =
        "(" ^ String.concatWith " " (List.map (fn (x, t) => let val x = v x in "(" ^ x ^ " : " ^ ty t ^ ")" end) ps) ^ ")"

      (* an expression at indentation n, on a line of its own *)
      fun exp (n, e) =
        case e of
          Let (x, s, r, b) =>
            let val x = v x val s = scheme s
            in nl n; emit ("(let (" ^ x ^ " : " ^ s ^ ") " ^ rhs r); exp (n, b); emit ")" end
        | Fun (fs, b) => (nl n; emit "(fun"; List.app (fn f => fundef (n + 2, f)) fs; exp (n, b); emit ")")
        | Join (l, ps, body, s) =>
            let val l = j l in nl n; emit ("(join " ^ l ^ " " ^ params ps); exp (n + 2, body); exp (n, s); emit ")" end
        | Jump (l, xs) => let val l = j l in nl n; emit ("(jump " ^ l ^ atoms xs ^ ")") end
        | If (c, t, f) => (nl n; emit ("(if " ^ atom c); exp (n + 2, t); exp (n + 2, f); emit ")")
        | Handle (a, x, h) => let val x = v x in nl n; emit ("(handle " ^ x); exp (n + 2, a); exp (n + 2, h); emit ")" end
        | Raise a => (nl n; emit ("(raise " ^ atom a ^ ")"))
        | Return r => (nl n; emit ("(return " ^ rhs r ^ ")"))
        | Mark (({file, start, stop}, frames), a) =>
            if marks then
              (nl n; emit ("(at \"" ^ String.toString file ^ "\" " ^ Int.toString start ^ " " ^ Int.toString stop);
               List.app (fn {name, site = SOME {file, start, stop}} =>
                              emit (" (in \"" ^ String.toString name ^ "\" \"" ^ String.toString file ^ "\" "
                                    ^ Int.toString start ^ " " ^ Int.toString stop ^ ")")
                          | {name, site = NONE} => emit (" (in \"" ^ String.toString name ^ "\")")) frames;
               exp (n, a); emit ")")
            else exp (n, a)
      and fundef (n, f) = fundefNamed (n, v, f)
      and fundefNamed (n, named, {name, tyvars, params = ps, result, body} : fundef) =
        let val name = named name val tvs = tyvarList tyvars val ps = params ps
        in nl n; emit ("(fn " ^ name ^ " " ^ tvs ^ ps ^ " : " ^ ty result); exp (n + 2, body); emit ")" end

      fun def d =
        case d of
          Val (x, s, e) => let val x = g x val s = scheme s in nl 0; emit ("(val " ^ x ^ " : " ^ s); exp (2, e); emit ")" end
        | Funs fs => (nl 0; emit "(funs"; List.app (fn f => fundefNamed (2, g, f)) fs; emit ")")
        | Do (gs, e) =>
            let val gs = List.map (fn (x, s) => let val x = g x in "(" ^ x ^ " : " ^ scheme s ^ ")" end) gs
            in nl 0; emit ("(do (" ^ String.concatWith " " gs ^ ")"); exp (2, e); emit ")" end

      fun decl stamp =
        let val (name, arity) = valOf (IntMap.find (!tycons, stamp))
        in
          case Ty.datatypeOf stamp of
            SOME {params, cons} =>
              let
                val ps = String.concatWith " " (List.map gen params)
                fun con (tag, cname, arg) =
                  " (" ^ Int.toString tag ^ " \"" ^ String.toString cname ^ "\""
                  ^ (case arg of SOME a => " : " ^ ty a | NONE => "") ^ ")"
              in nl 0; emit ("(datatype " ^ name ^ " (" ^ ps ^ ")" ^ String.concat (List.map con cons) ^ ")") end
          | NONE => (nl 0; emit ("(abstract " ^ name ^ " " ^ Int.toString arity ^ ")"))
        end
    in
      List.app decl (List.rev (!order));
      List.app def p;
      case String.concat (List.rev (!out)) of
        "" => ""
      | s => String.extract (s, 1, NONE)
    end

  val show = show' false

  (* with positions: all of the program *)
  val showAll = show' true

  (* ---- reading ---- *)

  exception Syntax of string

  datatype token =
      LP | RP | LB | RB | LBRACE | RBRACE | COLON | COMMA | ARROW | STAR
    | ID of string | TYVAR of string | NUM of string | STR of string | CHR of int

  fun tokenText t =
    case t of
      LP => "(" | RP => ")" | LB => "[" | RB => "]" | LBRACE => "{" | RBRACE => "}"
    | COLON => ":" | COMMA => "," | ARROW => "->" | STAR => "*"
    | ID s => s | TYVAR s => s | NUM s => s | STR s => "\"" ^ String.toString s ^ "\"" | CHR _ => "#\"...\""

  (* The tokens of a text, each with the offset it starts at. *)
  fun tokens (text : string) : (token * int) list =
    let
      val n = String.size text
      fun at i = String.sub (text, i)
      fun isName c = Char.isAlphaNum c orelse c = #"_" orelse c = #"/" orelse c = #"."
      fun span (i, ok) = if i < n andalso ok (at i) then span (i + 1, ok) else i
      (* the end of a quoted text starting after its quote at i: an escape
         is as long as SML's are, \^\ for the character 28 among them *)
      fun quoted i =
        if i >= n then raise Syntax ("an unterminated string at " ^ Int.toString i)
        else case at i of
               #"\"" => i
             | #"\\" =>
                 if i + 1 >= n then quoted (i + 1)
                 else if at (i + 1) = #"^" then quoted (i + 3)
                 else if Char.isDigit (at (i + 1)) then quoted (i + 4)
                 else if at (i + 1) = #"u" then quoted (i + 6)
                 else quoted (i + 2)
             | _ => quoted (i + 1)
      (* the end of a comment whose opening bracket ends before i; comments
         nest *)
      fun comment (i, depth) =
        if i + 1 >= n then raise Syntax "an unterminated comment"
        else if at i = #"*" andalso at (i + 1) = #")" then (if depth = 0 then i + 2 else comment (i + 2, depth - 1))
        else if at i = #"(" andalso at (i + 1) = #"*" then comment (i + 2, depth + 1)
        else comment (i + 1, depth)
      fun unescape (raw, i) =
        if raw = "" then ""
        else case String.fromString raw of
               SOME s => s
             | NONE => raise Syntax ("a bad string at " ^ Int.toString i)
      fun go (i, acc) =
        if i >= n then List.rev acc
        else
          let val c = at i
          in
            if Char.isSpace c then go (i + 1, acc)
            else if c = #"(" andalso i + 1 < n andalso at (i + 1) = #"*" then go (comment (i + 2, 0), acc)
            else
              case c of
                #"(" => go (i + 1, (LP, i) :: acc)
              | #")" => go (i + 1, (RP, i) :: acc)
              | #"[" => go (i + 1, (LB, i) :: acc)
              | #"]" => go (i + 1, (RB, i) :: acc)
              | #"{" => go (i + 1, (LBRACE, i) :: acc)
              | #"}" => go (i + 1, (RBRACE, i) :: acc)
              | #":" => go (i + 1, (COLON, i) :: acc)
              | #"," => go (i + 1, (COMMA, i) :: acc)
              | #"*" => go (i + 1, (STAR, i) :: acc)
              | #"-" =>
                  if i + 1 < n andalso at (i + 1) = #">" then go (i + 2, (ARROW, i) :: acc)
                  else raise Syntax ("a stray - at " ^ Int.toString i)
              | #"\"" =>
                  let val e = quoted (i + 1)
                  in go (e + 1, (STR (unescape (String.substring (text, i + 1, e - i - 1), i)), i) :: acc) end
              | #"#" =>
                  if i + 1 < n andalso at (i + 1) = #"\"" then
                    let
                      val e = quoted (i + 2)
                      val c = case Char.fromString (String.substring (text, i + 2, e - i - 2)) of
                                SOME c => Char.ord c
                              | NONE => raise Syntax ("a bad character at " ^ Int.toString i)
                    in go (e + 1, (CHR c, i) :: acc) end
                  else raise Syntax ("a stray # at " ^ Int.toString i)
              | #"'" => let val e = span (i + 1, fn c => Char.isAlphaNum c orelse c = #"_")
                        in go (e, (TYVAR (String.substring (text, i, e - i)), i) :: acc) end
              | _ =>
                  if Char.isDigit c orelse (c = #"~" andalso i + 1 < n andalso Char.isDigit (at (i + 1))) then
                    let val e = span (i + 1, fn c => Char.isAlphaNum c orelse c = #"." orelse c = #"~")
                    in go (e, (NUM (String.substring (text, i, e - i)), i) :: acc) end
                  else if Char.isAlpha c orelse c = #"_" then
                    let val e = span (i, isName)
                    in go (e, (ID (String.substring (text, i, e - i)), i) :: acc) end
                  else raise Syntax ("an unexpected " ^ String.str c ^ " at " ^ Int.toString i)
          end
    in go (0, []) end

  (* A program from its text, as `show` or `showAll` wrote it. Its datatypes
     are made anew and registered (Ty.bindDatatypeDirect). *)
  fun parse (text : string) : program =
    let
      val toks = ref (tokens text)
      fun peek () = case !toks of (t, _) :: _ => SOME t | [] => NONE
      fun peek2 () = case !toks of _ :: (t, _) :: _ => SOME t | _ => NONE
      fun where' () = case !toks of (_, i) :: _ => " at " ^ Int.toString i | [] => " at the end"
      fun fail what = raise Syntax ("expected " ^ what ^ where' ())
      fun next () = case !toks of (t, _) :: rest => (toks := rest; t) | [] => fail "more"
      fun eat t = if peek () = SOME t then ignore (next ()) else fail (tokenText t)
      fun id () = case next () of ID s => s | _ => fail "a name"
      fun keyword k = case next () of ID s => if s = k then () else fail k | _ => fail k
      fun int () =
        case next () of
          NUM s => (case Int.fromString s of SOME i => i | NONE => fail "a number")
        | _ => fail "a number"
      fun str () = case next () of STR s => s | _ => fail "a string"

      (* names to stamps *)
      val names : int StringMap.map ref = ref StringMap.empty
      fun stampOf s =
        case StringMap.find (!names, s) of
          SOME x => x
        | NONE => let val x = Elaborate.freshStamp () in names := StringMap.insert (!names, s, x); x end
      fun var prefix () =
        let val s = id ()
        in if String.isPrefix prefix s then stampOf s else fail ("a name " ^ prefix ^ "N") end
      val tyvarIds : int StringMap.map ref = ref StringMap.empty
      fun tyvarId s =
        case StringMap.find (!tyvarIds, s) of
          SOME x => x
        | NONE => let val x = Elaborate.freshStamp () in tyvarIds := StringMap.insert (!tyvarIds, s, x); x end
      fun tyvar () = case next () of TYVAR s => tyvarId s | _ => fail "a type variable"

      (* type names: the built-in ones, and those the text declares *)
      val tycons : (int * string) StringMap.map ref =
        ref (List.foldl (fn ((stamp, n), m) => StringMap.insert (m, n, (stamp, n))) StringMap.empty builtinNames)
      fun base n = case String.fields (fn c => c = #"/") n of b :: _ => b | [] => n
      fun declare (n, arity) =
        let val c = Types.freshTycon (base n, arity, true)
        in tycons := StringMap.insert (!tycons, n, (#stamp c, base n)); #stamp c end

      (* every type the text declares, first, since a datatype may use one
         declared after it *)
      val () =
        let
          fun scan ts =
            case ts of
              (LP, _) :: (ID "datatype", _) :: (ID n, _) :: (LP, _) :: rest =>
                let
                  fun count ((TYVAR _, _) :: rest, k) = count (rest, k + 1)
                    | count (rest, k) = (k, rest)
                  val (k, rest) = count (rest, 0)
                in ignore (declare (n, k)); scan rest end
            | (LP, _) :: (ID "abstract", _) :: (ID n, _) :: (NUM a, _) :: rest =>
                (ignore (declare (n, valOf (Int.fromString a))); scan rest)
            | _ :: rest => scan rest
            | [] => ()
        in scan (!toks) end

      fun ty () : Ty.ty =
        let val t = tuple ()
        in if peek () = SOME ARROW then (ignore (next ()); Ty.Arrow (t, ty ())) else t end
      and tuple () =
        let
          fun more acc = if peek () = SOME STAR then (ignore (next ()); more (app () :: acc)) else List.rev acc
        in case more [app ()] of [t] => t | ts => Ty.Tuple ts end
      and app () = postfix (atomic ())
      and postfix args =
        case peek () of
          SOME (ID n) => (ignore (next ()); postfix [named (n, args)])
        | _ => (case args of [t] => t | _ => fail "a type name after a list of types")
      and named (n, args) =
        case (n, args) of
          ("unit", []) => Ty.Tuple []
        | ("exncon", []) => Ty.ExnCon
        | _ =>
            (case StringMap.find (!tycons, n) of
               SOME (stamp, b) => Ty.Con (stamp, b, args)
             | NONE => raise Syntax ("an undeclared type " ^ n ^ where' ()))
      and atomic () : Ty.ty list =
        case next () of
          TYVAR s => [if String.isPrefix "'_" s then Ty.Var (tyvarId s) else Ty.Gen (tyvarId s)]
        | ID n => [named (n, [])]
        | LBRACE => let val t = ty () in eat RBRACE; [Ty.Tuple [t]] end
        | LP =>
            let
              fun more acc =
                case next () of
                  COMMA => more (ty () :: acc)
                | RP => List.rev acc
                | _ => fail ", or )"
            in more [ty ()] end
        | _ => fail "a type"

      fun tyvars () =
        if peek () = SOME LB then
          let
            val () = eat LB
            fun more acc = if peek () = SOME RB then (eat RB; List.rev acc) else more (tyvar () :: acc)
          in more [] end
        else []
      fun scheme () : scheme = let val tvs = tyvars () in (tvs, ty ()) end
      fun tyargs () =
        if peek () = SOME LB then
          let
            val () = eat LB
            fun more acc =
              case next () of
                COMMA => more (ty () :: acc)
              | RB => List.rev acc
              | _ => fail ", or ]"
          in more [ty ()] end
        else []

      fun const (s : string) : Lambda.const * Ty.ty =
        if String.isPrefix "0w" s then
          (case IntInf.fromString (String.extract (s, 2, NONE)) of
             SOME w => (Lambda.CWord w, defaultTy (Lambda.CWord w))
           | NONE => fail "a word")
        else if CharVector.exists (fn c => c = #"." orelse c = #"E" orelse c = #"e") s then
          (Lambda.CReal s, defaultTy (Lambda.CReal s))
        else
          (case IntInf.fromString s of
             SOME i => (Lambda.CInt i, Ty.int)
           | NONE => fail "a number")

      fun atom () : atom =
        case next () of
          ID s =>
            if String.isPrefix "v" s then Var (stampOf s, tyargs ())
            else if String.isPrefix "g" s then Global (stampOf s, tyargs ())
            else fail "a variable"
        | NUM s => Const (const s)
        | STR s => Const (Lambda.CString s, Ty.string)
        | CHR c => Const (Lambda.CChar c, defaultTy (Lambda.CChar c))
        | LP =>
            (case next () of
               RP => Unit
             | ID "con0" => let val tag = int () val () = eat COLON val t = ty () in eat RP; Con0 (tag, t) end
             | t =>
                 let
                   val c = case t of
                             NUM s => #1 (const s)
                           | STR s => Lambda.CString s
                           | CHR c => Lambda.CChar c
                           | _ => fail "a constant"
                   val () = eat COLON
                   val t = ty ()
                 in eat RP; Const (c, t) end)
        | _ => fail "an atom"
      fun atomsUntil stop =
        let fun more acc = if peek () = SOME stop then List.rev acc else more (atom () :: acc)
        in more [] end

      val rhsKeywords = ["app", "prim", "tuple", "select", "con", "decon", "tag", "newexn", "builtinexn",
                         "mkexn", "exncon", "exnarg", "setglobal"]
      fun rhs () : rhs =
        case (peek (), peek2 ()) of
          (SOME LP, SOME (ID k)) =>
            if List.exists (fn x => x = k) rhsKeywords then
              let
                val () = (eat LP; ignore (next ()))
                val r =
                  case k of
                    "app" => let val f = atom () in App (f, atomsUntil RP) end
                  | "prim" =>
                      let val p = id () val xs = atomsUntil COLON val () = eat COLON in Prim (p, ty (), xs) end
                  | "tuple" => Tuple (atomsUntil RP)
                  | "select" => let val i = int () in Select (i, atom ()) end
                  | "con" => let val tag = int () val a = atom () val () = eat COLON in Con (tag, ty (), a) end
                  | "decon" => let val tag = int () val a = atom () val () = eat COLON in Decon (tag, ty (), a) end
                  | "tag" => ConTag (atom ())
                  | "newexn" => NewExn (str ())
                  | "builtinexn" => BuiltinExn (int ())
                  | "mkexn" => let val c = atom () in MkExn (c, atom ()) end
                  | "exncon" => ExnCon (atom ())
                  | "exnarg" => let val a = atom () val () = eat COLON in ExnArg (ty (), a) end
                  | _ => let val g = var "g" () in SetGlobal (g, atom ()) end
              in eat RP; r end
            else Atom (atom ())
        | _ => Atom (atom ())

      fun binder () = let val () = eat LP val x = var "v" () val () = eat COLON val t = ty () in eat RP; (x, t) end
      fun binders () =
        let
          val () = eat LP
          fun more acc = if peek () = SOME RP then (eat RP; List.rev acc) else more (binder () :: acc)
        in more [] end

      fun fundef () : fundef = fundefNamed "v"
      and fundefNamed prefix : fundef =
        let
          val () = (eat LP; keyword "fn")
          val name = var prefix ()
          val tvs = tyvars ()
          val ps = binders ()
          val () = eat COLON
          val result = ty ()
          val body = exp ()
        in eat RP; {name = name, tyvars = tvs, params = ps, result = result, body = body} end

      and exp () : exp =
        let
          val () = eat LP
          val e =
            case id () of
              "let" =>
                let
                  val () = eat LP
                  val x = var "v" ()
                  val () = eat COLON
                  val s = scheme ()
                  val () = eat RP
                  val r = rhs ()
                in Let (x, s, r, exp ()) end
            | "fun" =>
                let
                  fun more acc =
                    if peek2 () = SOME (ID "fn") then more (fundef () :: acc) else Fun (List.rev acc, exp ())
                in more [] end
            | "join" => let val l = var "j" () val ps = binders () val b = exp () in Join (l, ps, b, exp ()) end
            | "jump" => let val l = var "j" () in Jump (l, atomsUntil RP) end
            | "if" => let val c = atom () val t = exp () in If (c, t, exp ()) end
            | "handle" => let val x = var "v" () val a = exp () in Handle (a, x, exp ()) end
            | "raise" => Raise (atom ())
            | "return" => Return (rhs ())
            | "at" =>
                let
                  val file = str () val start = int () val stop = int ()
                  fun frames acc =
                    if peek () = SOME LP andalso peek2 () = SOME (ID "in") then
                      let
                        val () = (eat LP; ignore (next ()))
                        val name = str ()
                        val site =
                          if peek () = SOME RP then NONE
                          else let val f = str () val s = int () val e = int () in SOME {file = f, start = s, stop = e} end
                      in eat RP; frames ({name = name, site = site} :: acc) end
                    else List.rev acc
                  val fs = frames []
                in Mark (({file = file, start = start, stop = stop}, fs), exp ()) end
            | k => raise Syntax ("an unknown form " ^ k ^ where' ())
        in eat RP; e end

      fun top acc =
        case (peek (), peek2 ()) of
          (NONE, _) => List.rev acc
        | (SOME LP, SOME (ID "datatype")) =>
            let
              val () = (eat LP; ignore (next ()))
              val n = id ()
              val () = eat LP
              fun params acc = if peek () = SOME RP then (eat RP; List.rev acc) else params (tyvar () :: acc)
              val ps = params []
              val stamp = case StringMap.find (!tycons, n) of SOME (stamp, _) => stamp | NONE => fail "a declared type"
              fun cons acc =
                if peek () = SOME RP then (eat RP; List.rev acc)
                else
                  let
                    val () = eat LP
                    val tag = int ()
                    val cname = str ()
                    val arg = if peek () = SOME COLON then (eat COLON; SOME (ty ())) else NONE
                  in eat RP; cons ((tag, cname, arg) :: acc) end
            in Ty.bindDatatypeDirect (stamp, {params = ps, cons = cons []}); top acc end
        | (SOME LP, SOME (ID "abstract")) =>
            let val () = (eat LP; ignore (next ())) val _ = id () val _ = int ()
            in eat RP; top acc end
        | (SOME LP, SOME (ID "val")) =>
            let
              val () = (eat LP; ignore (next ()))
              val g = var "g" ()
              val () = eat COLON
              val s = scheme ()
              val e = exp ()
            in eat RP; top (Val (g, s, e) :: acc) end
        | (SOME LP, SOME (ID "funs")) =>
            let
              val () = (eat LP; ignore (next ()))
              fun more fs = if peek () = SOME RP then (eat RP; List.rev fs) else more (fundefNamed "g" :: fs)
            in top (Funs (more []) :: acc) end
        | (SOME LP, SOME (ID "do")) =>
            let
              val () = (eat LP; ignore (next ()); eat LP)
              fun more gs =
                if peek () = SOME RP then (eat RP; List.rev gs)
                else
                  let val () = eat LP val g = var "g" () val () = eat COLON val s = scheme ()
                  in eat RP; more ((g, s) :: gs) end
              val gs = more []
              val e = exp ()
            in eat RP; top (Do (gs, e) :: acc) end
        | _ => fail "a declaration or a definition"
    in
      top []
    end

  (* Whether printing what `parse` reads of the printed program prints it
     again, positions and all: the check of the two against each other. *)
  fun roundTrip (p : program) : unit =
    let
      val text = showAll p
      val again = showAll (parse text) handle Syntax msg => Error.bug ("MidText.parse: " ^ msg)
    in
      if text = again then ()
      else
        let
          val a = String.fields (fn c => c = #"\n") text
          val b = String.fields (fn c => c = #"\n") again
          fun first (x :: xs, y :: ys, i) = if x = y then first (xs, ys, i + 1) else (i, x, y)
            | first (x :: _, [], i) = (i, x, "")
            | first ([], y :: _, i) = (i, "", y)
            | first ([], [], i) = (i, "", "")
          val (i, x, y) = first (a, b, 1)
        in
          Error.bug ("Mid printed, read and printed again differs at line " ^ Int.toString i ^ ": "
                     ^ x ^ " / " ^ y)
        end
    end
end
