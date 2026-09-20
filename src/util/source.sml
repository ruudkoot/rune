(* Source files and positions. *)
structure Source =
struct
  type pos = int                       (* byte offset into the file *)
  type span = {file : string, start : pos, stop : pos}

  val noSpan : span = {file = "", start = 0, stop = 0}

  fun join (a : span, b : span) : span =
    {file = #file a, start = Int.min (#start a, #start b), stop = Int.max (#stop a, #stop b)}

  (* A loaded source file with a table of line start offsets. *)
  type file = {name : string, text : string, lineStarts : int vector}

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

  fun fromString (name, text) : file =
    {name = name, text = text, lineStarts = computeLineStarts text}

  fun readFile (name : string) : file =
    let
      val ins = TextIO.openIn name
      val text = TextIO.inputAll ins
      val () = TextIO.closeIn ins
    in
      fromString (name, text)
    end

  (* 1-based line and column for a byte offset. *)
  fun lineCol ({lineStarts, ...} : file, pos : pos) : int * int =
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
      (line + 1, pos - Vector.sub (lineStarts, line) + 1)
    end

  (* Registry of loaded files so that spans can be rendered anywhere. *)
  val files : file StringMap.map ref = ref StringMap.empty

  fun register (f : file) = files := StringMap.insert (!files, #name f, f)

  fun load (name : string) : file =
    let val f = readFile name in register f; f end

  fun describe ({file, start, ...} : span) : string =
    case StringMap.find (!files, file) of
      NONE => if file = "" then "<unknown>" else file
    | SOME f =>
      let val (l, c) = lineCol (f, start)
      in file ^ ":" ^ Int.toString l ^ ":" ^ Int.toString c end
end
