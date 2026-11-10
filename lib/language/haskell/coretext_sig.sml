(* Core as text, and back (the haskell98 roadmap, D2): the contract between
   the front end, which writes Core, and Core to Mid, which reads it. `show`
   prints a program for a dump (rhc --dump-after) or a test (tests/hs/core),
   and `parse` reads what it prints, so that print, read, print is the
   identity; rhc checks that at lint level 3.

   The text is of parenthesised forms. A comment runs from `;` to the end
   of its line.

       program := decl ...
       decl    := (data T (TYPARAM ...) (C TYPE ...) ...)
                | (newtype T (TYPARAM ...) C TYPE)
                | (val x TYPE EXP)
       typaram := a | (a KIND)                  a alone is of kind *
       kind    := * | # | (-> KIND KIND ...)    # is unlifted
       type    := T | a | (TYPE TYPE ...) | (-> TYPE TYPE ...)
                | (forall (TYPARAM ...) TYPE) | (utuple TYPE ...) | !TYPE
       exp     := ATOM | (EXP ARG ...) | (\ (BINDER ...) EXP)
                | (let (x TYPE EXP) EXP) | (letrec ((x TYPE EXP) ...) EXP)
                | (case EXP x ALT ...) | (con C @TYPE ... ATOM ...)
                | (prim P @TYPE ... ATOM ...) | (utuple ATOM ...) | (cast EXP TYPE)
       binder  := (x TYPE) | @a | @(a KIND)
       arg     := ATOM | @TYPE
       alt     := ((C x ...) EXP) | (LITERAL EXP) | ((utuple x ...) EXP) | (_ EXP)
       atom    := x | LITERAL
       literal := 42 | -42 | 42I | 2.5 | 2.5e-3 | 2.5F | 'c' | '\955' | "bytes"

   A word in a type is a variable where a `forall`, a type binder or the
   parameters of a declaration bind it, and a type constructor elsewhere.
   A literal ending in `I` is an `Integer`, one with a point or an exponent
   a `Double`, or a `Float` ending in `F`. A string's escapes are `\\`,
   `\"`, `\n`, `\t` and `\DDD`, a byte in three decimal digits; a
   character's are those, `\'` and `\D...`, a code point in decimal. A name
   that is a word of the syntax (`let`, `case`, `*`, `_`, ...), that starts
   as a literal, `@` or `!` would, or that holds a space, a parenthesis, a
   quotation mark, `;` or a backquote, is written between backquotes, with
   `\\` and a backslashed backquote inside.

   Area: Languages *)
signature CORE_TEXT =
sig
  (* A fault in the text: the line it is on, and what is wrong. *)
  exception Error of int * string

  (* `parse text` is the program `text` holds.

     Raises: `Error` where `text` is not a program. *)
  val parse : string -> Core.program
  (* `parseType text` is the type `text` holds, whose variables a `forall`
     binds.

     Raises: `Error` where `text` is not one type. *)
  val parseType : string -> Core.ty

  (* `show program` is the text of `program`, which `parse` reads back as
     `program`. *)
  val show : Core.program -> string
  (* `showTy t` is the text of the type `t`, on one line. *)
  val showTy : Core.ty -> string
  (* `showKind k` is the text of the kind `k`. *)
  val showKind : Core.kind -> string
  (* `showExp e` is the text of the expression `e`. *)
  val showExp : Core.exp -> string
  (* `showLit l` is the text of the literal `l`. *)
  val showLit : Core.lit -> string
  (* `showName x` is the name `x` as the text writes it, between backquotes
     where it must be. *)
  val showName : string -> string
end
