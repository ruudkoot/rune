(* Source files and positions. *)
structure Source =
struct
  type pos = int                       (* byte offset into the file *)
  type span = {file : string, start : pos, stop : pos}

  val noSpan : span = {file = "", start = 0, stop = 0}

  fun join (a : span, b : span) : span =
    {file = #file a, start = Int.min (#start a, #start b), stop = Int.max (#stop a, #stop b)}

  (* How a source is read (docs/plans/utf8.md, D1): the default, ASCII
     outside comments, or Unicode in an encoding, UTF-8 or Latin-1
     (--unicode=ENC). A mode is a file's, not the compile's: the Basis
     Library and the libraries are read in the default, a program's files
     in the mode that its command line, its build file or Compiler.compile
     says (docs/units.md). The modes differ in what a literal holds
     (Lexer.lexerOf), and a Latin-1 file is made UTF-8 as it is read
     (readFile). *)
  datatype encoding = Utf8 | Latin1
  datatype mode = Ascii | Unicode of encoding

  (* a mode by its name, as a build file's annotation, the command line's
     --unicode=ENC and Compiler.compile write it *)
  fun modeName (m : mode) : string =
    case m of
      Ascii => "ascii"
    | Unicode Utf8 => "unicode"
    | Unicode Latin1 => "unicode=latin1"
  fun modeNamed (s : string) : mode option =
    case s of
      "ascii" => SOME Ascii
    | "unicode" => SOME (Unicode Utf8)
    | "unicode=utf8" => SOME (Unicode Utf8)
    | "unicode=latin1" => SOME (Unicode Latin1)
    | _ => NONE

  (* A loaded source file with a table of line start offsets; line is the
     number, less one, of its first line in the file it is from: 0 for a
     whole file, more for a part of one compiled on its own
     (Compiler.compile); mode is how it is read. *)
  type file = {name : string, text : string, lineStarts : int vector, line : int, mode : mode}

  fun computeLineStarts (text : string) : int vector =
    let
      val n = String.size text
      val starts = ref [0]
      (* One argument: a pair would be allocated once per character. *)
      fun go i =
        if i >= n then ()
        else
          (if String.sub (text, i) = #"\n" then starts := (i + 1) :: !starts else ();
           go (i + 1))
    in
      go 0;
      Vector.fromList (List.rev (!starts))
    end

  fun fromStringIn (mode, name, text) : file =
    {name = name, text = text, lineStarts = computeLineStarts text, line = 0, mode = mode}

  (* a text the compiler makes for itself, which is read in the default *)
  fun fromString (name, text) : file = fromStringIn (Ascii, name, text)

  (* a part of a file that begins at its line `line` (from 1) *)
  fun fromStringAt (mode, name, text, line) : file =
    {name = name, text = text, lineStarts = computeLineStarts text, line = Int.max (line - 1, 0), mode = mode}

  (* the text of a file that is other than the file system's: an editor's
     buffer, which the compiler as a service compiles (Serve) *)
  val overlays : string StringMap.map ref = ref StringMap.empty

  (* Latin-1 text made UTF-8, a byte above 127 the two bytes of the
     character of its number: how a file read under --unicode=latin1 is
     taken in, so that the lexer, the positions and the diagnostics see
     UTF-8 alone (D3) *)
  fun latin1ToUtf8 (s : string) : string =
    if CharVector.all (fn c => Char.ord c < 128) s then s
    else
      String.translate
        (fn c => let val b = Char.ord c
                 in if b < 128 then String.str c
                    else String.implode [Char.chr (0xC0 + b div 64), Char.chr (0x80 + b mod 64)]
                 end) s

  (* the text of a file read in a mode: a Latin-1 file is made UTF-8; an
     editor's buffer is its text already *)
  fun readFile (mode : mode, name : string) : file =
    case StringMap.find (!overlays, name) of
      SOME text => fromStringIn (mode, name, text)
    | NONE =>
        let
          val ins = TextIO.openIn name
          val text = TextIO.inputAll ins
          val () = TextIO.closeIn ins
        in
          fromStringIn (mode, name, if mode = Unicode Latin1 then latin1ToUtf8 text else text)
        end

  (* 1-based line and column for a byte offset. *)
  fun lineCol ({lineStarts, line = first, ...} : file, pos : pos) : int * int =
    let
      val n = Vector.length lineStarts
      fun search (lo, hi) =
        if lo >= hi then lo
        else
          let val mid = (lo + hi + 1) div 2
          in if Vector.sub (lineStarts, mid) <= pos then search (mid, hi) else search (lo, mid - 1)
          end
      val line = search (0, n - 1)
    in
      (first + line + 1, pos - Vector.sub (lineStarts, line) + 1)
    end

  (* Registry of loaded files so that spans can be rendered anywhere. *)
  val files : file StringMap.map ref = ref StringMap.empty

  (* The file looked up last: positions come file by file, so most lookups
     are of the same file as the one before. *)
  val lastFile : (string * file) option ref = ref NONE

  (* of a file whose text keepLines let go, the lines that hold a byte
     above 127, by their index: what its columns are counted in *)
  val keptLines : string IntMap.map StringMap.map ref = ref StringMap.empty
  fun forget (name : string) =
    if StringMap.member (!keptLines, name) then keptLines := StringMap.remove (!keptLines, name) else ()

  fun register (f : file) = (files := StringMap.insert (!files, #name f, f); forget (#name f); lastFile := NONE)

  fun isAscii (s : string) : bool = CharVector.all (fn c => Char.ord c < 128) s

  (* What a session that compiles one source after another (the REPL)
     keeps of one it has compiled: its lines, to name the positions of its
     spans, and not its text, but for the lines that hold a character
     above ASCII, whose columns a person reads in characters (shownLineCol);
     and nothing of one it made for itself. *)
  fun keepLines (name : string) =
    case StringMap.find (!files, name) of
      SOME {text, lineStarts, line, mode, ...} =>
        let
          val n = Vector.length lineStarts
          fun lineAt k =
            let
              val a = Vector.sub (lineStarts, k)
              val b = if k + 1 < n then Vector.sub (lineStarts, k + 1) else size text
            in String.substring (text, a, Int.max (0, Int.min (b, size text) - a)) end
          val kept =
            if isAscii text then IntMap.empty
            else Vector.foldli (fn (k, _, m) => let val l = lineAt k in if isAscii l then m else IntMap.insert (m, k, l) end)
                               IntMap.empty lineStarts
        in
          files := StringMap.insert (!files, name, {name = name, text = "", lineStarts = lineStarts, line = line,
                                                    mode = mode});
          forget name;
          if IntMap.isEmpty kept then () else keptLines := StringMap.insert (!keptLines, name, kept);
          lastFile := NONE
        end
    | NONE => ()
  fun unregister (name : string) =
    (files := (if StringMap.member (!files, name) then StringMap.remove (!files, name) else !files);
     forget name; lastFile := NONE)

  fun load (mode : mode, name : string) : file =
    let val f = readFile (mode, name) in register f; f end

  fun findFile (name : string) : file option =
    case !lastFile of
      SOME (n, f) => if n = name then SOME f else findFile' name
    | NONE => findFile' name
  and findFile' name =
    case StringMap.find (!files, name) of
      NONE => NONE
    | SOME f => (lastFile := SOME (name, f); SOME f)

  (* The file, line and column a span starts at, for a source that was
     loaded. Positions are put in the bytecode this way, so that the VM never
     needs the source to name a line. *)
  fun lineColOf ({file, start, ...} : span) : (string * int * int) option =
    case findFile file of
      NONE => NONE
    | SOME f => let val (l, c) = lineCol (f, start) in SOME (file, l, c) end

  (* ---- what a person reads (docs/plans/utf8.md, D15; docs/diagnostics.md) ----
     Positions are bytes, and so are the columns of the line table
     (lineCol, lineColOf). A column a person reads counts characters, as
     rustc and Emacs count them, and one an editor's protocol reads (DAP,
     Monaco) counts UTF-16 units. Both are counted only where they are
     shown: counting them for every span of the line table would cost 4.1%
     of a compile (E10). *)

  (* how many characters bytes a to b of a text hold, a byte that is not
     UTF-8 being one, as an excerpt shows it (\xE9); and how many UTF-16
     units they would be *)
  fun countIn (wide : int -> int) (text : string, a : int, b : int) : int =
    let
      val b = Int.min (b, size text)
      fun go (i, k) =
        if i >= b then k
        else if Char.ord (String.sub (text, i)) < 128 then go (i + 1, k + 1)
        else case Utf8.decode (text, i) of
               SOME (c, m) => go (i + m, k + wide c)
             | NONE => go (i + 1, k + 1)
    in go (Int.max (a, 0), 0) end
  val charsIn = countIn (fn _ => 1)
  val utf16In = countIn (fn c => if c > 0xFFFF then 2 else 1)

  (* the text of the line of index k of a file, where it begins in the
     text and where the next begins: the file's own, or the line
     keepLines kept; NONE where neither holds it, which keepLines leaves
     only of an ASCII line *)
  fun lineOfIndex ({name, text, lineStarts, ...} : file, k : int) : (string * int * int) option =
    if k < 0 orelse k >= Vector.length lineStarts then NONE
    else if text <> "" then
      SOME (text, Vector.sub (lineStarts, k),
            if k + 1 < Vector.length lineStarts then Vector.sub (lineStarts, k + 1) else size text)
    else
      case StringMap.find (!keptLines, name) of
        SOME m => Option.map (fn l => (l, 0, size l)) (IntMap.find (m, k))
      | NONE => NONE

  (* the column, from 1, counted by count, of byte column col of the line
     of index k: the byte column where the line is ASCII or gone, and
     where the line is shorter than the column, which is then of another
     text the name was given to (the REPL's entries, stdIn, take one name
     in turn) *)
  fun columnIn (count : string * int * int -> int) (f : file, k : int, col : int) : int =
    case lineOfIndex (f, k) of
      SOME (text, a, b) => if a + col - 1 > b then col else 1 + count (text, a, a + col - 1)
    | NONE => col

  (* the line and the column in characters a person reads of a byte
     offset: what a diagnostic's first line says *)
  fun shownLineCol (f : file, pos : pos) : int * int =
    let val (l, c) = lineCol (f, pos)
    in (l, columnIn charsIn (f, l - #line f - 1, c)) end

  (* the line as it is on disk, for a file that is not registered *)
  fun lineOnDisk (name : string, line : int) : string option =
    let
      val ins = TextIO.openIn name
      fun go k = case TextIO.inputLine ins of
                   NONE => NONE
                 | SOME l => if k = line then SOME l else go (k + 1)
    in (go 1 before TextIO.closeIn ins) handle e => (TextIO.closeIn ins; raise e) end
    handle IO.Io _ => NONE

  (* the column, counted by count, of a byte column of a line of a file:
     where a frame of a trace or of the debugger is, which the line table
     gives in bytes. A file that is not registered is read from disk; one
     that cannot be read keeps the byte column. *)
  fun columnOf (count : string * int * int -> int) (name : string, line : int, col : int) : int =
    let
      fun fromDisk () =
        case lineOnDisk (name, line) of
          SOME l => if col - 1 > size l then col else 1 + count (l, 0, col - 1)
        | NONE => col
    in
      if col <= 1 then col
      else
        case findFile name of
          SOME f =>
            (* a part of the file (Compiler.compile) may not hold the line *)
            let val k = line - #line f - 1
            in if k < 0 orelse k >= Vector.length (#lineStarts f) then fromDisk () else columnIn count (f, k, col) end
        | NONE => fromDisk ()
    end
  val shownColumn = columnOf charsIn
  val utf16Column = columnOf utf16In

  (* a file's name as a person reads it in a diagnostic: what would not
     show, or could make the line read otherwise -- a control (C0, DEL,
     C1), a bidirectional control or another default-ignorable character,
     and a byte that is not UTF-8 -- escaped, as an excerpt escapes it:
     \u{202E}, \xE9 *)
  fun shownName (name : string) : string =
    if CharVector.all (fn c => Char.ord c >= 32 andalso Char.ord c < 127) name then name
    else
      let
        fun hex c = Int.fmt StringCvt.HEX c
        fun go (i, acc) =
          if i >= size name then String.concat (List.rev acc)
          else
            case Utf8.decode (name, i) of
              NONE => go (i + 1, ("\\x" ^ StringCvt.padLeft #"0" 2 (hex (Char.ord (String.sub (name, i))))) :: acc)
            | SOME (c, k) =>
                if c < 32 orelse (c >= 127 andalso c < 160) orelse Identifier.isDefaultIgnorable c
                then go (i + k, ("\\u{" ^ hex c ^ "}") :: acc)
                else go (i + k, String.substring (name, i, k) :: acc)
      in go (0, []) end

  (* file:line:col of a frame as a person reads it: the byte column of the
     line table in characters, the name escaped *)
  fun shownPlace (name : string, line : int, col : int) : string =
    shownName name ^ ":" ^ Int.toString line ^ ":" ^ Int.toString (shownColumn (name, line, col))

  (* file:line:col as a diagnostic's first line says it, the column in
     characters and the name escaped *)
  fun describe ({file, start, ...} : span) : string =
    case StringMap.find (!files, file) of
      NONE => if file = "" then "<unknown>" else shownName file
    | SOME f =>
      let val (l, c) = shownLineCol (f, start)
      in shownName file ^ ":" ^ Int.toString l ^ ":" ^ Int.toString c end
end
