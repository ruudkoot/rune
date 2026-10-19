(* Completion at the REPL (docs/plans/repl.md, D14): what the cursor is in
   decides what it completes. After a `:` that begins the entry, the
   commands; inside a string after `use`, the names of files; elsewhere the
   names of the session -- values, constructors, structures, and the types
   where the text before says a type is expected -- and after a structure's
   name and a dot, its members. The environment is read without counting
   as a use (ReplHighlight). Candidates come by how often the session has
   used them, then in order, and the library's own (`Rune...`) only when
   what is typed begins so. *)
structure ReplComplete =
struct
  (* the commands, with a word on each (ReplCommands fills it) *)
  val commands : string list ref = ref []

  (* how often each name was typed in the entries run (ReplFront counts) *)
  val uses : int StringMap.map ref = ref StringMap.empty

  fun count (name : string) = case StringMap.find (!uses, name) of SOME k => k | NONE => 0

  fun noteUses (text : string) : unit =
    List.app (fn w => uses := StringMap.insert (!uses, w, count w + 1))
             (String.tokens (not o Ident.isNameByte) text)

  (* a byte of a name: an ASCII one, or one of a character above 127 (Ident) *)
  val isNameChar = Ident.isNameByte

  (* whether a name is offered for what is typed: the library's own
     (`Rune...`) only when what is typed begins so, and never the names the
     REPL makes (`rune'...`) *)
  fun offered (prefix : string) (n : string) : bool =
    String.isPrefix prefix n
    andalso (String.isPrefix "Rune" prefix orelse String.isPrefix "RUNE" prefix
             orelse not (String.isPrefix "Rune" n orelse String.isPrefix "RUNE" n))
    andalso not (String.isPrefix "rune'" n)

  (* the candidates in order: most used first, then by name *)
  fun ranked (prefix : string, names : string list) : string list =
    let
      val chosen = List.filter (offered prefix) names
      fun earlier (a, b) =
        case Int.compare (count b, count a) of
          EQUAL => String.compare (a, b) = LESS
        | ord => ord = LESS
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if earlier (x, y) then x :: y :: ys else y :: insert (x, ys)
      fun dedup (x :: (rest as y :: _)) = if x = y then dedup rest else x :: dedup rest
        | dedup l = l
    in dedup (List.foldl insert [] chosen) end

  (* the names of an environment: values and structures, and types where
     one is expected *)
  fun namesIn (env : Env.env, types : bool) : string list =
    StringMap.listKeys (Env.vals env) @ StringMap.listKeys (Env.strs env)
    @ (if types then StringMap.listKeys (Env.tys env) else [])

  (* whether the text before i, its spaces aside, says a type comes next *)
  fun typeExpected (text : string, i : int) : bool =
    let
      fun back j = if j > 0 andalso Char.isSpace (String.sub (text, j - 1)) then back (j - 1) else j
      val j = back i
      fun endsWith w = j >= String.size w andalso String.substring (text, j - String.size w, String.size w) = w
                       andalso (j = String.size w orelse not (isNameChar (String.sub (text, j - String.size w - 1))))
    in
      j > 0 andalso (String.sub (text, j - 1) = #":" orelse String.sub (text, j - 1) = #"*")
      orelse endsWith "->" orelse endsWith "of" orelse endsWith "type" orelse endsWith "datatype"
    end

  (* the file names that begin with what is typed of one, in its directory *)
  fun files (typed : string) : string list =
    let
      val {dir, file} = OS.Path.splitDirFile typed
      val d = OS.FileSys.openDir (if dir = "" then "." else dir)
      fun read acc =
        case OS.FileSys.readDir d of
          NONE => acc
        | SOME f =>
            if String.isPrefix file f andalso not (String.isPrefix "." f andalso not (String.isPrefix "." file)) then
              let
                val path = if dir = "" then f else OS.Path.joinDirFile {dir = dir, file = f}
                val shown = if (OS.FileSys.isDir path handle OS.SysErr _ => false) then path ^ "/" else path
              in read (shown :: acc) end
            else read acc
    in
      (read [] before OS.FileSys.closeDir d) handle OS.SysErr _ => (OS.FileSys.closeDir d; [])
    end
    handle OS.SysErr _ => []

  (* where a string the cursor is in began, if it is in one: the line's
     pieces of the lexer for the eye up to the cursor *)
  fun stringStart (text : string, i : int) : int option =
    let
      fun lineStart j = if j > 0 andalso String.sub (text, j - 1) <> #"\n" then lineStart (j - 1) else j
      val l = lineStart i
      val (pieces, _) = Lexer.scan (ReplSession.typedMode (), String.substring (text, l, i - l), Lexer.Code)
    in
      case List.rev pieces of
        (a, b, c) :: _ =>
          if (c = Lexer.Text orelse c = Lexer.Bad) andalso b = i - l andalso String.sub (text, l + a) = #"\""
             andalso (c = Lexer.Bad orelse b - a < 2 orelse String.sub (text, i - 1) <> #"\"")
          then SOME (l + a + 1) else NONE
      | [] => NONE
    end

  (* What the word before byte i of a text is: the name of a command (`:`
     beginning the entry), a file's name in a string after `use`, a name --
     after a structure's path, a type's where one is expected -- or
     nothing; with where it begins. *)
  datatype word = Command of int * string | File of int * string | Name of int * string list * string * bool
                | Nothing of int

  fun wordAt (text : string, i : int) : word =
    let
      fun back j = if j > 0 andalso (isNameChar (String.sub (text, j - 1)) orelse String.sub (text, j - 1) = #".")
                   then back (j - 1) else j
      val first = let fun skip j = if j < i andalso Char.isSpace (String.sub (text, j)) then skip (j + 1) else j
                  in skip 0 end
    in
      if first < i andalso String.sub (text, first) = #":" andalso
         CharVector.all isNameChar (String.substring (text, first + 1, i - first - 1)) then
        Command (first, String.substring (text, first, i - first))
      else
        case stringStart (text, i) of
          SOME s =>
            let val words = String.tokens (not o isNameChar) (String.substring (text, 0, s - 1))
            in
              if not (List.null words) andalso List.last words = "use" then File (s, String.substring (text, s, i - s))
              else Nothing i
            end
        | NONE =>
            let
              val s = back i
              val parts = String.fields (fn c => c = #".") (String.substring (text, s, i - s))
              val last = List.last parts
              val path = List.take (parts, List.length parts - 1)
            in
              if last = "" andalso List.null path then Nothing i
              else Name (i - String.size last, path, last, typeExpected (text, s))
            end
    end

  (* complete env (text, i): where the word before byte i begins and what it
     can be completed to (LineEdit's complete) *)
  fun complete (env : Env.env) (text : string, i : int) : {start : int, candidates : string list} =
    case wordAt (text, i) of
      Command (s, w) => {start = s, candidates = ranked (w, !commands)}
    | File (s, w) => {start = s, candidates = ranked (w, files w)}
    | Name (s, path, last, types) =>
        (case ReplHighlight.structureAt (env, path) of
           SOME e => {start = s, candidates = ranked (last, namesIn (e, types))}
         | NONE => {start = i, candidates = []})
    | Nothing i => {start = i, candidates = []}

  (* the longest text each of the names begins with *)
  fun commonPrefix ([] : string list) : string = ""
    | commonPrefix (n :: ns) =
        List.foldl (fn (m, p) =>
                      let fun same k = if k < String.size p andalso k < String.size m
                                          andalso String.sub (p, k) = String.sub (m, k) then same (k + 1) else k
                      in String.substring (p, 0, same 0) end) n ns

  (* What the names of a map offered for p (`offered`) all begin with: what
     the least and the greatest of them do, which are found at the edges of
     the range of keys beginning with p, past the ranges of the names not
     offered -- in the height of the tree, whatever the map's size. *)
  fun edges (m : 'a StringMap.map, p : string) : string list =
    let
      val hidden = List.filter (fn x => not (String.isPrefix x p) orelse x = "rune'")
                               (if String.isPrefix "Rune" p orelse String.isPrefix "RUNE" p then ["rune'"]
                                else ["Rune", "RUNE", "rune'"])
      fun below x k = String.compare (k, x) = LESS
      fun upTo x k = below x k orelse String.isPrefix x k
      fun hiddenBy k = List.find (fn x => String.isPrefix x k) hidden
      fun least k =
        case k of
          SOME k => if not (String.isPrefix p k) then NONE
                    else (case hiddenBy k of SOME x => least (StringMap.firstNot (upTo x) m) | NONE => SOME k)
        | NONE => NONE
      fun greatest k =
        case k of
          SOME k => if not (String.isPrefix p k) then NONE
                    else (case hiddenBy k of SOME x => greatest (StringMap.lastWhere (below x) m) | NONE => SOME k)
        | NONE => NONE
    in
      List.mapPartial (fn x => x) [least (StringMap.firstNot (below p) m), greatest (StringMap.lastWhere (upTo p) m)]
    end

  (* hinter env: what Tab would add at the end of a text, to be shown
     faintly after it (LineEdit's hint) -- the rest of the one candidate,
     or of what every candidate begins with -- and NONE where that is
     nothing or the text ends in a comment. A name's costs the height of
     the session's maps (edges); made for a prompt, it keeps the last
     text's hint, for a redraw of the same text, and the entries of each
     directory it read. *)
  fun hinter (env : Env.env) : string -> string option =
    let
      val last : (string * string option) option ref = ref NONE
      val listings : (string * string list) list ref = ref []
      fun kept (cache, key, make) =
        case List.find (fn (k, _) => k = key) (!cache) of
          SOME (_, v) => v
        | NONE => let val v = make () in cache := (key, v) :: !cache; v end
      fun filesFor typed =
        let
          val {dir, ...} = OS.Path.splitDirFile typed
          val entries = kept (listings, dir, fn () => files (if dir = "" then "" else OS.Path.joinDirFile {dir = dir, file = ""}))
        in List.filter (String.isPrefix typed) entries end
        handle OS.Path.Path => []
      fun rest (typed, NONE) = NONE
        | rest (typed, SOME p) =
            if String.size p > String.size typed andalso String.isPrefix typed p
            then SOME (String.extract (p, String.size typed, NONE)) else NONE
      fun common [] = NONE
        | common cs = SOME (commonPrefix cs)
      fun compute text =
        if ReplHighlight.endsInComment (env, text) then NONE
        else
          case wordAt (text, String.size text) of
            Command (_, w) => rest (w, common (List.filter (offered w) (!commands)))
          | File (_, w) => rest (w, common (filesFor w))
          | Name (_, path, word, types) =>
              (case ReplHighlight.structureAt (env, path) of
                 SOME e => rest (word, common (edges (Env.vals e, word) @ edges (Env.strs e, word)
                                               @ (if types then edges (Env.tys e, word) else [])))
               | NONE => NONE)
          | Nothing _ => NONE
    in
      fn text =>
        case !last of
          SOME (t, h) => if t = text then h else let val h = compute text in last := SOME (text, h); h end
        | NONE => let val h = compute text in last := SOME (text, h); h end
    end
end
