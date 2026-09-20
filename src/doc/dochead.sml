(* Usage heads (docs/plans/docgen.md, D3): the description of a value may
   begin with the value applied to arguments, as in `take (l, i)` or `l @ m`.
   The code is parsed with the compiler's parser, under the fixity of the top
   level, and checked against the type of the specification; the names of its
   arguments are the names the rest of the comment uses for them. *)
structure DocHead =
struct
  (* arity: how many arguments the value is applied to, one after another *)
  type head = {code : string, name : string, args : string list, arity : int}

  (* A usage may name the fields of a record argument as a pattern does,
     `make {size, fill}`, which is no expression: a label that stands alone
     between braces is given itself as its value before the code is parsed. *)
  fun expandFields (code : string) : string =
    let
      val toks = Lexer.tokenize (Source.fromString ("<usage>", code))
      val n = Vector.length toks
      fun tok i = #1 (Vector.sub (toks, i))
      fun go (i, acc) =
        if i >= n - 1 then String.concatWith " " (List.rev acc)
        else
          let
            val t = tok i
            val alone =
              (case t of Token.ID _ => true | _ => false)
              andalso i > 0 andalso (tok (i - 1) = Token.LBRACE orelse tok (i - 1) = Token.COMMA)
              andalso (tok (i + 1) = Token.RBRACE orelse tok (i + 1) = Token.COMMA)
              andalso inBraces (i - 1, 0)
            val s = Token.toString t
          in
            go (i + 1, (if alone then s ^ " = " ^ s else s) :: acc)
          end
      (* the bracket that encloses token i + 1 is a brace *)
      and inBraces (i, depth) =
        if i < 0 then false
        else
          case tok i of
            Token.RBRACE => inBraces (i - 1, depth + 1)
          | Token.RPAREN => inBraces (i - 1, depth + 1)
          | Token.RBRACKET => inBraces (i - 1, depth + 1)
          | Token.LBRACE => if depth = 0 then true else inBraces (i - 1, depth - 1)
          | Token.LPAREN => if depth = 0 then false else inBraces (i - 1, depth - 1)
          | Token.LBRACKET => if depth = 0 then false else inBraces (i - 1, depth - 1)
          | _ => inBraces (i - 1, depth)
    in
      go (0, [])
    end

  (* code as an expression, if it is one *)
  fun parseExp (code : string) : Ast.exp option =
    (case Parser.parseTokensWith (Lexer.tokenize (Source.fromString ("<usage>", "val it = " ^ expandFields code)),
                                  Fixity.initial) of
       ([Ast.DVal (_, [(_, e)], _)], _) => SOME e
     | _ => NONE)
    handle Error.CompileError _ => NONE

  (* f a1 ... an as (f, [a1, ..., an]), for an unqualified f *)
  fun unfold (e : Ast.exp, args : Ast.exp list) : (string * Ast.exp list) option =
    case e of
      Ast.EApp (f, a, _) => unfold (f, a :: args)
    | Ast.EVar (([], name), _, _) => SOME (name, args)
    | _ => NONE

  (* The variables of the arguments: what is not applied and does not look
     like a constructor. *)
  fun variables (e : Ast.exp) : string list =
    case e of
      Ast.EVar (([], x), _, _) =>
        if Char.isLower (String.sub (x, 0)) andalso x <> "true" andalso x <> "false" andalso x <> "nil" then [x] else []
    | Ast.ETuple (es, _) => List.concat (List.map variables es)
    | Ast.EList (es, _) => List.concat (List.map variables es)
    | Ast.ESeq (es, _) => List.concat (List.map variables es)
    | Ast.ERecord (fields, _) => List.concat (List.map (fn (_, e) => variables e) fields)
    | Ast.ETyped (e', _, _) => variables e'
    | Ast.EApp (_, a, _) => variables a
    | _ => []

  fun distinct (xs : string list) : string list =
    List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else acc @ [x]) [] xs

  (* The heads among pieces of code: those that apply an unqualified
     identifier to at least one argument. *)
  fun headsOf (codes : string list) : (head * Ast.exp list) list =
    List.mapPartial (fn code =>
                       case Option.mapPartial (fn e => unfold (e, [])) (parseExp code) of
                         SOME (name, args as _ :: _) =>
                           SOME ({code = code, name = name, args = distinct (List.concat (List.map variables args)),
                                  arity = List.length args}, args)
                       | _ => NONE) codes

  (* What is wrong with these arguments for a value of this type. An argument
     beyond the arrows that the type shows is allowed where the result is a
     type constructor, which may abbreviate a function type (`scan getc strm`
     against a StringCvt.reader); elaboration will tell (M8). *)
  fun mismatch (ty : Ast.ty, args : Ast.exp list) : string option =
    case (args, ty) of
      ([], _) => NONE
    | (a :: rest, Ast.TyArrow (dom, cod, _)) =>
        (case argMismatch (dom, a) of SOME why => SOME why | NONE => mismatch (cod, rest))
    | (_, Ast.TyCon _) => NONE
    | _ => SOME "it has more arguments than the type has arrows"

  and argMismatch (dom : Ast.ty, a : Ast.exp) : string option =
    case (a, dom) of
      (Ast.ETuple (es as _ :: _ :: _, _), Ast.TyTuple (tys, _)) =>
        if List.length es = List.length tys then NONE
        else SOME ("it has a tuple of " ^ Int.toString (List.length es) ^ " where the type has one of " ^
                   Int.toString (List.length tys))
    | (Ast.ETuple (_ :: _ :: _, _), Ast.TyCon _) => NONE
    | (Ast.ETuple (_ :: _ :: _, _), Ast.TyVar _) => NONE
    | (Ast.ETuple (_ :: _ :: _, _), _) => SOME "it has a tuple where the type has none"
    | (Ast.ERecord (fields, _), Ast.TyRecord (tys, _)) =>
        let
          val want = List.map #1 tys
          val have = List.map #1 fields
          fun subset (xs, ys) = List.all (fn x => List.exists (fn y => y = x) ys) xs
        in
          if subset (want, have) andalso subset (have, want) then NONE
          else SOME ("its record has the labels " ^ String.concatWith ", " have ^ " where the type has " ^
                     String.concatWith ", " want)
        end
    | (Ast.ERecord _, Ast.TyCon _) => NONE
    | (Ast.ERecord _, Ast.TyVar _) => NONE
    | (Ast.ERecord _, _) => SOME "it has a record where the type has none"
    | _ => NONE
end
