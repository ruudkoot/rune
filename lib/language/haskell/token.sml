(* Implements: HS_TOKEN *)
structure HsToken :> HS_TOKEN =
struct
  datatype token =
      VARID of string | CONID of string
    | QVARID of string * string | QCONID of string * string
    | VARSYM of string | CONSYM of string
    | QVARSYM of string * string | QCONSYM of string * string
    | INTEGER of IntInf.int * string | FLOAT of string
    | CHAR of int * string | STRING of int list * string
    | LPAREN | RPAREN | COMMA | SEMI | LBRACKET | RBRACKET | BACKQUOTE | LBRACE | RBRACE
    | DOTDOT | COLON | DCOLON | EQUALS | BACKSLASH | BAR | LARROW | RARROW | AT | TILDE | DARROW
    | CASE | CLASS | DATA | DEFAULT | DERIVING | DO | ELSE | IF | IMPORT | IN | INFIX
    | INFIXL | INFIXR | INSTANCE | LET | MODULE | NEWTYPE | OF | THEN | TYPE | WHERE | UNDERSCORE
    | VLBRACE | VSEMI | VRBRACE
    | EOF

  datatype trivia = Whitespace | LineComment | BlockComment | Pragma | ByteOrderMark

  type trivium = {kind : trivia, start : int, stop : int}

  type item = {token : token, start : int, stop : int, line : int, column : int, first : bool,
               trivia : trivium list}

  fun reservedId s =
    if size s < 2 then (if s = "_" then SOME UNDERSCORE else NONE)
    else
      case String.sub (s, 0) of
        #"c" => (case s of "case" => SOME CASE | "class" => SOME CLASS | _ => NONE)
      | #"d" =>
          (case s of
             "data" => SOME DATA | "default" => SOME DEFAULT | "deriving" => SOME DERIVING | "do" => SOME DO
           | _ => NONE)
      | #"e" => if s = "else" then SOME ELSE else NONE
      | #"i" =>
          (case s of
             "if" => SOME IF | "import" => SOME IMPORT | "in" => SOME IN | "infix" => SOME INFIX
           | "infixl" => SOME INFIXL | "infixr" => SOME INFIXR | "instance" => SOME INSTANCE
           | _ => NONE)
      | #"l" => if s = "let" then SOME LET else NONE
      | #"m" => if s = "module" then SOME MODULE else NONE
      | #"n" => if s = "newtype" then SOME NEWTYPE else NONE
      | #"o" => if s = "of" then SOME OF else NONE
      | #"t" => (case s of "then" => SOME THEN | "type" => SOME TYPE | _ => NONE)
      | #"w" => if s = "where" then SOME WHERE else NONE
      | _ => NONE

  fun reservedOp s =
    case s of
      ".." => SOME DOTDOT | ":" => SOME COLON | "::" => SOME DCOLON
    | "=" => SOME EQUALS | "\\" => SOME BACKSLASH | "|" => SOME BAR
    | "<-" => SOME LARROW | "->" => SOME RARROW | "@" => SOME AT
    | "~" => SOME TILDE | "=>" => SOME DARROW
    | _ => NONE

  fun qual (m, s) = m ^ "." ^ s

  fun show t =
    case t of
      VARID s => s | CONID s => s
    | QVARID q => qual q | QCONID q => qual q
    | VARSYM s => s | CONSYM s => s
    | QVARSYM q => qual q | QCONSYM q => qual q
    | INTEGER (_, s) => s | FLOAT s => s
    | CHAR (_, s) => s | STRING (_, s) => s
    | LPAREN => "(" | RPAREN => ")" | COMMA => "," | SEMI => ";"
    | LBRACKET => "[" | RBRACKET => "]" | BACKQUOTE => "`"
    | LBRACE => "{" | RBRACE => "}"
    | DOTDOT => ".." | COLON => ":" | DCOLON => "::" | EQUALS => "="
    | BACKSLASH => "\\" | BAR => "|" | LARROW => "<-" | RARROW => "->"
    | AT => "@" | TILDE => "~" | DARROW => "=>"
    | CASE => "case" | CLASS => "class" | DATA => "data"
    | DEFAULT => "default" | DERIVING => "deriving" | DO => "do"
    | ELSE => "else" | IF => "if" | IMPORT => "import" | IN => "in"
    | INFIX => "infix" | INFIXL => "infixl" | INFIXR => "infixr"
    | INSTANCE => "instance" | LET => "let" | MODULE => "module"
    | NEWTYPE => "newtype" | OF => "of" | THEN => "then" | TYPE => "type"
    | WHERE => "where" | UNDERSCORE => "_"
    | VLBRACE => "{v" | VSEMI => "v;" | VRBRACE => "v}"
    | EOF => "<eof>"

  (* a long literal is cut, so that a message stays a line *)
  fun cut s = if size s > 40 then String.substring (s, 0, 37) ^ "..." else s

  fun describe t =
    case t of
      VLBRACE => "the start of a layout block"
    | VSEMI => "a new line at the indentation of its layout block"
    | VRBRACE => "the end of a layout block"
    | EOF => "the end of the input"
    | STRING (_, s) => "the string " ^ cut s
    | INTEGER (_, s) => "the number " ^ cut s
    | FLOAT s => "the number " ^ cut s
    | CHAR (_, s) => "the character " ^ s
    | _ => "`" ^ show t ^ "`"

  fun plain t =
    case t of
      VLBRACE => LBRACE
    | VSEMI => SEMI
    | VRBRACE => RBRACE
    | _ => t
end
