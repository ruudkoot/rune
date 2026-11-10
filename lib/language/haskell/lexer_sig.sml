(* The lexer of Haskell 98: the Report's chapter 2 and section 9.2, over
   program text.

   The whole of a file becomes a vector of tokens before anything is
   parsed, and nothing here depends on layout or on the parser, so that
   this much of the language is a function of the text. Each token keeps
   the trivia before it, and the end of the input keeps the trivia after
   the last token, so that every byte of the text is in exactly one
   token or one stretch of trivia.

   The readings it makes, of `results/E9/readings.md` in the haskell98
   roadmap's evidence:

   - R4: the end of the file ends a line comment.
   - R5: any character at all in a comment or a literal; identifiers and
     operators by the Report's classes (`HsChar`).
   - R6: ASCII digits only in a numeric literal.
   - R7: `F..` is the operator `.` qualified by `F`; `F.=` is `F` then
     `.=`; `M.where` is `M`, `.` and `where`.
   - R8: `--:` is an operator; a numeric escape above 0x10FFFF is an
     error.
   - A byte that is not part of a sequence of UTF-8 is read as the code
     point of its value, as Latin-1 would (the Report is silent on the
     bytes of a file).
   - A byte order mark at the head of the file is trivia.

   Area: Languages *)
signature HS_LEXER =
sig
  (* How to read: `hierarchical` reads a dotted module name such as
     `Data.List` as one qualifier, which Haskell 98's `modid` is not (the
     roadmap's D35, refused by default). *)
  type options = {hierarchical : bool}

  (* Haskell 98's: no dotted module names. *)
  val defaults : options

  (* `tokens (options, file, text)` is the tokens of the program text
     `text` of the file `file`, the last of them `EOF`.

     Raises: `HsSource.Error` for a lexical error: a character outside
     the Report's classes, a literal or a nested comment left open, an
     escape that is none. *)
  val tokens : options * string * string -> HsToken.item vector
end
