(* The header of a module of Haskell (the haskell2010 roadmap's D6): the
   pragmas, comments and white space before its first token, which 12.3
   calls the file-header pragmas' place ("A file-header pragma must precede
   the module keyword in a source file"). It is read before the lexer, whose
   options a module's language sets, from the program text, a literate
   file's once unlit; its words keep their offsets in that text, which a
   literate file's unlit text keeps too, so that a diagnostic of a name is
   said where the name is written.

   A pragma's keyword is read in any case, as GHC reads it; the names it
   writes are case-sensitive, separated by commas. A pragma after the first
   token is not the header's.

   Area: Languages *)
signature HS_HEADER =
sig
  (* A name a pragma writes, and its offset in the text. *)
  type name = {name : string, at : int}

  (* `languages text` is the names the LANGUAGE pragmas of the header of
     the program text `text` write, in the order of the text. *)
  val languages : string -> name list
end
