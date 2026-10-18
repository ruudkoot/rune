(* When an entry of the REPL is complete (docs/plans/repl.md, D12): a `;`
   outside brackets, `let`, `local`, `struct`, `sig` and `abstype` ... `end`,
   strings and comments ends one. A scanner follows that nesting a character
   at a time, so that what has been typed is looked at once however long it
   grows: the editor asks it at Enter, the basic mode at each line, and
   Compiler.compile at each `;`, and the parser is run only where it says an
   entry may have ended, which the parser then confirms.

   A string that a line ends inside, outside a gap (`\ ... \`), cannot be
   finished: the entry is complete then too, so that the parser reports it
   at once instead of the REPL waiting for more. Where the count is wrong --
   a stray `end` or `)` -- the depth stays at or below 0, and the parser
   decides. *)
structure ReplScan =
struct
  type t = {depth : int ref, comment : int ref, inString : bool ref, escaped : bool ref, gap : bool ref,
            prev : char ref, word : char list ref, ended : bool ref, broken : bool ref}

  fun new () : t =
    {depth = ref 0, comment = ref 0, inString = ref false, escaped = ref false, gap = ref false,
     prev = ref #" ", word = ref [], ended = ref false, broken = ref false}

  fun endWord ({depth, word, ...} : t) =
    (case String.implode (List.rev (!word)) of
       "let" => depth := !depth + 1
     | "local" => depth := !depth + 1
     | "struct" => depth := !depth + 1
     | "sig" => depth := !depth + 1
     | "abstype" => depth := !depth + 1
     | "end" => depth := !depth - 1
     | _ => ();
     word := [])

  val isWordChar = Ident.isNameByte

  (* char (s, c): c is the next character typed *)
  fun char (s as {depth, comment, inString, escaped, gap, prev, word, ended, broken} : t, c : char) : unit =
    if !comment > 0 then
      if !prev = #"(" andalso c = #"*" then (comment := !comment + 1; prev := #" ")
      else if !prev = #"*" andalso c = #")" then (comment := !comment - 1; prev := #" ")
      else prev := c
    else if !inString then
      if !gap then (if c = #"\\" then gap := false else ())
      else if !escaped then (escaped := false; if Char.isSpace c then gap := true else ())
      else if c = #"\\" then escaped := true
      else if c = #"\"" then inString := false
      else if c = #"\n" then (inString := false; broken := true; ended := true)
      else ()
    else if isWordChar c then (word := c :: !word; ended := false)
    else
      (if null (!word) then () else endWord s;
       if Char.isSpace c then ()
       else if c = #"*" andalso !prev = #"(" then
         (* the `(` counted was a comment's; `;` before it may still end the entry *)
         (depth := !depth - 1; comment := 1; ended := !broken)
       else
         (ended := ((c = #";" andalso !depth <= 0) orelse !broken);
          case c of
            #"(" => depth := !depth + 1
          | #"[" => depth := !depth + 1
          | #"{" => depth := !depth + 1
          | #")" => depth := !depth - 1
          | #"]" => depth := !depth - 1
          | #"}" => depth := !depth - 1
          | #"\"" => inString := true
          | _ => ());
       prev := c)

  fun string (s : t, text : string) : unit = CharVector.app (fn c => char (s, c)) text

  (* whether what has been read may be a whole entry: it ends with a `;` at
     the top, comments after it aside, or a line ended inside a string *)
  fun complete ({ended, comment, inString, broken, ...} : t) : bool =
    !broken orelse (!ended andalso !comment = 0 andalso not (!inString))

  (* how deep the text is nested at its end: brackets and blocks, and a
     comment or a string counted as one more *)
  fun depth ({depth, comment, inString, ...} : t) : int =
    Int.max (0, !depth) + (if !comment > 0 orelse !inString then 1 else 0)

  fun ofText (text : string) : t = let val s = new () in string (s, text); s end
end
