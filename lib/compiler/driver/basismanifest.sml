(* The index of a library -- the basis library, or one of the libraries
   beside it (docs/plans/quickcheck.md, D1) -- and the choice of the files a
   program loads: shared by the compiler driver and runedoc. An index is
   derived from the library's build file and its files, and kept in the
   store, never in the tree (LibraryIndex; the build-system roadmap's D13).
   This takes one as a value, and reads no file. *)
structure BasisManifest =
struct
  exception Usage of string

  (* ---- a library's index ----
     A line per file, in load order:
       file, always or demand (or seal, final), host, provides, requires
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
     mentions one, never because a file of the library requires the name.
     A seal of a view of the library is seal@VIEW, loaded for a program in
     that view, after the libraries (D12). *)
  datatype when = Always | Demand | Seal | Final
  (* What a library's header says beside its exports, which are scope, and
     what it requires, which are its libraries; a library with none
     has NONE, whose files see all before them and whose `libraries` are
     transitive (docs/build.md, A library's header; D7, D15). virtuals are
     the virtual modules it declares and implements those of a library it
     requires that it implements, KIND and NAME each (D22; docs/build.md,
     Virtual libraries). *)
  type header = {friends : string list, views : (string * (string * string) list) list,
                 virtuals : (string * string) list, implements : (string * string) list}
  (* requires is what the file needs of the others, as a function, which
     most programs ask of few files. dir is the directory of the library the file is in.
     view is the view of the Basis Library a seal belongs to, a seal@VIEW
     line, which only a program in that view loads (D12). *)
  type entry = {dir : string, file : string, when : when, provides : string list,
                requires : unit -> string list, scope : (string * string) list option,
                header : header option, view : string option}

  (* An index: the libraries it is written on, each an import's word; its
     export boundary, its header's or a library (...) block's, NONE where it
     has neither and keeps the historical visibility; its header; the fixity
     it exports; the functors and functions its build marks to inline; and
     a line for each file, a file of host=only among them, which the other
     SML systems have alone and Rune does not compile *)
  type line = {file : string, class : string, host : string, provides : string list, requires : unit -> string list}
  type index = {libraries : string list, scope : (string * string) list option, header : header option,
                fixities : (string * Fixity.fixity) list, inline : string list, inlineValues : string list,
                lines : line list}

  (* A library's export boundary *)
  fun public (e : entry) =
    case #scope e of NONE => #provides e
    | SOME es => List.filter (fn n => List.exists (fn (_, exported) => exported = n) es) (#provides e)

  fun scopeOf (es : entry list) =
    case es of [] => NONE | e :: rest =>
      if List.all (fn other : entry => #scope other = #scope e) rest then #scope e
      else raise Usage ("inconsistent export boundary in the index of " ^ #dir e)

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

  (* The entries of the index of the library in dir, but for its files of
     host=only *)
  fun entriesOf (dir : string, {scope, header, lines, ...} : index) : entry list =
    List.mapPartial
      (fn {file, class, host, provides, requires} =>
         if host = "only" then NONE
         else
           let val view = if String.isPrefix "seal@" class andalso size class > 5 then SOME (String.extract (class, 5, NONE)) else NONE
           in
             SOME {dir = dir, file = file,
                   when = (case class of "always" => Always | "demand" => Demand | "seal" => Seal | "final" => Final
                                       | _ => if isSome view then Seal else raise Usage ("a file of no class in the index of " ^ dir ^ ": " ^ file)),
                   provides = provides, requires = requires, scope = scope,
                   header = header, view = view}
           end)
      lines

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
  val runtimeFile = "basis:runtime.sml"
  val dynamicFile = "basis:dynamic.sml"
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

  (* name -> the files that provide it, as paths, in the index's order *)
  fun providers (entries : entry list) : string list StringMap.map =
    List.foldl (fn (e : entry, m) =>
                   List.foldl (fn (n, m) =>
                                  StringMap.insert (m, n, (case StringMap.find (m, n) of
                                                             SOME fs => fs @ [path e]
                                                           | NONE => [path e])))
                              m (#provides e))
               StringMap.empty entries

  (* ---- what each scope sees (docs/build.md, A library's header; D7, D8,
     D9, D11) ----

     A scope is a program or a library with a header. It sees the Basis
     Library and its imports: what it names, and what those of them with no
     header are written on, since `libraries` is transitive only through a
     library that has not said otherwise. A library with no header sees all
     that comes before it, as it always has, and has no line of libraries. *)

  (* A name an import renames, of a kind, to another (D9): only a module or a
     type is renamed, since a value would lose its status as a constructor *)
  type rename = {kind : string, from : string, to : string}
  val renameKinds = ["structure", "signature", "functor", "type"]

  (* a library as a scope sees it: through these exports, NONE being all it
     declares, as a friend does or where it has no boundary, and with what it
     renames *)
  type import = {dir : string, names : (string * string) list option, renames : rename list}
  (* view is the program's view of the Basis Library, whose seals are loaded
     after the libraries (D12) *)
  type scopes = {basis : string, scoped : bool, program : import list, libraries : (string * import list) list,
                 view : string option}

  fun noScopes (basis : string) : scopes =
    {basis = basis, scoped = false, program = [], libraries = [], view = NONE}

  fun importsOf (scopes : scopes, dir : string) : import list option =
    Option.map #2 (List.find (fn (d, _) => d = dir) (#libraries scopes))

  (* How a scope names a library (docs/build.md, Clashes): NAME, NAME#VIEW for
     one of its views, and either with what it renames, which a build file
     writes NAME (KIND FROM as TO, ...) and which is kept in one word, NAME(
     KIND:FROM=TO,...) with no space: in a list of libraries, in an index's
     libraries and in a plan. *)
  fun identifier (s : string) : bool =
    size s > 0 andalso Char.isAlpha (String.sub (s, 0))
    andalso CharVector.all (fn c => Char.isAlphaNum c orelse c = #"_" orelse c = #"'") s
  fun importWord {name : string, view : string option, renames : rename list} : string =
    name ^ (case view of NONE => "" | SOME v => "#" ^ v) ^
    (case renames of
       [] => ""
     | rs => "(" ^ String.concatWith "," (List.map (fn {kind, from, to} => kind ^ ":" ^ from ^ "=" ^ to) rs) ^ ")")
  fun importOf (word : string) : {name : string, view : string option, renames : rename list} =
    let
      fun bad () = raise Usage ("not the name of a library: " ^ word)
      val n = size word
      fun opening i = if i >= n then NONE else if String.sub (word, i) = #"(" then SOME i else opening (i + 1)
      fun rename item =
        case String.fields (fn c => c = #":" orelse c = #"=") item of
          [kind, from, to] =>
            if List.exists (fn k => k = kind) renameKinds andalso identifier from andalso identifier to
            then {kind = kind, from = from, to = to} else bad ()
        | _ => bad ()
      val (head, renames) =
        case opening 0 of
          NONE => (word, [])
        | SOME i =>
            if n < i + 2 orelse String.sub (word, n - 1) <> #")" then bad ()
            else (String.substring (word, 0, i),
                  List.map rename (String.fields (fn c => c = #",") (String.substring (word, i + 1, n - i - 2))))
    in
      case String.fields (fn c => c = #"#") head of
        [name] => {name = name, view = NONE, renames = renames}
      | [name, v] => {name = name, view = SOME v, renames = renames}
      | _ => bad ()
    end
  (* NAME, and the view NAME#VIEW asks for *)
  fun splitView (word : string) : string * string option =
    let val {name, view, ...} = importOf word in (name, view) end
  (* a rename as a build file writes it *)
  fun renameText ({kind, from, to} : rename) : string = kind ^ " " ^ from ^ " as " ^ to

  (* whether build, a path, is the friend that a library in dir names *)
  fun isFriend (dir : string, friend : string, build : string) : bool =
    OS.FileSys.fullPath (OS.Path.concat (dir, friend)) = OS.FileSys.fullPath build
    handle OS.SysErr _ => false | OS.Path.Path => false

  (* a name of an import as the scope sees it *)
  fun renamed (renames : rename list) (n : string) : string =
    case List.find (fn {from, ...} => from = n) renames of SOME {to, ...} => to | NONE => n

  (* whether a name of e is one that a scope importing as imports sees, n
     being the scope's name for it. A name here has no kind and a rename has,
     so a name renamed away counts as well as its new name: a selection may
     load a file a scope does not need, and never misses one it does. *)
  fun seen (imports : import list, e : entry, n : string) : bool =
    case List.find (fn {dir, ...} => dir = #dir e) imports of
      NONE => false
    | SOME {names, renames, ...} =>
        List.exists (fn p => (p = n orelse renamed renames p = n)
                             andalso (case names of NONE => true | SOME es => List.exists (fn (_, x) => x = p) es))
                    (#provides e)

  (* The names of e that a scope importing as imports may name, as it names
     them, a name renamed away among them as seen counts it *)
  fun seenNames (imports : import list, e : entry) : string list =
    case List.find (fn {dir, ...} => dir = #dir e) imports of
      NONE => []
    | SOME {names, renames, ...} =>
        List.concat (List.map (fn p =>
                                 if (case names of NONE => true | SOME es => List.exists (fn (_, x) => x = p) es)
                                 then (case renamed renames p of q => if q = p then [p] else [p, q])
                                 else [])
                              (#provides e))

  (* The names of e that a program may name, of a scopes, as it names them *)
  fun forProgram (scopes : scopes, e : entry) : string list =
    if not (#scoped scopes) orelse #dir e = #basis scopes then public e
    else seenNames (#program scopes, e)

  (* The entries a compile in scopes chooses among: those of no view and
     those of its view, which come after the libraries, the libraries having
     been compiled with the Basis Library whole (D12) *)
  fun inView (scopes : scopes, entries : entry list) : entry list =
    case (#view scopes, List.exists (isSome o #view) entries) of
      (NONE, false) => entries   (* every compile, until the Basis Library has a view: nothing made *)
    | (NONE, true) => List.filter (not o isSome o #view) entries
    | (SOME v, _) =>
        let
          val (viewed, plain) = List.partition (isSome o #view) entries
          val mine = List.filter (fn e : entry => #view e = SOME v) viewed
        in if List.null mine then raise Usage ("the Basis Library has no view " ^ v) else plain @ mine end

  (* The virtual modules a library's header declares, and those it
     implements, as an entry of it says (D22) *)
  fun virtualsOf (e : entry) = case #header e of SOME {virtuals, ...} => virtuals | NONE => []
  fun implementsOf (e : entry) = case #header e of SOME {implements, ...} => implements | NONE => []

  (* The entries to load for a program that mentions the given names, in
     the index's order, but for its view's seals, which come last. *)
  fun select (scopes : scopes, entries : entry list, mentioned : names) : entry list =
    let
      val entries = inView (scopes, entries)
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
      (* A file that declares a virtual module brings the files that
         implement it, in a library that says so (D22): they are what the
         declaration takes, and are named by nothing else. Both have headers,
         so a compile with none scoped has none of either *)
      val implementing = if #scoped scopes then List.filter (fn e : entry => not (List.null (implementsOf e))) entries else []
      fun implementationsOf (e : entry) : entry list =
        case List.filter (fn (_, n) => List.exists (fn p => p = n) (#provides e)) (virtualsOf e) of
          [] => []
        | here => List.filter (fn i : entry => List.exists (fn m as (_, n) => List.exists (fn h => h = m) here
                                                                              andalso List.exists (fn p => p = n) (#provides i))
                                                           (implementsOf i))
                              implementing
      fun add (e : entry, chosen : names) : names =
        if StringMap.member (chosen, path e) then chosen
        else case implementing of
               [] => required' (e, chosen)
             | _ => List.foldl add (required' (e, chosen)) (implementationsOf e)
      and required' (e : entry, chosen : names) : names =
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
     A library is a directory with a library.build, whose index is in the
     form above. The libraries it is written on besides the basis library are
     what its build file requires, and are loaded before it. A NAME is a
     directory under the directory of the libraries (--lib), test/property
     for LIBDIR/test/property, or where that has none, under one of those a
     workspace names (roots), unless it is an absolute host path or begins
     with ., when it is a path; after a # it may say which of the library's
     views is meant. *)

  fun isLibraryPath name = OS.Path.isAbsolute name orelse String.isPrefix "." name

  (* the directories of libraries the workspace names (Workspace), in order *)
  val roots : string list ref = ref []
  val () = CompilerState.cellRoot ("BasisManifest.roots", roots)

  fun libraryDir (libDir : string, name : string) : string =
    let val name = #1 (splitView name)
    in
      if isLibraryPath name then name
      else
        let
          val first = libDir ^ "/" ^ name
          fun holds dir = Source.probe (dir ^ "/library.build")
          (* a root that is the directory a compile runs in is "" from here *)
          fun under root = if root = "" then name else root ^ "/" ^ name
        in
          if List.null (!roots) orelse holds first then first
          else getOpt (List.find holds (List.map under (!roots)), first)
        end
    end

  (* The directories of the named libraries and of those they are written on,
     each once, every library after the ones it names; requires says what a
     library in a directory names. A virtual library's implementations among
     them come right after it, each after what it is written on that is not
     before (D22): they run before the virtual library's files from the first
     that declares a virtual module on (arrange). virtuals and implements say
     what a library declares virtual and implements. *)
  fun librariesWith {requires : string -> string list, virtuals : string -> (string * string) list,
                     implements : string -> (string * string) list} (libDir : string, names : string list) : string list =
    let
      fun order (implementers : string -> string list) : string list =
        let
          fun visit stack (name : string, done : string list) : string list =
            visitDir stack (name, libraryDir (libDir, name), done)
          and visitDir (stack : string list) (name : string, dir : string, done : string list) : string list =
            if List.exists (fn d => d = dir) done then done
            else if List.exists (fn d => d = dir) stack
            then raise Usage ("library " ^ name ^ " is written on itself (" ^ String.concatWith " <- " (dir :: stack) ^ ")")
            else
              let
                val done = List.foldl (visit (dir :: stack)) done (requires dir) @ [dir]
                (* one being visited comes when what it requires has: this
                   library, and the rest of what it requires *)
                val waiting = List.filter (fn i => not (List.exists (fn d => d = i) stack)) (implementers dir)
              in List.foldl (fn (i, done) => visitDir (dir :: stack) (i, i, done)) done waiting end
        in List.foldl (visit []) [] names end
      val closure = order (fn _ => [])
      fun implementersOf dir =
        case virtuals dir of
          [] => []
        | vs => List.filter (fn d => d <> dir andalso List.exists (fn m => List.exists (fn v => v = m) vs) (implements d)) closure
    in
      if List.all (List.null o implements) closure then closure else order implementersOf
    end
  fun librariesBy (requires : string -> string list) =
    librariesWith {requires = requires, virtuals = fn _ => [], implements = fn _ => []}
  (* The entries of libraries, given in the order they are compiled, in the
     order a compile takes them: a virtual library's files from the first that
     declares a virtual module on come after the last library that implements
     one of its modules, whose files run before them (D22; docs/build.md,
     Virtual libraries) *)
  fun virtualTail (virtuals : (string * string) list, es : entry list) : entry list * entry list =
    let
      fun here (e : entry) = #when e <> Final andalso List.exists (fn (_, n) => List.exists (fn p => p = n) (#provides e)) virtuals
      fun go (head, []) = (List.rev head, [])
        | go (head, e :: rest) = if here e then (List.rev head, e :: rest) else go (e :: head, rest)
    in go ([], es) end
  fun arrange ([] : (string * entry list) list) : entry list = []
    | arrange libraries =
    let
      fun headerOf (es : entry list) = case es of e :: _ => #header e | [] => NONE
      fun virtualsIn es = case headerOf es of SOME {virtuals, ...} => virtuals | NONE => []
      fun implementsIn es = case headerOf es of SOME {implements, ...} => implements | NONE => []
      fun lastImplementer vs =
        List.foldl (fn ((dir, es), found) => if List.exists (fn m => List.exists (fn v => v = m) vs) (implementsIn es)
                                             then SOME dir else found) NONE libraries
      val moved =
        if List.all (List.null o virtualsIn o #2) libraries then []
        else
        List.mapPartial (fn (dir, es) =>
                           case virtualsIn es of
                             [] => NONE
                           | vs => Option.map (fn last => (dir, last, virtualTail (vs, es))) (lastImplementer vs))
                        libraries
      fun entriesOf (dir, es) =
        (case List.find (fn (d, _, _) => d = dir) moved of SOME (_, _, (head, _)) => head | NONE => es)
        @ List.concat (List.map (fn (_, _, (_, tail)) => tail) (List.filter (fn (_, last, _) => last = dir) moved))
    in
      case moved of
        [] => List.concat (List.map #2 libraries)   (* no virtual library implemented: nothing made *)
      | _ => List.concat (List.map entriesOf libraries)
    end

  (* The virtual modules of a compile's libraries, KIND, NAME and the
     directory of the library that declares each; refused, two libraries that
     declare one, and two that implement one: a program has one
     implementation of each (D22) *)
  fun virtualModules ([] : (string * entry list) list) : (string * string * string) list = []
    | virtualModules libraries =
    let
      fun headerOf (es : entry list) = case es of e :: _ => #header e | [] => NONE
      fun described (kind, name) = "the virtual " ^ (if kind = "functor" then "functor " else "module ") ^ name
      fun twice what (found : (string * string * string) list) =
        List.foldl (fn (m as (kind, name, dir), seen) =>
                      case List.find (fn (k, n, _) => k = kind andalso n = name) seen of
                        SOME (_, _, other) => raise Usage ("the program has " ^ what ^ " of " ^ described (kind, name) ^ ": the libraries "
                                                           ^ other ^ " and " ^ dir ^ " (docs/build.md, Virtual libraries)")
                      | NONE => m :: seen) [] found
      fun each select = List.concat (List.map (fn (dir, es) =>
                          case headerOf es of SOME h => List.map (fn (k, n) => (k, n, dir)) (select h) | NONE => []) libraries)
      val declared = each #virtuals
      val _ = twice "two declarations" declared
      val _ = twice "two implementations" (each #implements)
    in declared end

  (* What each scope of a compile sees: its libraries, in the order they are
     compiled, with their entries, what the program names (names) and the
     build it is, whose friends it may be, and its view of the Basis Library.
     With no header among them, no view of one and no rename, nothing is
     scoped, and a compile goes as it always has, unless what is being
     compiled has one itself (headed: the "program" is that library). *)
  fun scopes {root : string, building : string option, names : string list, headed : bool,
              libraries : (string * entry list) list, view : string option, requires : string -> string list} : scopes =
    let
      val basis = root ^ "/basis"
      fun entriesOf dir = case List.find (fn (d, _) => d = dir) libraries of SOME (_, es) => es | NONE => []
      fun headerOf dir = case entriesOf dir of e :: _ => #header e | [] => NONE
      val scoped = headed orelse List.exists (isSome o headerOf o #1) libraries
                   orelse List.exists (fn n => let val i = importOf n in isSome (#view i) orelse not (List.null (#renames i)) end)
                                      names
      (* what a client sees of a library it names *)
      fun through (client : string option) (name : string, dir : string, view : string option) =
        case (headerOf dir, view) of
          (NONE, NONE) => scopeOf (entriesOf dir)
        | (NONE, SOME _) => raise Usage ("a view needs a header, and the library " ^ #1 (splitView name) ^ " has none")
        | (SOME {friends, views, ...}, _) =>
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
      (* A rename is of a name the import offers, of that kind where the
         library says (its exports), each name once, and to a name it does not
         offer already *)
      fun checkRenames (name : string, dir : string, names, renames : rename list) =
        let
          val shown = #1 (splitView name)
          val offered = case names of
                          SOME es => es
                        | NONE => List.concat (List.map (fn e : entry => List.map (fn n => ("", n)) (#provides e)) (entriesOf dir))
          fun has ({kind, from, ...} : rename) = List.exists (fn (k, n) => n = from andalso (k = "" orelse k = kind)) offered
          fun twice xs = case xs of [] => NONE | x :: rest => if List.exists (fn y => y = x) rest then SOME x else twice rest
          fun refuse why = raise Usage ("the import of the library " ^ shown ^ " " ^ why ^ " (docs/build.md, Clashes)")
        in
          List.app (fn r => if has r then ()
                            else refuse ("renames " ^ #kind r ^ " " ^ #from r ^ ", which it does not "
                                         ^ (if isSome names then "export" else "declare"))) renames;
          Option.app (fn n => refuse ("renames " ^ n ^ " twice")) (twice (List.map (fn {kind, from, ...} => kind ^ " " ^ from) renames));
          Option.app (fn n => refuse ("renames two names to " ^ n)) (twice (List.map #to renames));
          List.app (fn {from, to, ...} =>
                      if List.exists (fn (_, n) => n = to andalso not (List.exists (fn r => #from r = n) renames)) offered
                      then refuse ("renames " ^ from ^ " to " ^ to ^ ", which it has already") else ()) renames
        end
      fun add (imports : import list, name, dir, names, renames : rename list) =
        case List.partition (fn {dir = d, ...} => d = dir) imports of
          ([], _) => imports @ [{dir = dir, names = names, renames = renames}]
        | ({names = old, renames = earlier, ...} :: _, others) =>
            if earlier <> renames
            then raise Usage ("the library " ^ #1 (splitView name) ^ " is imported twice in one scope, renamed otherwise"
                              ^ " (docs/build.md, Clashes)")
            else others @ [{dir = dir, names = case (old, names) of
                                                 (SOME a, SOME b) => SOME (a @ b)
                                               | _ => NONE,
                            renames = renames}]
      (* what a scope names itself, with what it renames, and then what
         those with no header are written on, which it has as they are where
         it does not name them itself *)
      fun named client (name : string, imports : import list) =
        let
          val {view, renames, ...} = importOf name
          val dir = libraryDir (root, name)
          val names = through client (name, dir, view)
          val () = if List.null renames then () else checkRenames (name, dir, names, renames)
        in add (imports, name, dir, names, renames) end
      fun transitive client (name : string, imports : import list) =
        let val dir = libraryDir (root, name)
        in
          if isSome (headerOf dir) then imports
          else List.foldl (fn (n, acc) =>
                             if List.exists (fn {dir = d, ...} => d = libraryDir (root, n)) acc then acc
                             else transitive client (n, named client (n, acc))) imports (requires dir)
        end
      fun imports client names = List.foldl (transitive client) (List.foldl (named client) [] names) names
    in
      {basis = basis, scoped = scoped, program = if scoped then imports building names else [],
       libraries =
         if not scoped then []
         else
           List.mapPartial
             (fn (dir, _) => Option.map (fn _ => (dir, imports (SOME (dir ^ "/library.build")) (requires dir)))
                                        (headerOf dir))
             libraries,
       view = view}
    end

  (* What a scope imports twice: a name, the library it first has it from,
     and the one that shadows that; "" for the Basis Library. Each is an
     error (D9), which a rename at import answers. Two libraries with no
     header have always shadowed each other, and that stays so until they
     have headers, unless a rename gives the name. A library with a header,
     or a rename, that gives a name of the Basis Library clashes with it
     like any other. A name is compared without its kind: no name of this
     tree crosses kinds (D9), and a false error is all that could come of
     one that did, which a rename answers too. *)
  fun clashes (imports : import list, entries : entry list, basis : string) : (string * string * string) list =
    let
      fun entriesOf dir = List.filter (fn e : entry => #dir e = dir) entries
      fun headerOf dir = case entriesOf dir of e :: _ => #header e | [] => NONE
      fun headed dir = isSome (headerOf dir)
      val basisNames =
        List.foldl (fn (e : entry, m) => if #dir e = basis andalso not (isSome (#view e))
                                         then List.foldl (fn (n, m) => StringMap.insert (m, n, ())) m (public e) else m)
                   StringMap.empty entries
      (* each name as the scope sees it, and whether a rename gave it *)
      fun offered ({dir, names, renames} : import) =
        List.map (fn n => let val shown = renamed renames n in (shown, shown <> n) end)
                 (case names of
                    SOME es => List.mapPartial (fn (kind, n) => if kind = "fixity" then NONE else SOME n) es
                  | NONE => List.concat (List.map #provides (entriesOf dir)))
      (* in the order they are compiled, which is the order they shadow in *)
      val dirs = List.foldl (fn (e : entry, ds) => if List.exists (fn d => d = #dir e) ds then ds else ds @ [#dir e]) [] entries
      val ordered = List.mapPartial (fn d => List.find (fn {dir, ...} => dir = d) imports) dirs
      fun visit (import as {dir, ...} : import, (seen, found)) =
        List.foldl (fn ((n, byRename), (seen, found)) =>
                       case StringMap.find (seen, n) of
                         SOME (other, earlierByRename) =>
                           if other = dir orelse not (headed other orelse headed dir orelse byRename orelse earlierByRename)
                           then (seen, found)
                           else (StringMap.insert (seen, n, (dir, byRename)), (n, other, dir) :: found)
                       | NONE =>
                           (StringMap.insert (seen, n, (dir, byRename)),
                            if (headed dir orelse byRename) andalso StringMap.member (basisNames, n)
                            then (n, "", dir) :: found else found))
                   (seen, found) (offered import)
    in List.rev (#2 (List.foldl visit (StringMap.empty, []) ordered)) end
end
