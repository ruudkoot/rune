(* A source file as the documentation generator reads it: the tokens of the
   compiler's lexer, the comments in the gaps between them, and source text
   with the comments taken out. The lexer keeps no comments; they are found
   again here, which works because the tokens have increasing spans and
   everything between two tokens is white space and comments. *)
structure DocSource =
struct
  type t = {file : Source.file, toks : Lexer.item vector}

  (* A comment: from its "(*" to after the matching "*)". *)
  type comment = {start : int, stop : int}

  fun load (path : string) : t =
    let val file = Source.load path
    in {file = file, toks = Lexer.tokenize file} end

  fun text ({file, ...} : t) : string = #text file
  fun name ({file, ...} : t) : string = #name file
  fun numTokens ({toks, ...} : t) : int = Vector.length toks
  fun token ({toks, ...} : t, i : int) : Token.token = #1 (Vector.sub (toks, i))
  fun tokenStart ({toks, ...} : t, i : int) : int = #start (#2 (Vector.sub (toks, i)))
  fun tokenStop ({toks, ...} : t, i : int) : int = #stop (#2 (Vector.sub (toks, i)))

  fun substring (src : t, a : int, b : int) : string = String.substring (text src, a, b - a)

  (* 1-based line and 0-based column of a position. *)
  fun lineOf ({file, ...} : t, pos : int) : int = #1 (Source.lineCol (file, pos))
  fun columnOf ({file, ...} : t, pos : int) : int = #2 (Source.lineCol (file, pos)) - 1

  (* The index of the first token that starts at or after pos; the last token
     is the end of the file, which starts after everything. *)
  fun indexAt (src : t, pos : int) : int =
    let
      fun search (lo, hi) =
        if lo >= hi then lo
        else
          let val mid = (lo + hi) div 2
          in if tokenStart (src, mid) < pos then search (mid + 1, hi) else search (lo, mid) end
    in
      search (0, numTokens src - 1)
    end

  (* The comments of the gap text[a, b). Comments nest, and a string inside a
     comment means nothing, as in Lexer.skipComment. What is left of a gap is
     white space, or the lexer and this scanner disagree. *)
  fun commentsIn (src : t, a : int, b : int) : comment list =
    let
      val s = text src
      fun sub i = String.sub (s, i)
      fun close start =
        let
          val depth = ref 1
          fun go i =
            if i + 1 >= b then Error.bug ("docgen: comment not closed in a gap of " ^ name src)
            else if sub i = #"(" andalso sub (i + 1) = #"*" then (depth := !depth + 1; go (i + 2))
            else if sub i = #"*" andalso sub (i + 1) = #")" then
              (depth := !depth - 1; if !depth = 0 then i + 2 else go (i + 2))
            else go (i + 1)
        in
          go (start + 2)
        end
      fun scan (i, acc) =
        if i >= b then List.rev acc
        else if Char.isSpace (sub i) then scan (i + 1, acc)
        else if i + 1 < b andalso sub i = #"(" andalso sub (i + 1) = #"*" then
          let val stop = close i in scan (stop, {start = i, stop = stop} :: acc) end
        else
          Error.bug ("docgen: text between two tokens of " ^ name src ^ " that is neither white space nor a comment")
    in
      scan (a, [])
    end

  (* The comments between the token before index i and token i. *)
  fun commentsBefore (src : t, i : int) : comment list =
    commentsIn (src, if i = 0 then 0 else tokenStop (src, i - 1), tokenStart (src, i))

  fun isBlank (s : string) : bool = List.all Char.isSpace (String.explode s)

  fun trimRight (s : string) : string =
    let fun go j = if j > 0 andalso Char.isSpace (String.sub (s, j - 1)) then go (j - 1) else j
    in String.substring (s, 0, go (String.size s)) end

  (* A gap without its comments. A comment that has lines to itself goes with
     those lines; one that follows code on its line goes with the blanks before
     it; one between two tokens of a line leaves a blank, unless the second
     token touches it. *)
  fun gapWithoutComments (src : t, a : int, b : int) : string =
    case commentsIn (src, a, b) of
      [] => substring (src, a, b)
    | cs =>
      let
        val mark = #"\001"
        fun inComment k = List.exists (fn {start, stop} => start <= k andalso k < stop) cs
        val marked = CharVector.tabulate (b - a, fn k => if inComment (a + k) then mark else String.sub (text src, a + k))
        val lines = String.fields (fn c => c = #"\n") marked
        val n = List.length lines
        fun unmark l = String.implode (List.filter (fn c => c <> mark) (String.explode l))
        fun clean (k, l) =
          if not (CharVector.exists (fn c => c = mark) l) then SOME l
          else if n = 1 then SOME (if String.sub (l, String.size l - 1) = mark then "" else " ")
          else if k = 0 then SOME ""
          else if k = n - 1 then SOME (unmark l)
          else NONE
        fun go (_, []) = []
          | go (k, l :: rest) = (case clean (k, l) of SOME l' => l' :: go (k + 1, rest) | NONE => go (k + 1, rest))
      in
        String.concatWith "\n" (go (0, lines))
      end

  (* The source text of [a, b), which begins at a token and ends at one,
     without comments and without blanks at the ends of its lines. *)
  fun slice (src : t, a : int, b : int) : string =
    let
      val first = indexAt (src, a)
      fun go (i, acc) =
        if i >= numTokens src orelse tokenStart (src, i) >= b orelse tokenStart (src, i) = tokenStop (src, i) then List.rev acc
        else
          let
            val gap = if i = first then "" else gapWithoutComments (src, tokenStop (src, i - 1), tokenStart (src, i))
          in
            go (i + 1, substring (src, tokenStart (src, i), tokenStop (src, i)) :: gap :: acc)
          end
      val lines = String.fields (fn c => c = #"\n") (String.concat (go (first, [])))
    in
      String.concatWith "\n" (List.map trimRight lines)
    end

  fun sliceSpan (src : t, {start, stop, ...} : Source.span) : string = slice (src, start, stop)

  (* The same, with the lines after the first moved left by the indentation
     of the line it begins on, so that the text can stand at the margin. *)
  fun sliceAtMargin (src : t, sp as {start, ...} : Source.span) : string =
    let
      val s = text src
      val lineStart = start - columnOf (src, start)
      fun blanks k = if lineStart + k < start andalso String.sub (s, lineStart + k) = #" " then blanks (k + 1) else k
      val col = blanks 0
      fun dedent l =
        let
          fun go k = if k < col andalso k < String.size l andalso String.sub (l, k) = #" " then go (k + 1) else k
        in String.extract (l, go 0, NONE) end
    in
      case String.fields (fn c => c = #"\n") (sliceSpan (src, sp)) of
        [] => ""
      | l :: rest => String.concatWith "\n" (l :: List.map dedent rest)
    end

  (* Text on one line: every run of white space becomes a blank. *)
  fun oneLine (s : string) : string = String.concatWith " " (String.tokens Char.isSpace s)
end
