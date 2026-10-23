(* Diagnostics shown (docs/plans/repl.md, D17; docs/diagnostics.md). The
   first line of a diagnostic is the one the compiler has always printed,
   `file:line:col: error: msg`, byte for byte when its stream gets no
   colour; on a terminal, or with --diagnostics=full, the lines of source it
   is about follow, under a gutter of line numbers, with carets under the
   span placed by display width. A program that wants this installs it
   (install), which points Error.show here; --diagnostics-json writes every
   diagnostic of the run to a file as well, in the form rune-ide reads. *)
structure Diagnostic =
struct
  datatype mode = Short | Full

  (* what the program decided for its standard error *)
  val theme : Color.theme option ref = ref NONE
  val () = CompilerState.cellRoot ("Diagnostic.theme", theme)
  val mode = ref Short
  val () = CompilerState.cellRoot ("Diagnostic.mode", mode)
  val jsonFile : string option ref = ref NONE
  val () = CompilerState.cellRoot ("Diagnostic.jsonFile", jsonFile)
  val collected : (string * Source.span * string) list ref = ref []
  val () = CompilerState.cellRoot ("Diagnostic.collected", collected)

  fun paint role s = case !theme of NONE => s | SOME t => Color.paintIn t role s

  fun firstLine (level, sp, msg) =
    paint "diag.location" (Source.describe sp ^ ":") ^ " " ^ paint level (level ^ ":") ^ " " ^ paint "diag.message" msg

  fun hex c = Int.fmt StringCvt.HEX c

  (* the bidirectional controls, which could make a line read otherwise than
     it is (rustc's defence against "Trojan Source") *)
  fun bidi c = c = 0x61C orelse c = 0x200E orelse c = 0x200F orelse (c >= 0x202A andalso c <= 0x202E)
               orelse (c >= 0x2066 andalso c <= 0x2069)

  (* bytes a to b of text as cells: what is shown and how many columns. A
     grapheme cluster is one cell, as wide as a terminal draws it (an emoji
     of several code points two columns, not the sum of theirs); a byte
     that is not UTF-8, a control and a bidirectional control are escaped *)
  fun cells (text, a, b) =
    let
      fun plain (i, j) =
        let
          fun ok k = k >= j orelse
                     (case Utf8.decode (text, k) of
                        SOME (c, n) => c <> 9 andalso not (DisplayWidth.isControl c) andalso not (bidi c) andalso ok (k + n)
                      | NONE => false)
        in
          ok i
        end
      fun go (i, acc) =
        if i >= b then rev acc
        else
          case Utf8.decode (text, i) of
            NONE =>
              let val e = "\\x" ^ StringCvt.padLeft #"0" 2 (hex (Char.ord (String.sub (text, i))))
              in go (i + 1, (e, size e) :: acc) end
          | SOME (c, k) =>
              if c = 9 then go (i + k, ("\t", 1) :: acc)
              else if DisplayWidth.isControl c orelse bidi c then
                let val e = "\\u{" ^ hex c ^ "}" in go (i + k, (e, size e) :: acc) end
              else
                let val j = Int.min (b, Int.max (i + k, Grapheme.next (text, i)))
                in
                  if plain (i, j) then
                    let val cl = String.substring (text, i, j - i)
                    in go (j, (cl, Grapheme.width Grapheme.ByCluster cl) :: acc) end
                  else go (i + k, (String.substring (text, i, k), DisplayWidth.codePoint c) :: acc)
                end
    in
      go (a, [])
    end

  fun shown (cs : (string * int) list) = String.concat (map #1 cs)
  fun width (cs : (string * int) list) = foldl (fn ((_, w), n) => n + w) 0 cs
  (* what stands under cells that come before a marker: a tab under a tab,
     so that the marker lines up whatever a tab is *)
  fun under cs = String.concat (map (fn ("\t", _) => "\t" | (_, w) => CharVector.tabulate (w, fn _ => #" ")) cs)

  fun repeat (c, n) = CharVector.tabulate (Int.max (n, 1), fn _ => c)

  (* the lines of a span, under a gutter, or NONE when its source's text is
     gone (a file `use`d in the REPL keeps only its lines) *)
  fun excerpt (level, {file, start, stop} : Source.span) =
    case Source.findFile file of
      NONE => NONE
    | SOME (f as {text, lineStarts, line = first, ...}) =>
        if text = "" orelse start > size text then NONE
        else
          let
            val stop = Int.min (Int.max (stop, start), size text)
            fun lineOf pos = #1 (Source.lineCol (f, pos)) - first - 1
            fun bounds idx =
              let
                val a = Vector.sub (lineStarts, idx)
                val b = if idx + 1 < Vector.length lineStarts then Vector.sub (lineStarts, idx + 1) - 1 else size text
                val b = if b > a andalso String.sub (text, b - 1) = #"\r" then b - 1 else b
              in
                (a, Int.max (a, b))
              end
            val l1 = lineOf start
            val l2 = lineOf (if stop > start then stop - 1 else stop)
            val digits = size (Int.toString (first + l2 + 1))
            fun num n = StringCvt.padLeft #" " digits (Int.toString n)
            val blank = CharVector.tabulate (digits, fn _ => #" ")
            fun gutter s = paint "diag.gutter" (s ^ " |")
            fun source idx =
              let val (a, b) = bounds idx
              in gutter (num (first + idx + 1)) ^ " " ^ paint "diag.quote" (shown (cells (text, a, b))) end
            fun marks (idx, from, upto) =
              let
                val (a, b) = bounds idx
                val from = Int.max (a, Int.min (from, b))
                val upto = Int.max (from, Int.min (upto, b))
              in
                gutter blank ^ " " ^ under (cells (text, a, from)) ^
                paint level (repeat (#"^", width (cells (text, from, upto))))
              end
            val rows =
              if l1 = l2 then [source l1, marks (l1, start, stop)]
              else
                [source l1, marks (l1, start, #2 (bounds l1))]
                @ (if l2 > l1 + 1 then [paint "diag.gutter" "..."] else [])
                @ [source l2, marks (l2, #1 (bounds l2), stop)]
          in
            SOME (String.concatWith "\n" (gutter blank :: rows))
          end

  fun render (level, sp, msg) =
    let val head = firstLine (level, sp, msg)
    in
      case !mode of
        Short => head
      | Full => (case excerpt (level, sp) of SOME e => head ^ "\n" ^ e | NONE => head)
    end

  fun show (level, sp, msg) =
    (case !jsonFile of SOME _ => collected := (level, sp, msg) :: !collected | NONE => ();
     render (level, sp, msg))

  (* a warning replayed from the cache, which keeps its first line only *)
  fun showCached line =
    case !theme of
      NONE => line
    | SOME _ =>
        let
          val marker = ": warning: "
          fun find i =
            if i + size marker > size line then NONE
            else if String.substring (line, i, size marker) = marker then SOME i
            else find (i + 1)
        in
          case find 0 of
            NONE => line
          | SOME i =>
              paint "diag.location" (String.substring (line, 0, i + 1)) ^ " " ^ paint "warning" "warning:" ^ " " ^
              paint "diag.message" (String.extract (line, i + size marker, NONE))
        end

  (* --color, --diagnostics and --diagnostics-json, for standard error *)
  fun install {color, full, json} =
    let
      val fd = Posix.FileSys.stderr
      val tty = (Posix.ProcEnv.isatty fd) handle _ => false
      val dumb = OS.Process.getEnv "TERM" = SOME "dumb"
    in
      theme := Color.decide (color, fd);
      mode := (case full of SOME true => Full | SOME false => Short
                          | NONE => if tty andalso not dumb then Full else Short);
      jsonFile := json;
      collected := [];
      Error.show := show
    end

  (* a position as rune-ide's editor counts it: a line from 1, a column of
     UTF-16 units from 1 *)
  fun point (text, offset) =
    let
      val stop = Int.min (size text, Int.max (0, offset))
      fun go (i, line, col) =
        if i >= stop then (line, col)
        else
          let val (c, k) = Utf8.next (text, i)
          in if c = 10 then go (i + k, line + 1, 1) else go (i + k, line, col + (if c > 0xFFFF then 2 else 1)) end
    in
      go (0, 1, 1)
    end

  fun item (level, sp as {file, start, stop} : Source.span, msg) =
    let
      val range =
        case Source.findFile file of
          SOME {text, ...} =>
            if text = "" then Json.Null
            else
              let val (sl, sc) = point (text, start) val (el, ec) = point (text, stop)
              in Json.Object [("startLineNumber", Json.int sl), ("startColumn", Json.int sc),
                              ("endLineNumber", Json.int el), ("endColumn", Json.int ec)] end
        | NONE => Json.Null
      val plain =
        let val (t, m) = (!theme, !mode)
        in theme := NONE; mode := Full; (render (level, sp, msg) before (theme := t; mode := m)) end
    in
      Json.Object [("severity", Json.String level), ("message", Json.String msg), ("path", Json.String file),
                   ("startByte", Json.int start), ("endByte", Json.int stop), ("range", range),
                   ("rendered", Json.String plain)]
    end

  (* write the diagnostics of the run, when --diagnostics-json asked *)
  fun finish success =
    case !jsonFile of
      NONE => ()
    | SOME path =>
        let
          val report = Json.Object [("version", Json.int 1), ("success", Json.Bool success),
                                    ("compilerVersion", Json.String Config.version),
                                    ("diagnostics", Json.Array (map item (rev (!collected))))]
          val out = TextIO.openOut path
        in
          TextIO.output (out, Json.encode report ^ "\n"); TextIO.closeOut out
        end
end
