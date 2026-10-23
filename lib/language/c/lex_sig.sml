(* C preprocessing tokens with original physical source positions.

   Area: Languages *)
signature C_LEX =
sig
  (* The original file, one-based physical line and byte column. *)
  type location = {file : string, line : int, column : int}
  (* Preprocessing-token categories; newline tokens delimit directives. *)
  datatype kind = Identifier | Number | StringLiteral | CharacterLiteral | Punctuation | Newline
  (* A token's spelling, preceding whitespace, source position and macro
     invocation origins. Expansion keeps the original definition location. *)
  type token = {kind : kind, text : string, space : bool,
                location : location, origins : location list}
  (* A lexical error and its physical source location. *)
  exception Error of location * string
  (* `scan {file, text}` applies trigraphs, line splicing, comment replacement and
     maximal preprocessing-token recognition. It retains physical positions.

     Raises: `Error` for unterminated literals/comments or invalid bytes. *)
  val scan : {file : string, text : string} -> token list
  (* `spelling tokens` writes tokens with separating spaces and explicit
     newlines. Retokenizing it preserves token boundaries. *)
  val spelling : token list -> string
  (* `diagnostic (token, message)` locates the outer invocation and adds
     the definition and expansion trace to the message. *)
  val diagnostic : token * string -> location * string
end
