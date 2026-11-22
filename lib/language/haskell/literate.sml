(* Implements: HS_LITERATE *)
structure HsLiterate :> HS_LITERATE =
struct
  fun isLiterate name = String.isSuffix ".lhs" name

  (* what the line above was, for the rule of adjacency *)
  datatype prev = Blank | Program | Commentary

  fun unlit (file, src) =
    let
      val n = size src
      val out = CharArray.tabulate (n, fn i => String.sub (src, i))
      fun blankOut (a, b) =
        let fun go i = if i >= b then () else (CharArray.update (out, i, #" "); go (i + 1))
        in go a end
      fun lineEnd i = if i >= n orelse String.sub (src, i) = #"\n" then i else lineEnd (i + 1)
      fun isBlank (a, b) = a >= b orelse (Char.isSpace (String.sub (src, a)) andalso isBlank (a + 1, b))
      fun startsWith (a, b, s) =
        b - a >= size s andalso String.substring (src, a, size s) = s
      fun fail (a, b, msg) = raise HsSource.Error ({file = file, start = a, stop = b}, msg)
      (* The line [a, b) and those after it. `opened` is where the
         \begin{code} block the line is in began, if it is in one. *)
      fun go (a, opened : int option, prev) =
        let
          val b = lineEnd a
          val (opened, prev) =
            case opened of
              SOME _ =>
                if startsWith (a, b, "\\end{code}") then (blankOut (a, b); (NONE, Blank))
                else (opened, Blank)
            | NONE =>
                if startsWith (a, b, "\\begin{code}") then (blankOut (a, b); (SOME a, Blank))
                else if startsWith (a, b, "\\end{code}") then
                  fail (a, b, "literate source: an \\end{code} that no \\begin{code} opened")
                else if a < b andalso String.sub (src, a) = #">" then
                  (if prev = Commentary then
                     fail (a, b, "literate source: a program line next to a line of commentary")
                   else ();
                   CharArray.update (out, a, #" ");
                   (NONE, Program))
                else if isBlank (a, b) then (blankOut (a, b); (NONE, Blank))
                else
                  (if prev = Program then
                     fail (a, b, "literate source: a line of commentary next to a program line")
                   else ();
                   blankOut (a, b);
                   (NONE, Commentary))
        in
          if b >= n then opened else go (b + 1, opened, prev)
        end
    in
      case go (0, NONE, Blank) of
        SOME a => fail (a, lineEnd a, "literate source: a \\begin{code} that no \\end{code} closes")
      | NONE => CharArray.vector out
    end
end
