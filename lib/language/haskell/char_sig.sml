(* The classes of characters of the Haskell 98 Report's lexical syntax
   (chapter 2, section 9.2), by code point.

   Above ASCII the Report's classes are those of Unicode's general
   category: `uniSmall` a lowercase letter, `uniLarge` an uppercase or
   titlecase one, `uniDigit` a decimal digit, `uniSymbol` a symbol or a
   punctuation mark, `uniWhite` a space. Rune's `lib/unicode` does not
   give the general category yet (the haskell98 roadmap's D21), so above
   ASCII every character is of class `Unknown` until it does, and the
   lexer refuses one outside a comment or a literal; it reads any
   character in a comment or a literal (the reading R5).

   Area: Languages *)
signature HS_CHAR =
sig
  (* A class of the lexical syntax. *)
  datatype class =
      Small    (* `small`: `a` to `z`, `_` and a lowercase letter *)
    | Large    (* `large`: `A` to `Z` and an uppercase or titlecase letter *)
    | Digit    (* `digit`: `0` to `9` and a decimal digit *)
    | Symbol   (* `symbol`: `ascSymbol` and a symbol or punctuation that is not `special`, `_`, `:`, a quotation mark *)
    | White    (* `whitechar`: space, tab, the line ends, vertical tab and a space above ASCII *)
    | Special  (* `special`: one of `(),;[]` and the backquote and braces *)
    | Colon    (* `:`, which begins a constructor operator *)
    | Quote    (* the two quotation marks, `"` and `'` *)
    | Unknown  (* no class: a control character, or a character above ASCII until `lib/unicode` classifies it *)

  (* `classify c` is the class of the code point `c`; `Unknown` for a
     negative `c`. *)
  val classify : int -> class

  (* `isIdent c` is whether `c` may continue an identifier: a small or a
     large letter, a digit or `'`. *)
  val isIdent : int -> bool

  (* `isSymbol c` is whether `c` may continue an operator: a symbol or `:`. *)
  val isSymbol : int -> bool
end
