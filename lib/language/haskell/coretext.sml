(* Core's text: a lexer into tokens, a reader of parenthesised forms, the
   forms read as Core, and Core printed through the same forms
   (coretext_sig.sml). *)
structure CoreText : CORE_TEXT =
struct
  open Core

  exception Error of int * string

  (* ---- Forms ---- *)

  (* a form of the text, with the line it starts on: a list, a word, a name
     between backquotes, a string, a character, and a form after `@` or `!` *)
  datatype form =
      FList of form list * int
    | FWord of string * int
    | FName of string * int
    | FStr of string * int
    | FChar of int * int
    | FAt of form * int
    | FBang of form * int

  fun lineOf f =
    case f of
      FList (_, l) => l | FWord (_, l) => l | FName (_, l) => l | FStr (_, l) => l
    | FChar (_, l) => l | FAt (_, l) => l | FBang (_, l) => l

  fun fail (l, msg) = raise Error (l, msg)

  (* ---- Lexing and reading ---- *)

  fun delimiter c = Char.isSpace c orelse c = #"(" orelse c = #")" orelse c = #"\"" orelse c = #";" orelse c = #"`"

  (* the forms of `text`, in order *)
  fun forms (text : string) : form list =
    let
      val n = size text
      fun at i = String.sub (text, i)
      (* the decimal digits from i: their value and where they end *)
      fun digits (i, acc, count, most) =
        if i < n andalso count < most andalso Char.isDigit (at i)
        then digits (i + 1, acc * 10 + (Char.ord (at i) - 48), count + 1, most)
        else (acc, i, count)
      (* an escape after a backslash at i - 1, in a string (bytes) or a
         character (a code point): its value and where it ends *)
      fun escape (line, i, inChar) =
        if i >= n then fail (line, "the text ends in an escape")
        else
          case at i of
            #"\\" => (92, i + 1)
          | #"\"" => (34, i + 1)
          | #"'" => if inChar then (39, i + 1) else fail (line, "\\' in a string: write '")
          | #"n" => (10, i + 1)
          | #"t" => (9, i + 1)
          | c =>
              if Char.isDigit c then
                let val (v, j, count) = digits (i, 0, 0, if inChar then 7 else 3)
                in
                  if not inChar andalso count <> 3 then fail (line, "a byte of a string is three decimal digits after \\")
                  else if not inChar andalso v > 255 then fail (line, "a byte of a string is at most \\255")
                  else (v, j)
                end
              else fail (line, "an unknown escape \\" ^ String.str c)
      (* the items of a list that starts after i, on line start, to its `)` *)
      fun items (start, i, line, acc) =
        let val (i, line) = skip (i, line)
        in
          if i >= n then fail (start, "a list that starts on this line is not closed")
          else if at i = #")" then (List.rev acc, i + 1, line)
          else let val (f, i, line) = one (i, line) in items (start, i, line, f :: acc) end
        end
      (* past spaces and comments *)
      and skip (i, line) =
        if i >= n then (i, line)
        else if at i = #"\n" then skip (i + 1, line + 1)
        else if Char.isSpace (at i) then skip (i + 1, line)
        else if at i = #";" then
          let fun eol j = if j >= n orelse at j = #"\n" then j else eol (j + 1)
          in skip (eol i, line) end
        else (i, line)
      (* one form at i, after spaces *)
      and one (i, line) : form * int * int =
        let val c = at i
        in
          if c = #"(" then let val (fs, j, l) = items (line, i + 1, line, []) in (FList (fs, line), j, l) end
          else if c = #")" then fail (line, "a ) with no ( before it")
          else if c = #"@" orelse c = #"!" then
            let
              val (i', line') = (i + 1, line)
              val () = if i' >= n orelse delimiter (at i') andalso at i' <> #"(" andalso at i' <> #"`"
                       then fail (line, String.str c ^ " with nothing after it") else ()
              val (f, j, l) = one (i', line')
            in (if c = #"@" then FAt (f, line) else FBang (f, line), j, l) end
          else if c = #"\"" then
            let
              fun str (j, acc) =
                if j >= n then fail (line, "the text ends inside a string")
                else if at j = #"\"" then (FStr (String.implode (List.rev acc), line), j + 1, line)
                else if at j = #"\n" then fail (line, "a string goes past the end of its line")
                else if at j = #"\\" then
                  let val (v, k) = escape (line, j + 1, false) in str (k, Char.chr v :: acc) end
                else str (j + 1, at j :: acc)
            in str (i + 1, []) end
          else if c = #"'" then
            let
              val (v, j) =
                if i + 1 >= n then fail (line, "the text ends inside a character")
                else if at (i + 1) = #"\\" then escape (line, i + 2, true)
                else if at (i + 1) = #"'" orelse at (i + 1) = #"\n" then fail (line, "an empty character")
                else (Char.ord (at (i + 1)), i + 2)
            in
              if j < n andalso at j = #"'" then (FChar (v, line), j + 1, line)
              else fail (line, "a character is one letter or escape between ' and '")
            end
          else if c = #"`" then
            let
              fun name (j, acc) =
                if j >= n orelse at j = #"\n" then fail (line, "a name between backquotes goes past the end of its line")
                else if at j = #"`" then
                  if null acc then fail (line, "an empty name") else (FName (String.implode (List.rev acc), line), j + 1, line)
                else if at j = #"\\" andalso j + 1 < n andalso (at (j + 1) = #"\\" orelse at (j + 1) = #"`")
                then name (j + 2, at (j + 1) :: acc)
                else if at j = #"\\" andalso j + 1 < n andalso Char.isDigit (at (j + 1)) then
                  let val (v, k, count) = digits (j + 1, 0, 0, 3)
                  in if count = 3 andalso v <= 255 then name (k, Char.chr v :: acc)
                     else fail (line, "a byte of a name is three decimal digits after \\") end
                else name (j + 1, at j :: acc)
            in name (i + 1, []) end
          else
            let fun word j = if j < n andalso not (delimiter (at j)) then word (j + 1) else j
                val j = word i
            in (FWord (String.substring (text, i, j - i), line), j, line) end
        end
      fun top (i, line, acc) =
        let val (i, line) = skip (i, line)
        in if i >= n then List.rev acc else let val (f, i, line) = one (i, line) in top (i, line, f :: acc) end end
    in top (0, 1, []) end

  (* ---- Words ---- *)

  val keywords = ["\\", "let", "letrec", "case", "con", "prim", "utuple", "cast", "forall", "->", "data", "newtype",
                  "val", "import", "_", "*", "#"]
  fun member (x, xs) = List.exists (fn y => y = x) xs
  fun isKeyword w = member (w, keywords)

  (* whether a word starts as a number does: a digit, or - and a digit *)
  fun numeric w =
    size w > 0 andalso (Char.isDigit (String.sub (w, 0))
                        orelse size w > 1 andalso String.sub (w, 0) = #"-" andalso Char.isDigit (String.sub (w, 1)))

  fun showName x =
    let
      val plain =
        x <> "" andalso not (isKeyword x) andalso not (numeric x)
        andalso not (member (String.sub (x, 0), [#"'", #"@", #"!"]))
        andalso CharVector.all (fn c => not (delimiter c) andalso Char.ord c > 32 andalso Char.ord c <> 127) x
      fun esc c =
        if c = #"`" then "\\`" else if c = #"\\" then "\\\\"
        else if Char.ord c < 32 orelse Char.ord c = 127 then
          "\\" ^ StringCvt.padLeft #"0" 3 (Int.toString (Char.ord c))
        else String.str c
    in if plain then x else "`" ^ String.translate esc x ^ "`" end

  fun showLit l =
    let
      fun int i = if IntInf.< (i, 0) then "-" ^ IntInf.toString (IntInf.~ i) else IntInf.toString i
      fun byte inChar c =
        let val k = Char.ord c
        in
          if c = #"\\" then "\\\\"
          else if c = #"\"" andalso not inChar then "\\\""
          else if c = #"'" andalso inChar then "\\'"
          else if c = #"\n" then "\\n"
          else if c = #"\t" then "\\t"
          else if k < 32 orelse k >= 127 then "\\" ^ (if inChar then Int.toString k else StringCvt.padLeft #"0" 3 (Int.toString k))
          else String.str c
        end
    in
      case l of
        LInt i => int i
      | LInteger i => int i ^ "I"
      | LDouble s => s
      | LFloat s => s ^ "F"
      | LStr s => "\"" ^ String.translate (byte false) s ^ "\""
      | LChar c => if c >= 32 andalso c < 127 then "'" ^ byte true (Char.chr c) ^ "'" else "'\\" ^ Int.toString c ^ "'"
    end

  (* the literal a numeric word is *)
  fun literalOf (w, line) =
    let
      fun bad () = fail (line, "not a literal: " ^ w)
      val (body, suffix) =
        if String.isSuffix "I" w then (String.substring (w, 0, size w - 1), "I")
        else if String.isSuffix "F" w then (String.substring (w, 0, size w - 1), "F")
        else (w, "")
      val digitsOnly = fn s => s <> "" andalso CharVector.all Char.isDigit s
      val unsigned = if String.isPrefix "-" body then String.extract (body, 1, NONE) else body
      fun integer () = case IntInf.fromString (if String.isPrefix "-" body then "~" ^ unsigned else unsigned) of
                         SOME i => i | NONE => bad ()
      (* digits [. digits] [e [+-] digits], with a point or an exponent, as
         Haskell writes one (2.5's float) *)
      fun floating s =
        let
          val (mant, ex) = case String.fields (fn c => c = #"e" orelse c = #"E") s of
                             [m] => (m, NONE) | [m, e] => (m, SOME e) | _ => bad ()
          val okMant = case String.fields (fn c => c = #".") mant of
                         [a] => digitsOnly a | [a, b] => digitsOnly a andalso digitsOnly b | _ => false
          val okEx = case ex of
                       NONE => true
                     | SOME e => digitsOnly (if String.isPrefix "-" e orelse String.isPrefix "+" e then String.extract (e, 1, NONE)
                                             else e)
        in okMant andalso okEx andalso (isSome ex orelse CharVector.exists (fn c => c = #".") mant) end
    in
      if suffix = "I" then if digitsOnly unsigned then LInteger (integer ()) else bad ()
      else if digitsOnly unsigned andalso suffix = "" then LInt (integer ())
      else if floating unsigned then (if suffix = "F" then LFloat body else LDouble body)
      else bad ()
    end

  (* ---- Forms read as Core ---- *)

  fun nameOf f =
    case f of
      FWord (w, l) =>
        if isKeyword w then fail (l, "a word of the syntax where a name is wanted: " ^ w ^ " (write `" ^ w ^ "`)")
        else if numeric w then fail (l, "a literal where a name is wanted: " ^ w)
        else w
    | FName (x, _) => x
    | _ => fail (lineOf f, "a name is wanted")

  (* a binder of a case, an alternative or a lambda: a name, or _ for none *)
  fun binderName f = case f of FWord ("_", _) => "_" | _ => nameOf f

  fun kindOf f =
    case f of
      FWord ("*", _) => Star
    | FWord ("#", _) => Unlifted
    | FList (FWord ("->", _) :: (ks as _ :: _ :: _), _) =>
        let val ks = List.map kindOf ks
        in List.foldr Arrow (List.last ks) (List.take (ks, length ks - 1)) end
    | _ => fail (lineOf f, "not a kind: a kind is *, # or (-> KIND KIND ...)")

  (* a parameter of a type: a, or (a KIND) *)
  fun typaram f =
    case f of
      FList ([a, k], _) => (nameOf a, kindOf k)
    | _ => (nameOf f, Star)

  (* a type, in the scope of the type variables `scope` *)
  fun tyOf scope f =
    case f of
      FWord ("->", _) => TCon "->"
    | FWord _ => let val x = nameOf f in if member (x, scope) then TVar x else TCon x end
    | FName (x, _) => if member (x, scope) then TVar x else TCon x
    | FBang (t, _) => TEval (tyOf scope t)
    | FList ([FWord ("->", _)], _) => TCon "->"
    | FList ([FWord ("->", _), t], _) => TApp (TCon "->", tyOf scope t)
    | FList (FWord ("->", _) :: ts, _) =>
        (* the function type; `->` given fewer than two types, its
           constructor (Haskell's `(->)`) *)
        let val ts = List.map (tyOf scope) ts
        in List.foldr TFun (List.last ts) (List.take (ts, length ts - 1)) end
    | FList ([FWord ("forall", _), FList (ps, _), body], _) =>
        let val ps = List.map typaram ps
        in List.foldr (fn ((a, k), t) => TForall (a, k, t)) (tyOf (List.map #1 ps @ scope) body) ps end
    | FList (FWord ("forall", l) :: _, _) => fail (l, "a forall is (forall (TYPARAM ...) TYPE)")
    | FList (FWord ("utuple", _) :: ts, _) => TUTuple (List.map (tyOf scope) ts)
    | FList (h :: (args as _ :: _), _) => apply (tyOf scope h, List.map (tyOf scope) args)
    | _ => fail (lineOf f, "not a type")

  fun atomOf f =
    case f of
      FWord (w, l) => if numeric w then Lit (literalOf (w, l)) else Var (nameOf f)
    | FName (x, _) => Var x
    | FStr (s, _) => Lit (LStr s)
    | FChar (c, _) => Lit (LChar c)
    | _ => fail (lineOf f, "an atom, a name or a literal, is wanted")

  fun isAtomForm f = case f of FWord _ => true | FName _ => true | FStr _ => true | FChar _ => true | _ => false

  (* types after @, then atoms *)
  fun typesAndAtoms scope fs =
    let
      fun go (FAt (t, _) :: rest, tys) = go (rest, tyOf scope t :: tys)
        | go (rest, tys) = (List.rev tys, List.map atomOf rest)
    in go (fs, []) end

  fun expOf scope f =
    case f of
      FList ([FWord ("\\", l), FList (bs, _), body], _) =>
        let
          fun binders ([], scope, acc) = (List.rev acc, scope)
            | binders (FAt (FList ([a, k], _), _) :: rest, scope, acc) =
                let val a = nameOf a in binders (rest, a :: scope, TyBinder (a, kindOf k) :: acc) end
            | binders (FAt (a, _) :: rest, scope, acc) =
                let val a = nameOf a in binders (rest, a :: scope, TyBinder (a, Star) :: acc) end
            | binders (FList ([x, t], _) :: rest, scope, acc) =
                binders (rest, scope, ValBinder (binderName x, tyOf scope t) :: acc)
            | binders (b :: _, _, _) = fail (lineOf b, "a binder of a lambda is (x TYPE), @a or @(a KIND)")
          val (bs, scope') = binders (bs, scope, [])
        in if null bs then fail (l, "a lambda binds nothing") else Lam (bs, expOf scope' body) end
    | FList (FWord ("\\", l) :: _, _) => fail (l, "a lambda is (\\ (BINDER ...) EXP)")
    | FList ([FWord ("let", _), FList ([x, t, e], _), body], _) =>
        Let (nameOf x, tyOf scope t, expOf scope e, expOf scope body)
    | FList (FWord ("let", l) :: _, _) => fail (l, "a let is (let (x TYPE EXP) EXP)")
    | FList ([FWord ("letrec", l), FList (bs, _), body], _) =>
        let
          fun bind (FList ([x, t, e], _)) = (nameOf x, tyOf scope t, expOf scope e)
            | bind b = fail (lineOf b, "a binding of a letrec is (x TYPE EXP)")
        in if null bs then fail (l, "a letrec binds nothing") else LetRec (List.map bind bs, expOf scope body) end
    | FList (FWord ("letrec", l) :: _, _) => fail (l, "a letrec is (letrec ((x TYPE EXP) ...) EXP)")
    | FList (FWord ("case", l) :: scrut :: b :: alts, _) =>
        if null alts then fail (l, "a case has no alternative")
        else Case (expOf scope scrut, binderName b, List.map (altOf scope) alts)
    | FList (FWord ("case", l) :: _, _) => fail (l, "a case is (case EXP x ALT ...)")
    | FList (FWord ("con", _) :: c :: rest, _) =>
        let val (tys, atoms) = typesAndAtoms scope rest in Con (nameOf c, tys, atoms) end
    | FList (FWord ("prim", _) :: p :: rest, _) =>
        let val (tys, atoms) = typesAndAtoms scope rest in Prim (nameOf p, tys, atoms) end
    | FList (FWord ("utuple", _) :: atoms, _) => UTuple (List.map atomOf atoms)
    | FList ([FWord ("cast", _), e, t], _) => Cast (expOf scope e, tyOf scope t)
    | FList (FWord ("cast", l) :: _, _) => fail (l, "a cast is (cast EXP TYPE)")
    | FList (FWord (w, l) :: _, _) =>
        if isKeyword w then fail (l, "a word of the syntax at the head of an application: " ^ w)
        else app scope f
    | FList (_ :: _ :: _, _) => app scope f
    | FList (_, l) => fail (l, "an empty or a lone form: an application has an argument")
    | FAt (_, l) => fail (l, "a type where an expression is wanted")
    | FBang (_, l) => fail (l, "! in an expression")
    | _ => Atom (atomOf f)

  and app scope f =
    case f of
      FList (h :: args, l) =>
        if null args then fail (l, "an application has an argument")
        else
          App (expOf scope h,
               List.map (fn FAt (t, _) => TyArg (tyOf scope t)
                          | a => if isAtomForm a then ValArg (atomOf a)
                                 else fail (lineOf a, "an argument is an atom or @TYPE: let-bind it")) args)
    | _ => fail (lineOf f, "an application is wanted")

  and altOf scope f =
    case f of
      FList ([FWord ("_", _), rhs], _) => AltDefault (expOf scope rhs)
    | FList ([FList (FWord ("utuple", _) :: xs, _), rhs], _) => AltUTuple (List.map binderName xs, expOf scope rhs)
    | FList ([FList (c :: xs, _), rhs], _) => AltCon (nameOf c, List.map binderName xs, expOf scope rhs)
    | FList ([FWord (w, l), rhs], _) =>
        if numeric w then AltLit (literalOf (w, l), expOf scope rhs)
        else fail (l, "a pattern is (C x ...), (utuple x ...), a literal or _")
    | FList ([FChar (c, _), rhs], _) => AltLit (LChar c, expOf scope rhs)
    | _ => fail (lineOf f, "an alternative is (PATTERN EXP)")

  fun declOf f =
    case f of
      FList (FWord ("data", _) :: t :: FList (ps, _) :: cons, _) =>
        let
          val ps = List.map typaram ps
          val scope = List.map #1 ps
          fun con (FList (c :: fields, _)) = (nameOf c, List.map (tyOf scope) fields)
            | con c = fail (lineOf c, "a constructor is (C TYPE ...)")
        in Data (nameOf t, ps, List.map con cons) end
    | FList (FWord ("data", l) :: _, _) => fail (l, "a data type is (data T (TYPARAM ...) (C TYPE ...) ...)")
    | FList ([FWord ("newtype", _), t, FList (ps, _), c, field], _) =>
        let val ps = List.map typaram ps
        in Newtype (nameOf t, ps, nameOf c, tyOf (List.map #1 ps) field) end
    | FList (FWord ("newtype", l) :: _, _) => fail (l, "a newtype is (newtype T (TYPARAM ...) C TYPE)")
    | FList ([FWord ("val", _), x, t, e], _) => Val (nameOf x, tyOf [] t, expOf [] e)
    | FList (FWord ("val", l) :: _, _) => fail (l, "a value is (val x TYPE EXP)")
    | FList ([FWord ("import", _), x, t], _) => Import (nameOf x, tyOf [] t)
    | FList (FWord ("import", l) :: _, _) => fail (l, "an import is (import x TYPE)")
    | _ => fail (lineOf f, "a declaration is (data ...), (newtype ...), (val ...) or (import ...)")

  fun parse text = List.map declOf (forms text)

  fun parseType text =
    case forms text of
      [f] => tyOf [] f
    | _ => fail (1, "not one type")

  (* ---- Core as forms ---- *)

  fun w s = FWord (s, 0)
  fun name x = FWord (showName x, 0)
  fun list fs = FList (fs, 0)
  fun at f = FAt (f, 0)
  fun bang f = FBang (f, 0)

  fun kindForm k =
    case k of
      Star => w "*"
    | Unlifted => w "#"
    | Arrow _ =>
        let fun go (Arrow (a, b)) = a :: go b | go k = [k]
        in list (w "->" :: List.map kindForm (go k)) end

  fun typaramForm (a, Star) = name a
    | typaramForm (a, k) = list [name a, kindForm k]

  fun tyForm t =
    case t of
      TVar a => name a
    | TCon "->" => w "->"
    | TCon c => name c
    | TApp _ => let val (h, args) = spine t in list (tyForm h :: List.map tyForm args) end
    | TFun _ =>
        let fun go (TFun (a, b)) = a :: go b | go t = [t]
        in list (w "->" :: List.map tyForm (go t)) end
    | TForall _ =>
        let fun go (TForall (a, k, b), ps) = go (b, (a, k) :: ps) | go (b, ps) = (List.rev ps, b)
            val (ps, body) = go (t, [])
        in list [w "forall", list (List.map typaramForm ps), tyForm body] end
    | TEval a => bang (tyForm a)
    | TUTuple ts => list (w "utuple" :: List.map tyForm ts)

  fun litForm l = FWord (showLit l, 0)

  fun atomForm (Var x) = name x
    | atomForm (Lit l) = litForm l

  fun binderOut x = if x = "_" then w "_" else name x

  fun expForm e =
    case e of
      Atom a => atomForm a
    | App (f, args) => list (expForm f :: List.map (fn TyArg t => at (tyForm t) | ValArg a => atomForm a) args)
    | Lam (bs, body) =>
        list [w "\\",
              list (List.map (fn TyBinder (a, Star) => at (name a)
                               | TyBinder (a, k) => at (list [name a, kindForm k])
                               | ValBinder (x, t) => list [binderOut x, tyForm t]) bs),
              expForm body]
    | Let (x, t, rhs, body) => list [w "let", list [name x, tyForm t, expForm rhs], expForm body]
    | LetRec (bs, body) =>
        list [w "letrec", list (List.map (fn (x, t, rhs) => list [name x, tyForm t, expForm rhs]) bs), expForm body]
    | Case (scrut, b, alts) => list (w "case" :: expForm scrut :: binderOut b :: List.map altForm alts)
    | Con (c, tys, atoms) => list (w "con" :: name c :: List.map (at o tyForm) tys @ List.map atomForm atoms)
    | Prim (p, tys, atoms) => list (w "prim" :: name p :: List.map (at o tyForm) tys @ List.map atomForm atoms)
    | UTuple atoms => list (w "utuple" :: List.map atomForm atoms)
    | Cast (e, t) => list [w "cast", expForm e, tyForm t]

  and altForm a =
    case a of
      AltCon (c, xs, rhs) => list [list (name c :: List.map binderOut xs), expForm rhs]
    | AltLit (l, rhs) => list [litForm l, expForm rhs]
    | AltUTuple (xs, rhs) => list [list (w "utuple" :: List.map binderOut xs), expForm rhs]
    | AltDefault rhs => list [w "_", expForm rhs]

  fun declForm d =
    case d of
      Data (t, ps, cons) =>
        list (w "data" :: name t :: list (List.map typaramForm ps)
              :: List.map (fn (c, fields) => list (name c :: List.map tyForm fields)) cons)
    | Newtype (t, ps, c, field) => list [w "newtype", name t, list (List.map typaramForm ps), name c, tyForm field]
    | Val (x, t, e) => list [w "val", name x, tyForm t, expForm e]
    | Import (x, t) => list [w "import", name x, tyForm t]

  (* ---- Forms as text ---- *)

  val width = 100

  (* a form on one line *)
  fun flat f =
    case f of
      FList (fs, _) => "(" ^ String.concatWith " " (List.map flat fs) ^ ")"
    | FWord (s, _) => s
    | FName (s, _) => s
    | FStr (s, _) => showLit (LStr s)
    | FChar (c, _) => showLit (LChar c)
    | FAt (f, _) => "@" ^ flat f
    | FBang (f, _) => "!" ^ flat f

  fun spaces n = CharVector.tabulate (n, fn _ => #" ")

  (* how many items of a list headed by a word stay on its first line *)
  fun inline head =
    case head of
      "\\" => 2 | "case" => 3 | "val" => 3 | "import" => 3 | "data" => 3 | "newtype" => 3 | "con" => 2 | "prim" => 2
    | "cast" => 2 | _ => 1

  (* the size of f on one line where it is at most `room`, else `room + 1`,
     found without making its text: a form is measured at each level of
     `layout`, so making its text there would cost its size times its
     depth (a long list of literals in a let chain) *)
  fun flatSize (f, room) =
    let
      exception Over
      val n = ref 0
      fun add k = (n := !n + k; if !n > room then raise Over else ())
      fun go f =
        case f of
          FList (fs, _) => (add 2; ignore (List.foldl (fn (x, first) => (if first then () else add 1; go x; false)) true fs))
        | FWord (s, _) => add (size s)
        | FName (s, _) => add (size s)
        | FStr (s, _) => add (size (showLit (LStr s)))
        | FChar (c, _) => add (size (showLit (LChar c)))
        | FAt (f, _) => (add 1; go f)
        | FBang (f, _) => (add 1; go f)
    in
      (go f; !n) handle Over => room + 1
    end

  fun fits (f, room) = flatSize (f, room) <= room

  (* f at column col, broken over lines where it does not fit, its pieces
     joined once *)
  fun layout (f, col) =
    let
      val out : string list ref = ref []
      fun emit s = out := s :: !out
      fun lines (xs, col) = List.app (fn x => (emit "\n"; emit (spaces col); go (x, col))) xs
      and go (f, col) =
        if fits (f, width - col) then emit (flat f)
        else
          case f of
            FList (FWord ("let", _) :: [binding, body], _) =>
              (emit "(let "; go (binding, col + 5); emit "\n"; emit (spaces col); go (body, col); emit ")")
          | FList (FWord ("letrec", _) :: [FList (bs, _), body], _) =>
              (emit "(letrec (";
               (case bs of
                  b :: more => (go (b, col + 9); lines (more, col + 9))
                | [] => ());
               emit ")\n"; emit (spaces col); go (body, col); emit ")")
          | FList (fs as FWord (h, _) :: _, _) =>
              let
                val k = Int.min (inline h, length fs)
                (* the items that stay, if they fit; the head alone if not *)
                val room = width - col - 1
                val firstSize =
                  List.foldl (fn (x, n) => if n > room then n else n + flatSize (x, room)) (k - 1) (List.take (fs, k))
                val k = if k > 1 andalso firstSize > room then 1 else k
              in
                emit "("; emit (String.concatWith " " (List.map flat (List.take (fs, k))));
                lines (List.drop (fs, k), col + 2); emit ")"
              end
          | FList (x :: rest, _) => (emit "("; go (x, col + 1); lines (rest, col + 2); emit ")")
          | FAt (g, _) => (emit "@"; go (g, col + 1))
          | FBang (g, _) => (emit "!"; go (g, col + 1))
          | _ => emit (flat f)
    in
      go (f, col); String.concat (List.rev (!out))
    end

  fun show program = String.concat (List.map (fn d => layout (declForm d, 0) ^ "\n") program)
  fun showTy t = flat (tyForm t)
  fun showKind k = flat (kindForm k)
  fun showExp e = layout (expForm e, 0)
end
