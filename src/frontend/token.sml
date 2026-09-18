(* Lexical tokens of Standard ML '97 (plus the `_prim` extension). *)
structure Token =
struct
  datatype token =
    (* identifiers and literals *)
    ID of string                          (* alphanumeric or symbolic identifier *)
  | LONGID of string list * string        (* A.B.x *)
  | TYVAR of string                       (* 'a, ''a (name includes quotes) *)
  | INT of IntInf.int
  | WORD of IntInf.int
  | REAL of string                        (* literal text, SML syntax *)
  | STRING of string
  | CHAR of char
    (* reserved words *)
  | ABSTYPE | AND | ANDALSO | AS | CASE | DATATYPE | DO | ELSE | END | EXCEPTION
  | FN | FUN | HANDLE | IF | IN | INFIX | INFIXR | LET | LOCAL | NONFIX | OF | OP
  | OPEN | ORELSE | RAISE | REC | THEN | TYPE | VAL | WITH | WITHTYPE | WHILE
  | EQTYPE | FUNCTOR | INCLUDE | SHARING | SIG | SIGNATURE | STRUCT | STRUCTURE | WHERE
    (* reserved symbols *)
  | LPAREN | RPAREN | LBRACKET | RBRACKET | LBRACE | RBRACE | COMMA | COLON | COLONGT
  | SEMI | DOTS | UNDERSCORE | BAR | EQUALS | DARROW | ARROW | HASH
    (* extension *)
  | PRIM                                  (* _prim *)
  | OVERLOAD                              (* _overload *)
  | EOF

  fun toString t =
    case t of
      ID s => s
    | LONGID (path, s) => String.concatWith "." (path @ [s])
    | TYVAR s => s
    | INT i => IntInf.toString i
    | WORD w => "0w" ^ IntInf.toString w
    | REAL s => s
    | STRING s => "\"" ^ String.toString s ^ "\""
    | CHAR c => "#\"" ^ Char.toString c ^ "\""
    | ABSTYPE => "abstype" | AND => "and" | ANDALSO => "andalso" | AS => "as"
    | CASE => "case" | DATATYPE => "datatype" | DO => "do" | ELSE => "else"
    | END => "end" | EXCEPTION => "exception" | FN => "fn" | FUN => "fun"
    | HANDLE => "handle" | IF => "if" | IN => "in" | INFIX => "infix"
    | INFIXR => "infixr" | LET => "let" | LOCAL => "local" | NONFIX => "nonfix"
    | OF => "of" | OP => "op" | OPEN => "open" | ORELSE => "orelse"
    | RAISE => "raise" | REC => "rec" | THEN => "then" | TYPE => "type"
    | VAL => "val" | WITH => "with" | WITHTYPE => "withtype" | WHILE => "while"
    | EQTYPE => "eqtype" | FUNCTOR => "functor" | INCLUDE => "include"
    | SHARING => "sharing" | SIG => "sig" | SIGNATURE => "signature"
    | STRUCT => "struct" | STRUCTURE => "structure" | WHERE => "where"
    | LPAREN => "(" | RPAREN => ")" | LBRACKET => "[" | RBRACKET => "]"
    | LBRACE => "{" | RBRACE => "}" | COMMA => "," | COLON => ":" | COLONGT => ":>"
    | SEMI => ";" | DOTS => "..." | UNDERSCORE => "_" | BAR => "|" | EQUALS => "="
    | DARROW => "=>" | ARROW => "->" | HASH => "#"
    | PRIM => "_prim"
    | OVERLOAD => "_overload"
    | EOF => "<eof>"

  val reserved : (string * token) list =
    [("abstype", ABSTYPE), ("and", AND), ("andalso", ANDALSO), ("as", AS),
     ("case", CASE), ("datatype", DATATYPE), ("do", DO), ("else", ELSE),
     ("end", END), ("exception", EXCEPTION), ("fn", FN), ("fun", FUN),
     ("handle", HANDLE), ("if", IF), ("in", IN), ("infix", INFIX),
     ("infixr", INFIXR), ("let", LET), ("local", LOCAL), ("nonfix", NONFIX),
     ("of", OF), ("op", OP), ("open", OPEN), ("orelse", ORELSE),
     ("raise", RAISE), ("rec", REC), ("then", THEN), ("type", TYPE),
     ("val", VAL), ("with", WITH), ("withtype", WITHTYPE), ("while", WHILE),
     ("eqtype", EQTYPE), ("functor", FUNCTOR), ("include", INCLUDE),
     ("sharing", SHARING), ("sig", SIG), ("signature", SIGNATURE),
     ("struct", STRUCT), ("structure", STRUCTURE), ("where", WHERE)]

  val reservedSymbolic : (string * token) list =
    [(":", COLON), (":>", COLONGT), ("|", BAR), ("=", EQUALS), ("=>", DARROW),
     ("->", ARROW), ("#", HASH)]
end
