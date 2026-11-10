(* Literate Haskell (the Report's section 9.4): the program text of a
   literate file.

   The program text has the length of the file, byte for byte, so that a
   position of the one is a position of the other: a program line keeps
   its bytes but for its leading `>`, which becomes a space, so that its
   columns are the file's, and every byte of a line of commentary but its
   line end becomes a space. Layout sees no line of commentary, and the
   trivia that an exact print takes from the file keep it.

   Area: Languages *)
signature HS_LITERATE =
sig
  (* `isLiterate name` is whether `name` is that of a literate file: it
     ends in `.lhs`. *)
  val isLiterate : string -> bool

  (* `unlit (file, bytes)` is the program text of the literate file
     `file`, whose bytes are `bytes`. A line that begins with `>` is a
     program line, and so is every line between a line that begins with
     `\begin{code}` and one that begins with `\end{code}`; every other
     line is commentary.

     Raises: `HsSource.Error` for a program line next to a line of
     commentary that is not blank, for a `\begin{code}` that no
     `\end{code}` closes, and for an `\end{code}` that no `\begin{code}`
     opened. *)
  val unlit : string * string -> string
end
