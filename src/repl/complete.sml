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
             (String.tokens (fn c => not (Char.isAlphaNum c orelse c = #"_" orelse c = #"'")) text)

  fun isNameChar c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"

  (* the candidates in order: most used first, then by name *)
  fun ranked (prefix : string, names : string list) : string list =
    let
      val own = String.isPrefix "Rune" prefix orelse String.isPrefix "RUNE" prefix
      val chosen = List.filter (fn n => String.isPrefix prefix n
                                        andalso (own orelse not (String.isPrefix "Rune" n orelse String.isPrefix "RUNE" n))
                                        andalso not (String.isPrefix "rune'" n))
                               names
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
      val (pieces, _) = Lexer.scan (String.substring (text, l, i - l), Lexer.Code)
    in
      case List.rev pieces of
        (a, b, c) :: _ =>
          if (c = Lexer.Text orelse c = Lexer.Bad) andalso b = i - l andalso String.sub (text, l + a) = #"\""
             andalso (c = Lexer.Bad orelse b - a < 2 orelse String.sub (text, i - 1) <> #"\"")
          then SOME (l + a + 1) else NONE
      | [] => NONE
    end

  (* complete env (text, i): where the word before byte i begins and what it
     can be completed to (LineEdit's complete) *)
  fun complete (env : Env.env) (text : string, i : int) : {start : int, candidates : string list} =
    let
      fun back j = if j > 0 andalso (isNameChar (String.sub (text, j - 1)) orelse String.sub (text, j - 1) = #".")
                   then back (j - 1) else j
      val first = let fun skip j = if j < i andalso Char.isSpace (String.sub (text, j)) then skip (j + 1) else j
                  in skip 0 end
    in
      if first < i andalso String.sub (text, first) = #":" andalso
         CharVector.all isNameChar (String.substring (text, first + 1, i - first - 1)) then
        (* a command *)
        {start = first, candidates = ranked (String.substring (text, first, i - first), !commands)}
      else
        case stringStart (text, i) of
          SOME s =>
            let
              val ahead = String.substring (text, 0, s - 1)
              val words = String.tokens (not o isNameChar) ahead
            in
              if not (List.null words) andalso List.last words = "use" then
                {start = s, candidates = ranked (String.substring (text, s, i - s), files (String.substring (text, s, i - s)))}
              else {start = i, candidates = []}
            end
        | NONE =>
            let
              val s = back i
              val word = String.substring (text, s, i - s)
              val parts = String.fields (fn c => c = #".") word
              val last = List.last parts
              val path = List.take (parts, List.length parts - 1)
              val start = i - String.size last
            in
              case ReplHighlight.structureAt (env, path) of
                SOME e =>
                  if last = "" andalso List.null path then {start = i, candidates = []}
                  else {start = start, candidates = ranked (last, namesIn (e, typeExpected (text, s)))}
              | NONE => {start = i, candidates = []}
            end
    end
end
