(* The MANIFEST of a library -- the basis library, or one of the libraries
   beside it (docs/plans/quickcheck.md, D1) -- and the choice of the files a
   program loads: shared by the compiler driver and runedoc. *)
structure BasisManifest =
struct
  exception Usage of string

  (* ---- the basis library: lib/basis/MANIFEST ----
     One file per line, in load order:
       file | always or demand | host | provides | requires
     provides: the structures, signatures and functors the file declares;
     requires: those of other files that it names. (host is for the
     cross-check of tests/basis.) A program is compiled after the always
     files, the files that provide a name it mentions, and what those require:
     the scan below looks at identifiers only, so it may load a file the
     program does not need, never miss one it does. A name can have several
     files, as IO and OS do (the structure and the signature of the
     specification); naming it loads them all. A seal file binds structures
     again as their signatures show them; it is loaded for a program that
     mentions one, never because a file of the library requires the name. *)
  datatype when = Always | Demand | Seal | Final
  (* requires is read from the text when it is asked for: most programs need
     it of few files. dir is the directory of the library the file is in. *)
  type entry = {dir : string, file : string, when : when, provides : string list,
                requires : unit -> string list, scope : (string * string) list option}

  (* A sixth MANIFEST field carries a library's complete export boundary.
     Five-field manifests retain their historical visibility. *)
  fun public (e : entry) =
    case #scope e of NONE => #provides e
    | SOME es => List.filter (fn n => List.exists (fn (_, exported) => exported = n) es) (#provides e)

  fun scopeOf (es : entry list) =
    case es of [] => NONE | e :: rest =>
      if List.all (fn other : entry => #scope other = #scope e) rest then #scope e
      else raise Usage ("inconsistent export boundary in " ^ #dir e ^ "/MANIFEST")

  (* The file of an entry, as a path. *)
  fun path (e : entry) : string = #dir e ^ "/" ^ #file e

  fun trim (s : string) : string =
    let
      val n = String.size s
      fun left i = if i < n andalso Char.isSpace (String.sub (s, i)) then left (i + 1) else i
      fun right j = if j > 0 andalso Char.isSpace (String.sub (s, j - 1)) then right (j - 1) else j
      val i = left 0
      val j = right n
    in if i >= j then "" else String.substring (s, i, j - i) end

  (* The MANIFEST is read for every program, so it is scanned in one pass
     over its text, a line at a time, with the bars and the words of a line
     found by index rather than by splitting it into strings first. *)
  fun readManifest (dir : string) : entry list =
    let
      val manifest = dir ^ "/MANIFEST"
      val ins = TextIO.openIn manifest
                handle IO.Io _ => raise Usage ("cannot read basis manifest " ^ manifest ^ " (use --lib or --no-prelude)")
      val text = TextIO.inputAll ins before TextIO.closeIn ins
      val n = String.size text
      fun at k = String.sub (text, k)
      fun blank c = c = #" " orelse c = #"\t" orelse c = #"\r"
      (* the words of text[i, j) *)
      fun words (i, j) =
        let
          fun skip k = if k < j andalso blank (at k) then skip (k + 1) else k
          fun stop k = if k < j andalso not (blank (at k)) then stop (k + 1) else k
          fun go (k, acc) =
            let val a = skip k
            in if a >= j then List.rev acc else let val e = stop a in go (e, String.substring (text, a, e - a) :: acc) end end
        in go (i, []) end
      fun bad (i, e) = raise Usage ("malformed line in " ^ manifest ^ ": " ^ String.substring (text, i, e - i))
      (* the one word of text[i, j), or NONE *)
      fun one (i, j) = case words (i, j) of [w] => SOME w | _ => NONE
      (* A line of five fields, optionally followed by the library's scope. *)
      fun entry (i, e) =
        let
          fun bars (k, acc) = if k >= e then List.rev acc else bars (k + 1, if at k = #"|" then k :: acc else acc)
          fun exports (a,b) =
            case words (a,b) of
              ["-"] => []
            | ws => List.map (fn word =>
                case String.fields (fn c => c = #":") word of
                  [kind,n] => if n <> "" andalso List.exists (fn x => kind=x) ["structure","signature","functor","type"]
                              then (kind,n) else bad (i,e)
                | _ => bad (i,e)) ws
          fun make (b1,b2,b3,b4,last,scope) =
            case (one (i,b1),one (b1+1,b2)) of
              (SOME file,SOME mode) =>
                {dir=dir,file=file,
                 when=(case mode of "always" => Always | "demand" => Demand | "seal" => Seal | "final" => Final | _ => bad (i,e)),
                 provides=words (b3+1,b4),requires=fn () => words (b4+1,last),scope=scope}
            | _ => bad (i,e)
        in
          case bars (i,[]) of
            [b1,b2,b3,b4] => make (b1,b2,b3,b4,e,NONE)
          | [b1,b2,b3,b4,b5] => make (b1,b2,b3,b4,b5,SOME (exports (b5+1,e)))
          | _ => bad (i,e)
        end
      fun go (i, acc) =
        if i >= n then List.rev acc
        else
          let
            fun eol k = if k < n andalso at k <> #"\n" then eol (k + 1) else k
            val e = eol i
            fun first k = if k < e andalso blank (at k) then first (k + 1) else k
            val f = first i
          in
            if f >= e orelse at f = #"#" then go (e + 1, acc) else go (e + 1, entry (i, e) :: acc)
          end
    in let val entries = go (0, []) val _ = scopeOf entries in entries end end

  type names = unit StringMap.map

  (* The identifiers of a token stream, and the heads of its long identifiers. *)
  fun namesOf (toks : Lexer.item vector, acc : names) : names =
    Vector.foldl (fn ((Token.ID s, _), acc) => StringMap.insert (acc, s, ())
                   | ((Token.LONGID (s :: _, _), _), acc) => StringMap.insert (acc, s, ())
                   (* a dynamic module's boundary is RuneDynamic's (docs/units.md) *)
                   | ((Token.DYNAMIC, _), acc) => StringMap.insert (acc, "RuneDynamic", ())
                   | ((Token.EXPORT, _), acc) => StringMap.insert (acc, "RuneDynamic", ())
                   | ((Token.VIRTUAL, _), acc) => StringMap.insert (acc, "RuneDynamic", ())
                   | (_, acc) => acc) acc toks

  (* name -> the files that provide it, as paths, in MANIFEST order *)
  fun providers (entries : entry list) : string list StringMap.map =
    List.foldl (fn (e : entry, m) =>
                   List.foldl (fn (n, m) =>
                                  StringMap.insert (m, n, (case StringMap.find (m, n) of
                                                             SOME fs => fs @ [path e]
                                                           | NONE => [path e])))
                              m (#provides e))
               StringMap.empty entries

  (* The entries to load for a program that mentions the given names, in
     MANIFEST order. *)
  fun select (entries : entry list, mentioned : names) : entry list =
    let
      (* The files that provide a name: a scan of the entries, compared with
         the primitive =, for the few names the chosen files require (a map of
         every name would cost more to build than a program needs). *)
      (* A seal file binds a structure again, as its signature shows it: that
         is for the program that mentions the structure. The files of the
         library that need it have it whole, from the file that declares it. *)
      fun providersOf (from : entry, n) =
        List.filter (fn e : entry => #when e <> Seal andalso
          List.exists (fn p => p=n) (if #dir from = #dir e then #provides e else public e)) entries
      fun required (e : entry) = List.filter (fn n => not (String.isPrefix "-" n)) (#requires e ())
      fun add (e : entry, chosen : names) : names =
        if StringMap.member (chosen, path e) then chosen
        else
          List.foldl (fn (n, chosen) =>
                         case providersOf (e,n) of
                           [] => raise Usage ("basis manifest: " ^ #file e ^ " requires " ^ n ^
                                                      ", which no file provides")
                         | es => List.foldl add chosen es)
                     (StringMap.insert (chosen, path e, ()))
                     (required e)
      val wanted = fn e : entry => #when e = Always orelse List.exists (fn n => StringMap.member (mentioned, n)) (public e)
      val chosen = List.foldl (fn (e, chosen) => if wanted e then add (e, chosen) else chosen) StringMap.empty entries
      (* A file compiled after the program joins it only when what it needs is
         there anyway: a program that never mentions OS has nothing to do when
         it ends. *)
      val chosen =
        List.foldl (fn (e : entry, chosen) =>
                       if #when e = Final
                          andalso List.all (fn n => List.exists (fn e' : entry => StringMap.member (chosen, path e'))
                                                                (providersOf (e,n)))
                                           (required e)
                       then add (e, chosen) else chosen)
                   chosen entries
    in List.filter (fn e : entry => StringMap.member (chosen, path e)) entries end

  (* ---- the libraries beside the basis library ----
     A library is a directory with a MANIFEST in the form above. The libraries
     it is written on besides the basis library are named in its MANIFEST by
     a line
       # library: NAME ...
     and are loaded before it. A NAME is a directory under the directory of
     the libraries (--lib), test/property for LIBDIR/test/property, unless it
     is an absolute host path or begins with ., when it is a path. *)

  fun isLibraryPath name = OS.Path.isAbsolute name orelse String.isPrefix "." name

  fun libraryDir (libDir : string, name : string) : string =
    if isLibraryPath name then name else libDir ^ "/" ^ name

  (* The words of a MANIFEST's header lines that begin with key: the
     comments --basis-index writes before the first file's line, which is
     where the reading stops, so that a compile reads no more of the file
     than its header for them (the Basis Library's is 25 KB, which read
     again a line at a time cost every compile 0.3M instructions; M8). *)
  fun headerWords (ins : TextIO.instream, key : string) : string list =
    let
      fun lines acc =
        case TextIO.inputLine ins of
          NONE => List.rev acc
        | SOME l =>
            let val l = trim l
            in
              if String.isPrefix key l
              then lines (List.rev (String.tokens Char.isSpace (String.extract (l, size key, NONE))) @ acc)
              else if String.isPrefix "#" l then lines acc
              else List.rev acc
            end
    in lines [] before TextIO.closeIn ins end

  (* The libraries a library's MANIFEST names on its # library: lines. *)
  fun libraryRequires (dir : string) : string list =
    let
      val manifest = dir ^ "/MANIFEST"
      val ins = TextIO.openIn manifest handle IO.Io _ => raise Usage ("cannot read library manifest " ^ manifest)
    in headerWords (ins, "# library:") end

  (* The functors a library's MANIFEST marks to be inlined across units, on
     its # inline: lines (its build file's `inline functor ... end`; M6b) *)
  fun inlineFunctors (dir : string) : string list =
    headerWords (TextIO.openIn (dir ^ "/MANIFEST"), "# inline:")
    handle IO.Io _ => []

  (* The directories of the named libraries and of those they are written on,
     each once, every library after the ones it names. *)
  fun libraries (libDir : string, names : string list) : string list =
    let
      fun visit (stack : string list) (name : string, done : string list) : string list =
        let val dir = libraryDir (libDir, name)
        in
          if List.exists (fn d => d = dir) done then done
          else if List.exists (fn d => d = dir) stack
          then raise Usage ("library " ^ name ^ " is written on itself (" ^ String.concatWith " <- " (dir :: stack) ^ ")")
          else
            let val done = List.foldl (visit (dir :: stack)) done (libraryRequires dir)
            in done @ [dir] end
        end
    in List.foldl (visit []) [] names end
end
