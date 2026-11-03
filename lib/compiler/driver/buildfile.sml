(* Build files (docs/build.md; the incremental roadmap's M10, D16): their
   syntax, read into declarations, which CompilerProject makes the plan of
   what a build compiles -- each unit with the basis it is compiled in, a
   unit's basis being what the steps before it leave. A basis is a value, as
   in MLB: a file adds what it declares to the basis before it, and a
   library's exports say what the files after it see. Unlike MLB, a `use`
   elaborates in its caller's basis. *)
structure BuildFile =
struct
  (* ---- syntax ---- *)

  (* what a library may export; Fix is a name's fixity, which a boundary lets
     through only where it is named (docs/build.md, A library's header) *)
  datatype kind = Str | Sig | Fun | Ty | Fix
  (* a library's header, but for its exports: the Library after it. A name
     it requires is an import's word, with what is renamed (BasisManifest);
     shadows are the names of the Basis Library its exports take the place of
     (docs/build.md, Clashes); strict holds its units to being well-formed.
     virtuals are the virtual modules it declares, and implements those of a
     library it requires that it implements, each a structure or a functor
     (docs/build.md, Virtual libraries; D22) *)
  type header = {requires : string list, friends : string list, views : (string * (kind * string) list) list,
                 shadows : (kind * string) list, strict : bool, virtuals : (kind * string) list,
                 implements : (kind * string) list}
  datatype dec =
      File of string                              (* a path, relative to the build file's directory *)
    | Files of string list
    | Library of (kind * string) list * dec list
    | Use of string
    | Implements of string * dec list
    | Annotate of string list * dec list
    | Libraries of string list                   (* the libraries a library is written on, each an import's word *)
    | Header of header                           (* what comes first in a library's build file *)
    | Inline of string list                      (* functors to inline across units (M6b) *)
    | InlineVal of string list                   (* functions to inline across units (functors-units M10) *)
    | View of string                             (* the program's view of the Basis Library (D12) *)
    (* a declared step, which a build runs before it reads a source, and
       the class of a per-file preprocessor, which a file is put in by the
       annotation preprocess=NAME (docs/build.md, Generated sources; D16) *)
    | Generate of {tool : string, arguments : string list, inputs : string list, outputs : string list}
    | Preprocessor of {name : string, tool : string, arguments : string list, inputs : string list}

  exception Error of string
  exception LocatedError of Source.span * string

  (* the words of a build file: comments dropped, strings kept whole *)
  datatype word = W of string | S of string
  type lexeme={word:word,start:int,stop:int}
  fun lexemes (path : string, text : string, recover : bool) : lexeme list =
    let
      val n = String.size text
      fun at i = if i < n then String.sub (text, i) else #"\000"
      fun error (start,stop,message)=raise LocatedError ({file=path,start=start,stop=stop},message)
      fun pathChar c = Char.isAlphaNum c orelse Char.contains "/._-+~#" c
      (* a path: its characters, and $(NAME) whole *)
      fun scan j =
        if j < n andalso (pathChar (at j) orelse recover andalso Char.ord (at j)>=128) then scan (j + 1)
        else if j < n andalso at j = #"$" andalso at (j + 1) = #"(" then
          let fun close k = if k >= n then if recover then n else error (j,n,"a path variable that does not end")
                            else if at k = #")" then k else close (k + 1)
              val stop=close (j+2)
          in if stop=n then n else scan (stop+1) end
        else j
      fun go (i, depth, acc) =
        if i >= n then (if depth > 0 andalso not recover then error (n,n,"a comment that does not end") else List.rev acc)
        else if at i = #"(" andalso at (i + 1) = #"*" then go (i + 2, depth + 1, acc)
        else if depth > 0 then (if at i = #"*" andalso at (i + 1) = #")" then go (i + 2, depth - 1, acc) else go (i + 1, depth, acc))
        else if Char.isSpace (at i) then go (i + 1, 0, acc)
        else if at i = #"\"" then
          let fun close j = if j >= n then if recover then n else error (i,n,"a string that does not end")
                            else if at j = #"\"" then j else close (j + 1)
              val j = close (i + 1)
              val stop=if j=n then n else j+1
          in go (stop,0,{word=S (String.substring (text,i+1,j-i-1)),start=i,stop=stop} :: acc) end
        else if Char.contains ",=()" (at i) then go (i+1,0,{word=W (String.str (at i)),start=i,stop=i+1} :: acc)
        else if pathChar (at i) orelse at i = #"$" orelse recover andalso Char.ord (at i)>=128 then
          let val j=scan i
          in if j=i then if recover then go (i+1,0,{word=W (String.str (at i)),start=i,stop=i+1} :: acc)
                         else error (i,i+1,"unexpected '" ^ String.str (at i) ^ "'")
             else go (j,0,{word=W (String.substring (text,i,j-i)),start=i,stop=j} :: acc) end
        else if recover then go (i+1,0,{word=W (String.str (at i)),start=i,stop=i+1} :: acc)
        else error (i,i+1,"unexpected '" ^ String.str (at i) ^ "'")
    in go (0, 0, []) end
  fun words (path,text)=List.map #word (lexemes (path,text,false))
    handle LocatedError (_,message) => raise Error (path ^ ": " ^ message)

  (* The words that begin a construct, which no path may be. A step's own
     words, inputs and outputs, are known only where a step reads them, so
     that a file or a library may still be called outputs *)
  val keywords = ["files", "group", "local", "in", "end", "library", "use", "implements", "annotate", "cache",
                  "libraries", "inline", "requires", "exports", "friends", "view", "shadows", "strict", "virtual",
                  "generate", "preprocessor"]

  (* the words that were the language's and are not now, which no path may
     be: what to write instead (docs/build.md, What is gone; D6) *)
  fun dropped (word : string) : string option =
    case word of
      "group" => SOME "a build lists its files in the order they are compiled"
    | "local" => SOME "what a build hides stands behind a library's exports"
    | "cache" => SOME "--cache-dir says where the cache is"
    | _ => NONE

  (* the words `annotate` takes (docs/build.md, Annotations, and A library's
     build file); view=NAME marks the seals of a view of the Basis Library,
     and preprocess=NAME puts a file in the class of a preprocessor *)
  fun knownAnnotation (a : string) : bool =
    List.exists (fn k => k = a) ["allowPrim", "noWarnings", "always", "demand", "seal", "final", "host=swap", "host=no", "host=only", "prelude"]
    orelse isSome (Source.modeNamed a)
    orelse (String.isPrefix "view=" a andalso BasisManifest.identifier (String.extract (a, 5, NONE)))
    orelse (String.isPrefix "preprocess=" a andalso BasisManifest.identifier (String.extract (a, 11, NONE)))
  (* the preprocessor a unit's annotations put it in: the last they name *)
  fun preprocessorOf (annotations : string list) : string option =
    List.foldl (fn (a, found) => if String.isPrefix "preprocess=" a then SOME (String.extract (a, 11, NONE)) else found)
               NONE annotations

  fun parseUsing {path,text,recover,pathAt,wanted} : dec list =
    let
      val ws = ref (lexemes (path,text,recover))
      val last=ref {file=path,start=0,stop=0}:Source.span ref
      fun peek () = case !ws of w :: _ => SOME (#word w) | [] => NONE
      fun next () = case !ws of w :: rest =>
            (ws:=rest;last:={file=path,start= #start w,stop= #stop w};#word w)
        | [] => raise LocatedError ({file=path,start=size text,stop=size text},"unexpected end of the file")
      fun error message=raise LocatedError (!last,message)
      fun expect s = case next () of W s' => if s' = s then () else error ("expected " ^ s ^ ", found " ^ s')
                                   | S s' => error ("expected " ^ s ^ ", found \"" ^ s' ^ "\"")
      fun want role=wanted (role,{file=path,start= #stop (!last),stop=case !ws of [] => size text | w::_ => #start w})
      fun reference (role,word)=
        (pathAt (role,word,!last);case word of W s => s | S s => s)
      fun pathWord role =
        (want role;case next () of word as W s =>
           if List.exists (fn k => k=s) keywords then error ("expected a path, found " ^ s) else reference (role,word)
         | word as S _ => reference (role,word))
      fun paths role = case peek () of
                       SOME (W "end") => (ignore (next ()); [])
                     | SOME _ => let val p = pathWord role in p :: paths role end
                     | NONE => (want role;raise LocatedError
                         ({file=path,start=size text,stop=size text},"a list of files that does not end"))
      (* A list of libraries, each with what its import renames: NAME (KIND
         FROM as TO, ...), kept as one word (BasisManifest.importWord) *)
      fun libraryList () =
        case peek () of
          SOME (W "end") => (ignore (next ()); [])
        | SOME _ =>
            let
              val name = pathWord "library"
              fun rename () =
                let
                  val kind = case next () of
                               W k => if List.exists (fn x => x = k) BasisManifest.renameKinds then k
                                      else error "a rename is of a structure, signature, functor or type: KIND NAME as NAME"
                             | S _ => error "a rename is of a structure, signature, functor or type: KIND NAME as NAME"
                  fun ident what = case next () of
                                     W n => if BasisManifest.identifier n then n else error ("expected " ^ what ^ ", found " ^ n)
                                   | S n => error ("expected " ^ what ^ ", found \"" ^ n ^ "\"")
                  val from = ident "the name renamed"
                  val () = expect "as"
                  val to = ident "a name"
                  val r = {kind = kind, from = from, to = to}
                in
                  case next () of
                    W "," => r :: rename ()
                  | W ")" => [r]
                  | _ => error "expected , or ) in the renames"
                end
              val renames = case peek () of SOME (W "(") => (ignore (next ()); rename ()) | _ => []
              val {name = library, view, ...} = BasisManifest.importOf name handle BasisManifest.Usage m => error m
            in BasisManifest.importWord {name = library, view = view, renames = renames} :: libraryList () end
        | NONE => (want "library";raise LocatedError
            ({file=path,start=size text,stop=size text},"a list of libraries that does not end"))
      fun exportList () =
        let
          fun export () =
            let
              val k = case next () of
                        W "structure" => Str | W "signature" => Sig | W "functor" => Fun | W "type" => Ty
                      | W "fixity" => Fix
                      | _ => error "an export is structure, signature, functor, type or fixity NAME"
              val n = case next () of W n => n | S n => n
            in
              case next () of
                W "," => (k, n) :: export ()
              | W ")" => [(k, n)]
              | _ => error "expected , or ) in the exports"
            end
        in expect "("; export () end
      (* a step's arguments, as its tool is given them: ( ARG, ... ) *)
      fun argumentList () =
        case peek () of
          SOME (W "(") =>
            let
              val () = ignore (next ())
              fun argument () =
                let
                  val a = case next () of
                            W "," => error "expected an argument, found ,"
                          | W ")" => error "expected an argument, found )"
                          | W a => a
                          | S a => a
                in
                  case next () of
                    W "," => a :: argument ()
                  | W ")" => [a]
                  | _ => error "expected , or ) in the arguments"
                end
            in case peek () of SOME (W ")") => (ignore (next ()); []) | _ => argument () end
        | _ => []
      fun inputList () = case peek () of SOME (W "inputs") => (ignore (next ()); paths "input") | _ => []
      fun decsUntil stops =
        case peek () of
          NONE => (want "source";[])
        | SOME (W s) => if List.exists (fn t => t = s) stops then [] else let val d = dec () in d :: decsUntil stops end
        | SOME (S _) => let val d = dec () in d :: decsUntil stops end
      and dec () =
        case next () of
          W "files" => Files (paths "source")
        | W "library" =>
            let
              val es = exportList ()
              val () = expect "="
              val ds = decsUntil ["end"]
              val () = expect "end"
            in Library (es, ds) end
        | W "use" => Use (pathWord "build")
        | W "implements" =>
            let val n = case next () of W n => n | S n => n
                val () = expect "="
                val ds = decsUntil ["end"]
                val () = expect "end"
            in Implements (n, ds) end
        | W "annotate" =>
            let
              fun anns () =
                case peek () of
                  SOME (S a) => (ignore (next ());
                                 if knownAnnotation a orelse recover then () else error ("unknown annotation \"" ^ a ^ "\"");
                                 a :: anns ())
                | _ => []
              val a = anns ()
              val () = expect "in"
              val ds = decsUntil ["end"]
              val () = expect "end"
            in Annotate (a, ds) end
        | W "libraries" => Libraries (libraryList ())
        | W "view" =>
            (* the program's view of the Basis Library: a header's view has a
               list, and is a library's *)
            (case next () of
               W n => if BasisManifest.identifier n then View n else error ("not the name of a view: " ^ n)
             | S n => error ("not the name of a view: \"" ^ n ^ "\""))
        | W "inline" =>
            let
              val kind = case next () of
                           W "functor" => Inline
                         | W "val" => InlineVal
                         | _ => error "expected functor or val after inline"
              fun names () = case next () of
                               W "end" => []
                             | W n => n :: names ()
                             | S n => n :: names ()
            in kind (names ()) end
        | W "generate" =>
            let
              val tool = pathWord "tool"
              val arguments = argumentList ()
              val inputs = inputList ()
              val () = expect "outputs"
              val outputs = paths "output"
            in
              if List.null outputs then error "a step says what it makes: outputs PATH ... end"
              else Generate {tool = tool, arguments = arguments, inputs = inputs, outputs = outputs}
            end
        | W "preprocessor" =>
            let
              val name = case next () of
                           W n => if BasisManifest.identifier n then n else error ("not the name of a preprocessor: " ^ n)
                         | S n => error ("not the name of a preprocessor: \"" ^ n ^ "\"")
              val tool = pathWord "tool"
              val arguments = argumentList ()
            in Preprocessor {name = name, tool = tool, arguments = arguments, inputs = inputList ()} end
        | word as W s =>
            (case dropped s of
               SOME instead => error ("the build language has no " ^ s ^ ": " ^ instead)
             | NONE => if List.exists (fn k => k = s) keywords then error ("unexpected " ^ s) else File (reference ("source",word)))
        | word as S _ => File (reference ("source",word))
      (* the modules a header says are virtual, or implemented: structures
         and functors (docs/build.md, Virtual libraries) *)
      fun moduleList what =
        List.map (fn (k, n) => if k = Str orelse k = Fun then (k, n)
                               else error ("a " ^ what ^ " module is a structure or a functor: " ^ what ^ " (KIND NAME, ...)"))
                 (exportList ())
      (* A header's parts, in any order, each once but for its views: what
         comes before the first declaration of the file. `implements (...)`
         is a header's, and `implements NAME = ... end` a declaration *)
      type parts = {requires : string list option, exports : (kind * string) list option, friends : string list option,
                    views : (string * (kind * string) list) list, shadows : (kind * string) list option, strict : bool,
                    virtuals : (kind * string) list option, implements : (kind * string) list option}
      fun header (h : parts) : parts =
        let
          fun once (seen, what) = if isSome seen then error ("a header says " ^ what ^ " once") else ()
          (* a header's view has a list; view NAME alone is a program's *)
          val listed = case !ws of _ :: _ :: {word = W "(", ...} :: _ => true | _ => false
          val implementsList = case !ws of _ :: {word = W "(", ...} :: _ => true | _ => false
          val {requires, exports, friends, views, shadows, strict, virtuals, implements} = h
          fun done () = {requires = requires, exports = exports, friends = friends, views = List.rev views, shadows = shadows,
                         strict = strict, virtuals = virtuals, implements = implements}
        in
          case peek () of
            SOME (W "requires") =>
              (ignore (next ()); once (requires, "requires");
               header {requires = SOME (libraryList ()), exports = exports, friends = friends, views = views, shadows = shadows,
                      strict = strict, virtuals = virtuals, implements = implements})
          | SOME (W "exports") =>
              (ignore (next ()); once (exports, "exports");
               header {requires = requires, exports = SOME (exportList ()), friends = friends, views = views, shadows = shadows,
                      strict = strict, virtuals = virtuals, implements = implements})
          | SOME (W "friends") =>
              (ignore (next ()); once (friends, "friends");
               header {requires = requires, exports = exports, friends = SOME (paths "build"), views = views, shadows = shadows,
                      strict = strict, virtuals = virtuals, implements = implements})
          | SOME (W "shadows") =>
              (ignore (next ()); once (shadows, "shadows");
               header {requires = requires, exports = exports, friends = friends, views = views, shadows = SOME (exportList ()),
                      strict = strict, virtuals = virtuals, implements = implements})
          | SOME (W "virtual") =>
              (ignore (next ()); once (virtuals, "virtual");
               header {requires = requires, exports = exports, friends = friends, views = views, shadows = shadows,
                      strict = strict, virtuals = SOME (moduleList "virtual"), implements = implements})
          | SOME (W "implements") =>
              if not implementsList then done ()
              else
                (ignore (next ()); once (implements, "implements");
                 header {requires = requires, exports = exports, friends = friends, views = views, shadows = shadows,
                        strict = strict, virtuals = virtuals, implements = SOME (moduleList "implemented")})
          | SOME (W "view") =>
              if not listed then done ()
              else
                let
                  val () = ignore (next ())
                  val n = case next () of W n => n | S n => n
                  val () = if List.exists (fn (m, _) => m = n) views then error ("a header has two views " ^ n) else ()
                in
                  header {requires = requires, exports = exports, friends = friends, views = (n, exportList ()) :: views,
                         shadows = shadows, strict = strict, virtuals = virtuals, implements = implements}
                end
          | SOME (W "strict") =>
              (ignore (next ()); if strict then error "a header says strict once" else ();
               header {requires = requires, exports = exports, friends = friends, views = views, shadows = shadows,
                      strict = true, virtuals = virtuals, implements = implements})
          | _ => done ()
        end
      (* a header's exports are a boundary around all the file declares after
         it, in one word the Library that a build reads. An implementing
         library has none: what it implements is reached through the virtual
         library, and it adds no public module (D22) *)
      fun body () =
        case header {requires = NONE, exports = NONE, friends = NONE, views = [], shadows = NONE, strict = false,
                     virtuals = NONE, implements = NONE} of
          {requires = NONE, exports = NONE, friends = NONE, views = [], shadows = NONE, strict = false,
           virtuals = NONE, implements = NONE} => decsUntil []
        | {exports = SOME _, implements = SOME _, ...} =>
            error "an implementing library exports nothing: what it implements is reached through the virtual library (docs/build.md, Virtual libraries)"
        | {requires, exports, friends, views, shadows, strict, virtuals, implements} =>
            (case (exports, implements) of
               (NONE, NONE) => error "a library's header says what it exports"
             | _ =>
                 let val ds = decsUntil []
                 in [Header {requires = getOpt (requires, []), friends = getOpt (friends, []), views = views,
                             shadows = getOpt (shadows, []), strict = strict, virtuals = getOpt (virtuals, []),
                             implements = getOpt (implements, [])},
                     Library (getOpt (exports, []), ds)] end)
    in
      let val ds = body ()
      in case peek () of NONE => ds | SOME (W w) => error ("unexpected " ^ w) | SOME (S s) => error ("unexpected \"" ^ s ^ "\"") end
    end
  fun parse (path,text)=parseUsing {path=path,text=text,recover=false,pathAt=fn _ => (),wanted=fn _ => ()}
    handle LocatedError (_,message) => raise Error (path ^ ": " ^ message)

  (* One import as a build file writes it in its list of libraries, NAME or
     NAME (KIND FROM as TO, ...), as its word (BasisManifest.importWord): what
     --library takes, so that the command line says it as a build file does *)
  fun importText (text : string) : string =
    case parse ("--library", "libraries " ^ text ^ " end") of
      [Libraries [word]] => word
    | _ => raise Error ("--library takes one library, with what it renames: " ^ text)

  (* ---- paths ---- *)

  (* the path variables (--path NAME=DIR) *)
  val variables : string StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("BuildFile.variables", variables)

  (* A path of a build file in dir, its variables given. A path that begins
     with a variable whose value is relative is relative to root, the
     directory of the build file the compile was given, so that one value
     serves every build file a build uses; any other relative path, to dir *)
  fun expandFrom {isAbsolute,concat,root} (dir : string, p : string) : string =
    let
      val n = String.size p
      fun scan (i, acc) =
        if i >= n then String.concat (List.rev acc)
        else if String.sub (p, i) = #"$" andalso i + 1 < n andalso String.sub (p, i + 1) = #"(" then
          let
            fun close j = if j >= n then raise Error ("a path variable that does not end: " ^ p)
                          else if String.sub (p, j) = #")" then j else close (j + 1)
            val j = close (i + 2)
            val name = String.substring (p, i + 2, j - i - 2)
            val v = case StringMap.find (!variables, name) of
                      SOME v => v
                    | NONE => raise Error ("no path variable " ^ name ^ " (--path " ^ name ^ "=DIR)")
          in scan (j + 1, v :: acc) end
        else scan (i + 1, String.str (String.sub (p, i)) :: acc)
      val q = scan (0, [])
      val base = if String.isPrefix "$(" p then root else dir
    in
      if isAbsolute q orelse base = "" orelse base = "." then q else concat (base, q)
    end
  (* where the build given is not known -- an editor's look at one file --
     that file's directory stands for it *)
  fun expandUsing {isAbsolute,concat} (dir,p)=expandFrom {isAbsolute=isAbsolute,concat=concat,root=dir} (dir,p)
  fun expandWith isAbsolute args=expandUsing {isAbsolute=isAbsolute,concat=OS.Path.concat} args
  fun expand args = expandWith OS.Path.isAbsolute args
end
