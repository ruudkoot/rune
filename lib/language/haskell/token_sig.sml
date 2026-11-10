(* The lexemes of Haskell 98 (the Report's chapter 2 and section 9.2), with
   what lies between them.

   Three tokens are the layout algorithm's (section 9.3) and never the
   lexer's: `VLBRACE`, `VSEMI` and `VRBRACE`, the braces and semicolon it
   puts in. They stay apart from the written ones, so that a trace shows
   what layout did. Comments, pragmas and white space are not tokens: each
   token keeps the trivia before it, so that a tree can be printed back as
   its file (the haskell98 roadmap's D28).

   Area: Languages *)
signature HS_TOKEN =
sig
  (* A lexeme. A qualified name is its qualifier and its name; a literal
     keeps its value and its text as written. *)
  datatype token =
      VARID of string                     (* `varid` *)
    | CONID of string                     (* `conid` *)
    | QVARID of string * string           (* `qvarid` with its qualifier *)
    | QCONID of string * string           (* `qconid` with its qualifier *)
    | VARSYM of string                    (* `varsym` *)
    | CONSYM of string                    (* `consym` *)
    | QVARSYM of string * string          (* `qvarsym` with its qualifier *)
    | QCONSYM of string * string          (* `qconsym` with its qualifier *)
    | INTEGER of IntInf.int * string      (* `integer`: its value, its text *)
    | FLOAT of string                     (* `float`: its text *)
    | CHAR of int * string                (* `char`: its code point, its text *)
    | STRING of int list * string         (* `string`: its code points, its text *)
    | LPAREN | RPAREN | COMMA | SEMI | LBRACKET | RBRACKET | BACKQUOTE | LBRACE
    | RBRACE                              (* `special` *)
    | DOTDOT | COLON | DCOLON | EQUALS | BACKSLASH | BAR | LARROW | RARROW | AT | TILDE
    | DARROW                              (* `reservedop` *)
    | CASE | CLASS | DATA | DEFAULT | DERIVING | DO | ELSE | IF | IMPORT | IN | INFIX
    | INFIXL | INFIXR | INSTANCE | LET | MODULE | NEWTYPE | OF | THEN | TYPE | WHERE
    | UNDERSCORE                          (* `reservedid` *)
    | VLBRACE                             (* layout's `{` *)
    | VSEMI                               (* layout's `;` *)
    | VRBRACE                             (* layout's `}` *)
    | EOF                                 (* the end of the input *)

  (* What a stretch of trivia is. *)
  datatype trivia =
      Whitespace     (* white space; in a literate file, its commentary too *)
    | LineComment    (* `--` to the end of the line *)
    | BlockComment   (* `{-` to its `-}` *)
    | Pragma         (* `{-#` to its `#-}`, which the Report's chapter 11 reads as a comment *)
    | ByteOrderMark  (* the bytes EF BB BF at the head of the file *)

  (* A stretch of trivia, by the bytes of the file it covers. *)
  type trivium = {kind : trivia, start : int, stop : int}

  (* A token as the lexer reads it: the bytes it covers, the line it is
     on, its column as layout counts it (a tab to the next multiple of
     eight, plus one), whether it is the first token of its line, and the
     trivia before it. *)
  type item = {token : token, start : int, stop : int, line : int, column : int, first : bool,
               trivia : trivium list}

  (* `reservedId s` is the keyword `s` is, if it is one; `_` among them. *)
  val reservedId : string -> token option

  (* `reservedOp s` is the reserved operator `s` is, if it is one. *)
  val reservedOp : string -> token option

  (* `show t` is the text `t` stands for, `{v`, `v;` and `v}` for layout's
     tokens and `<eof>` for the end. *)
  val show : token -> string

  (* `describe t` names `t` in a diagnostic: its text in backquotes, and
     layout's tokens and the end by what they are. *)
  val describe : token -> string

  (* `plain t` is the written token that layout's `t` stands for, and `t`
     when it is not layout's. *)
  val plain : token -> token
end
