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
     files, the files that provide a name it mentions, and what those require.
     A file of a program mentions the names it uses (Deps; Main.usedBy), and a
     file of a library those of its identifiers (namesOf), so a selection may
     load a file a program does not need, never miss one it does. A name can have several
     files, as IO and OS do (the structure and the signature of the
     specification); naming it loads them all. A seal file binds structures
     again as their signatures show them; it is loaded for a program that
     mentions one, never because a file of the library requires the name. *)
  datatype when = Always | Demand | Seal | Final
  (* What a library's header says beside its exports, which are scope, and
     what it requires, which are its # library: lines; a library with none
     has NONE, whose files see all before them and whose `libraries` are
     transitive (docs/build.md, A library's header; D7, D15). *)
  type header = {friends : string list, views : (string * (string * string) list) list}
  (* requires is read from the text when it is asked for: most programs need
     it of few files. dir is the directory of the library the file is in. *)
  type entry = {dir : string, file : string, when : when, provides : string list,
                requires : unit -> string list, scope : (string * string) list option,
                header : header option}

  (* A library's export boundary: its header's, on an # exports: line, or a
     library (...) block's, in a sixth MANIFEST field. Five-field manifests
     retain their historical visibility. *)
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
      (* a list of exports, KIND:NAME each; a name may hold a colon *)
      fun exports (i, e, a, b) =
        case words (a,b) of
          ["-"] => []
        | ws => List.map (fn word =>
            case String.fields (fn c => c = #":") word of
              kind :: (name as _ :: _) =>
                let val n = String.concatWith ":" name
                in if n <> "" andalso List.exists (fn x => kind=x) ["structure","signature","functor","type","fixity"]
                   then (kind,n) else bad (i,e) end
            | _ => bad (i,e)) ws
      (* the header's lines, which come before the first file's *)
      val headed = ref NONE : (string * string) list option ref
      val friends = ref [] : string list ref
      val views = ref [] : (string * (string * string) list) list ref
      fun comment (i, f, e) =
        if f + 2 >= e orelse not (Char.contains "efv" (at (f + 2))) then ()
        else
          let
            val line = String.substring (text, f, e - f)
            fun after key = f + size key
          in
            if String.isPrefix "# exports:" line then headed := SOME (exports (i, e, after "# exports:", e))
            else if String.isPrefix "# friends:" line then friends := !friends @ words (after "# friends:", e)
            else if String.isPrefix "# view:" line then
              (case words (after "# view:", e) of
                 n :: _ =>
                   let
                     fun skip k = if k < e andalso blank (at k) then skip (k + 1) else k
                     val start = skip (after "# view:") + size n
                   in views := (n, exports (i, e, start, e)) :: !views end
               | [] => bad (i, e))
            else ()
          end
      (* A line of five fields, optionally followed by the library's scope. *)
      fun entry (i, e) =
        let
          fun bars (k, acc) = if k >= e then List.rev acc else bars (k + 1, if at k = #"|" then k :: acc else acc)
          fun make (b1,b2,b3,b4,last,scope) =
            case (one (i,b1),one (b1+1,b2)) of
              (SOME file,SOME mode) =>
                {dir=dir,file=file,
                 when=(case mode of "always" => Always | "demand" => Demand | "seal" => Seal | "final" => Final | _ => bad (i,e)),
                 provides=words (b3+1,b4),requires=fn () => words (b4+1,last),scope=scope,
                 header=Option.map (fn _ => {friends= !friends,views=List.rev (!views)}) (!headed)}
            | _ => bad (i,e)
        in
          case bars (i,[]) of
            [b1,b2,b3,b4] => make (b1,b2,b3,b4,e,!headed)
          | [b1,b2,b3,b4,b5] => make (b1,b2,b3,b4,b5,SOME (exports (i,e,b5+1,e)))
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
            if f >= e then go (e + 1, acc)
            else if at f = #"#" then (comment (i, f, e); go (e + 1, acc))
            else go (e + 1, entry (i, e) :: acc)
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

  (* what a dynamic module's boundary mentions, which is in no name of it *)
  fun boundaryNames (toks : Lexer.item vector, acc : names) : names =
    Vector.foldl (fn ((Token.DYNAMIC, _), acc) => StringMap.insert (acc, "RuneDynamic", ())
                   | ((Token.EXPORT, _), acc) => StringMap.insert (acc, "RuneDynamic", ())
                   | ((Token.VIRTUAL, _), acc) => StringMap.insert (acc, "RuneDynamic", ())
                   | (_, acc) => acc) acc toks

  (* What of RuneRuntime (lib/basis/runtime.sml) makes a program one that
     loads units (docs/units.md, Dynamic modules): the members that append a
     unit to it, and those that read what its file keeps for that, the units'
     identities *)
  val loading = ["load", "link", "linkedUnits", "linkedUnitSources"]
  val runtimeFile = "lib/basis/runtime.sml"
  val dynamicFile = "lib/basis/dynamic.sml"
  (* those members, as the functions of Runtime's file are named *)
  val loadingFunctions = List.map (fn n => "RuneRuntime." ^ n) loading

  (* Whether a file's tokens say that the program loads units: one of those
     members by name, or the primitives under them, by _prim: not the string
     alone, which a table of the primitives holds (the compiler's own). A name
     can get there without this, through an alias of the structure (Main,
     judged). *)
  fun namesLoading (toks : Lexer.item vector) : bool =
    let
      val n = Vector.length toks
      fun at i = #1 (Vector.sub (toks, i))
      fun member m = List.exists (fn l => l = m) loading
      fun says i =
        case at i of
          Token.LONGID ([s], m) => (s = "Runtime" orelse s = "RuneRuntime") andalso member m
        | Token.PRIM =>
            i + 1 < n andalso (case at (i + 1) of
                                 Token.STRING s => s = "rt_link" orelse s = "rt_linked_units"
                               | _ => false)
        | _ => false
      fun go i = i < n andalso (says i orelse go (i + 1))
    in go 0 end

  (* name -> the files that provide it, as paths, in MANIFEST order *)
  fun providers (entries : entry list) : string list StringMap.map =
    List.foldl (fn (e : entry, m) =>
                   List.foldl (fn (n, m) =>
                                  StringMap.insert (m, n, (case StringMap.find (m, n) of
                                                             SOME fs => fs @ [path e]
                                                           | NONE => [path e])))
                              m (#provides e))
               StringMap.empty entries

  (* ---- what each scope sees (docs/build.md, A library's header; D7, D8,
     D11) ----

     A scope is a program or a library with a header. It sees the Basis
     Library and its imports: what it names, and what those of them with no
     header are written on, since `libraries` is transitive only through a
     library that has not said otherwise. A library with no header sees all
     that comes before it, as it always has, and has no line of libraries. *)

  (* a library as a scope sees it: through these exports, NONE being all it
     declares, as a friend does or where it has no boundary *)
  type import = {dir : string, names : (string * string) list option}
  type scopes = {basis : string, scoped : bool, program : import list, libraries : (string * import list) list}

  fun noScopes (basis : string) : scopes =
    {basis = basis, scoped = false, program = [], libraries = []}

  fun importsOf (scopes : scopes, dir : string) : import list option =
    Option.map #2 (List.find (fn (d, _) => d = dir) (#libraries scopes))

  (* NAME or NAME#VIEW, which is how a library's name asks for one of its
     views *)
  fun splitView (name : string) : string * string option =
    case String.fields (fn c => c = #"#") name of
      [n] => (n, NONE)
    | [n, v] => (n, SOME v)
    | _ => raise Usage ("not the name of a library: " ^ name)

  (* whether build, a path, is the friend that a library in dir names *)
  fun isFriend (dir : string, friend : string, build : string) : bool =
    OS.FileSys.fullPath (OS.Path.concat (dir, friend)) = OS.FileSys.fullPath build
    handle OS.SysErr _ => false | OS.Path.Path => false

  (* whether a name of e is one that a scope importing as imports sees *)
  fun seen (imports : import list, e : entry, n : string) : bool =
    case List.find (fn {dir, ...} => dir = #dir e) imports of
      NONE => false
    | SOME {names = NONE, ...} => List.exists (fn p => p = n) (#provides e)
    | SOME {names = SOME es, ...} => List.exists (fn (_, exported) => exported = n) es

  (* The names of e that a program may name, of a scopes *)
  fun forProgram (scopes : scopes, e : entry) : string list =
    if not (#scoped scopes) orelse #dir e = #basis scopes then public e
    else List.filter (fn n => seen (#program scopes, e, n)) (#provides e)

  (* The entries to load for a program that mentions the given names, in
     MANIFEST order. *)
  fun select (scopes : scopes, entries : entry list, mentioned : names) : entry list =
    let
      (* The files that provide a name: a scan of the entries, compared with
         the primitive =, for the few names the chosen files require (a map of
         every name would cost more to build than a program needs). *)
      (* A seal file binds a structure again, as its signature shows it: that
         is for the program that mentions the structure. The files of the
         library that need it have it whole, from the file that declares it. *)
      fun provider (from : entry, e : entry, n) =
        if #dir from = #dir e then List.exists (fn p => p=n) (#provides e)
        else
          case (if #dir e = #basis scopes then NONE else importsOf (scopes, #dir from)) of
            NONE => List.exists (fn p => p=n) (public e)
          | SOME imports => seen (imports, e, n)
      fun providersOf (from : entry, n) =
        List.filter (fn e : entry => #when e <> Seal andalso provider (from, e, n)) entries
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
      val wanted = fn e : entry => #when e = Always orelse List.exists (fn n => StringMap.member (mentioned, n)) (forProgram (scopes, e))
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
     is an absolute host path or begins with ., when it is a path; after a
     # it may say which of the library's views is meant. *)

  fun isLibraryPath name = OS.Path.isAbsolute name orelse String.isPrefix "." name

  fun libraryDir (libDir : string, name : string) : string =
    let val name = #1 (splitView name)
    in if isLibraryPath name then name else libDir ^ "/" ^ name end

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

  (* The fixity a library's MANIFEST says it exports, on its # fixity: lines,
     for reading the files of a library that requires it *)
  fun fixities (dir : string) : (string * Fixity.fixity) list =
    let
      fun directives ("infix" :: p :: n :: rest) = (n, Fixity.Infix (valOf (Int.fromString p))) :: directives rest
        | directives ("infixr" :: p :: n :: rest) = (n, Fixity.Infixr (valOf (Int.fromString p))) :: directives rest
        | directives ("nonfix" :: n :: rest) = (n, Fixity.Nonfix) :: directives rest
        | directives _ = []
    in directives (headerWords (TextIO.openIn (dir ^ "/MANIFEST"), "# fixity:")) end
    handle IO.Io _ => []

  (* The functors a library's MANIFEST marks to be inlined across units, on
     its # inline: lines (its build file's `inline functor ... end`; M6b) *)
  fun inlineFunctors (dir : string) : string list =
    headerWords (TextIO.openIn (dir ^ "/MANIFEST"), "# inline:")
    handle IO.Io _ => []

  (* The values it marks to be inlined across units, on its # inline val:
     lines (`inline val ... end`; functors-units M10) *)
  fun inlineValues (dir : string) : string list =
    headerWords (TextIO.openIn (dir ^ "/MANIFEST"), "# inline val:")
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

  (* What each scope of a compile sees: its libraries, in the order they are
     compiled, with their entries, what the program names (names) and the
     build it is, whose friends it may be. With no header among them nothing
     is scoped, and a compile goes as it always has, unless what is being
     compiled has one itself (headed: the "program" is that library). *)
  fun scopes {root : string, building : string option, names : string list, headed : bool,
              libraries : (string * entry list) list} : scopes =
    let
      val basis = root ^ "/basis"
      fun entriesOf dir = case List.find (fn (d, _) => d = dir) libraries of SOME (_, es) => es | NONE => []
      fun headerOf dir = case entriesOf dir of e :: _ => #header e | [] => NONE
      val scoped = headed orelse List.exists (isSome o headerOf o #1) libraries
                   orelse List.exists (isSome o #2 o splitView) names
      (* what a client sees of a library it names *)
      fun through (client : string option) (name : string, dir : string, view : string option) =
        case (headerOf dir, view) of
          (NONE, NONE) => scopeOf (entriesOf dir)
        | (NONE, SOME _) => raise Usage ("a view needs a header, and the library " ^ #1 (splitView name) ^ " has none")
        | (SOME {friends, views}, _) =>
            let val friend = case client of
                  SOME build => List.exists (fn f => isFriend (dir, f, build)) friends
                | NONE => false
            in
              if friend then NONE
              else
                case view of
                  NONE => scopeOf (entriesOf dir)
                | SOME v =>
                    case List.find (fn (n, _) => n = v) views of
                      SOME (_, names) => SOME names
                    | NONE => raise Usage ("the library " ^ #1 (splitView name) ^ " has no view " ^ v)
            end
      fun add (imports : import list, dir, names) =
        case List.partition (fn {dir = d, ...} => d = dir) imports of
          ([], _) => imports @ [{dir = dir, names = names}]
        | ({names = old, ...} :: _, others) =>
            others @ [{dir = dir, names = case (old, names) of
                                            (SOME a, SOME b) => SOME (a @ b)
                                          | _ => NONE}]
      fun visit client (name : string, imports : import list) =
        let
          val dir = libraryDir (root, name)
          val imports = add (imports, dir, through client (name, dir, #2 (splitView name)))
        in
          if isSome (headerOf dir) then imports
          else List.foldl (fn (n, acc) =>
                             if List.exists (fn {dir = d, ...} => d = libraryDir (root, n)) acc then acc
                             else visit client (n, acc)) imports (libraryRequires dir)
        end
      fun imports client names = List.foldl (visit client) [] names
    in
      {basis = basis, scoped = scoped, program = if scoped then imports building names else [],
       libraries =
         if not scoped then []
         else
           List.mapPartial
             (fn (dir, _) => Option.map (fn _ => (dir, imports (SOME (dir ^ "/library.build")) (libraryRequires dir)))
                                        (headerOf dir))
             libraries}
    end

  (* What a scope imports twice: a name, the library it first has it from,
     and the one that shadows that; "" for the Basis Library. Two libraries
     with no header have always shadowed each other, and that stays so until
     they have headers. A name is compared without its kind: no name of this
     tree crosses kinds (D9), and a false warning is all that could come of
     one that did. *)
  fun clashes (imports : import list, entries : entry list, basis : string) : (string * string * string) list =
    let
      fun entriesOf dir = List.filter (fn e : entry => #dir e = dir) entries
      fun headed dir = case entriesOf dir of e :: _ => isSome (#header e) | [] => false
      val basisNames =
        List.foldl (fn (e : entry, m) => if #dir e = basis
                                         then List.foldl (fn (n, m) => StringMap.insert (m, n, ())) m (public e) else m)
                   StringMap.empty entries
      fun offered ({dir, names} : import) =
        case names of
          SOME es => List.mapPartial (fn (kind, n) => if kind = "fixity" then NONE else SOME n) es
        | NONE => List.concat (List.map #provides (entriesOf dir))
      (* in the order they are compiled, which is the order they shadow in *)
      val dirs = List.foldl (fn (e : entry, ds) => if List.exists (fn d => d = #dir e) ds then ds else ds @ [#dir e]) [] entries
      val ordered = List.mapPartial (fn d => List.find (fn {dir, ...} => dir = d) imports) dirs
      fun visit (import as {dir, ...} : import, (seen, found)) =
        List.foldl (fn (n, (seen, found)) =>
                       case StringMap.find (seen, n) of
                         SOME other =>
                           if other = dir orelse not (headed other orelse headed dir) then (seen, found)
                           else (StringMap.insert (seen, n, dir), (n, other, dir) :: found)
                       | NONE =>
                           (StringMap.insert (seen, n, dir),
                            if headed dir andalso StringMap.member (basisNames, n) then (n, "", dir) :: found else found))
                   (seen, found) (offered import)
    in List.rev (#2 (List.foldl visit (StringMap.empty, []) ordered)) end
end
