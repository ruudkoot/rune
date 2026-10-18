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
     says (docs/units.md). As yet every mode reads a text alike: the
     roadmap's M3 and M4 give them their rules. *)
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

  fun readFile (mode : mode, name : string) : file =
    case StringMap.find (!overlays, name) of
      SOME text => fromStringIn (mode, name, text)
    | NONE =>
        let
          val ins = TextIO.openIn name
          val text = TextIO.inputAll ins
          val () = TextIO.closeIn ins
        in
          fromStringIn (mode, name, text)
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

  fun register (f : file) = (files := StringMap.insert (!files, #name f, f); lastFile := NONE)

  (* What a session that compiles one source after another (the REPL)
     keeps of one it has compiled: its lines, to name the positions of its
     spans, and not its text; and nothing of one it made for itself. *)
  fun keepLines (name : string) =
    case StringMap.find (!files, name) of
      SOME {lineStarts, line, mode, ...} =>
        (files := StringMap.insert (!files, name, {name = name, text = "", lineStarts = lineStarts, line = line,
                                                   mode = mode});
         lastFile := NONE)
    | NONE => ()
  fun unregister (name : string) =
    (files := (if StringMap.member (!files, name) then StringMap.remove (!files, name) else !files); lastFile := NONE)

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

  fun describe ({file, start, ...} : span) : string =
    case StringMap.find (!files, file) of
      NONE => if file = "" then "<unknown>" else file
    | SOME f =>
      let val (l, c) = lineCol (f, start)
      in file ^ ":" ^ Int.toString l ^ ":" ^ Int.toString c end
end
