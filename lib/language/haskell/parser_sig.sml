(* The parser of Haskell 98: recursive descent over the grammar of the
   Report's section 9.5, on the layout of `HsLayout` (the haskell98
   roadmap's D27).

   A block's item parser returns as soon as the next token cannot go on
   with the item, so a block that then sees neither `;` nor its close is
   at `parse-error(t)`, and takes the implicit close there; nothing else
   here knows of layout. Operators stay in flat sequences, so no fixity is
   needed (R1: `do a == b == c` parses, and fixity resolution refuses it).
   A declaration's left-hand side and a statement's pattern are read as
   relaxed patterns and checked once the token after them says what they
   are.

   Area: Languages *)
signature HS_PARSER =
sig
  (* How much of the source a tree keeps.

     `Bare`, none, so that two trees compare equal where they differ only
     in where they were read; `Spans`, a span on every node; `Full`, spans
     and every node's own tokens with their trivia, which `HsPrint.exact`
     needs. *)
  datatype annotations = Bare | Spans | Full

  (* How to read: the lexer's options, and the annotations. *)
  type options = {lexer : HsLexer.options, annotations : annotations}

  (* Haskell 98's lexer, and `Full` annotations. *)
  val defaults : options

  (* `parse (options, file, tokens)` is the module the tokens of the file
     `file` hold.

     Raises: `HsSource.Error` at the first syntax error. *)
  val parse : options * string * HsToken.item vector -> HsAst.module

  (* `parseTraced (options, file, tokens)` is `parse`'s module, and every
     token the parser passed, in order.

     The braces and semicolons of layout are as layout gave them: the
     function `L` of section 9.3, on the source.

     Raises: `HsSource.Error` at the first syntax error. *)
  val parseTraced : options * string * HsToken.item vector -> HsAst.module * HsToken.token list

  (* `parseFile (options, file, bytes)` is the module that the file
     `file`, whose bytes are `bytes`, holds.

     It is unlit first where its name is a literate file's (`HsLiterate`),
     then lexed and parsed.

     Raises: `HsSource.Error` at the first error. *)
  val parseFile : options * string * string -> HsAst.module
end
