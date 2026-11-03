(* The plan: what a compile is made of, as a value and as text, whatever said
   so -- a build file or the command line (docs/build.md, The plan; the
   build-system roadmap's D5). The text can be read without Rune and without a
   parser: a line is words, in compile order, and `$1=="unit"` is the list of
   files. It is Rune's own, nothing in a cache reads it, and it says how a plan
   was made apart from what the plan is: `provenance` is outside the body two
   forms of one build compare on.

     rune-plan 1
     basis demand | all | none
     view NAME                         the program's view of the Basis Library, if any
     inline functor|val NAME           the program's
     library NAME DIR                  each, what it is written on before it
       form open | block | header
       requires NAME                   as written, in order
       inline functor|val NAME
       export KIND NAME                sorted; a view's are in view NAME ... end
       view NAME ... end
       friend PATH
       shadow KIND NAME                  a name of the Basis Library an export takes the place of
       STEP ...
     end
     program
       requires NAME
       STEP ...
     end
     provenance
       input PATH SHA256
     end

     STEP ::= unit NAME PATH MODE ANNOTATION ...
            | use KEY STEP ... end     a build file, used for the first time
            | replay KEY               and again
            | boundary EXPORT ... STEP ... end
            | implements NAME STEP ... end

   A field holds no space: % and what is not printable ASCII are %xx, and an
   empty field is %-. The Basis Library is implicit, as it is in a build file.
   The words `edge` and `scc` are kept for what a graph discovered from
   sources would add, an edge between units and a group of units that use
   each other; a plan of version 1 has neither, and refuses them. *)
structure CompilerPlan =
struct
  structure P = CompilerProject
  structure W = Workspace

  type export = BuildFile.kind * string
  datatype step =
      Unit of {name : string, path : string, mode : string, annotations : string list}
    | Boundary of export list * step list
    | Use of string * step list
    | Implements of string * step list
  (* what a library's build file says of its boundary: none, the older block,
     or a header (docs/build.md, A library's build file) *)
  datatype form = Open | Block of export list | Header of export list
  type library = {name : string, dir : string, form : form, requires : string list, inline : string list,
                  inlineValues : string list, views : (string * export list) list, friends : string list,
                  shadows : export list, steps : step list}
  type input = {path : string, hash : string}
  type t = {basis : string, view : string option, inline : string list, inlineValues : string list, libraries : library list,
            requires : string list, program : step list, inputs : input list}

  exception Bad of string

  (* ---- what has no order in the source has one here ---- *)

  fun kindWord k =
    case k of BuildFile.Str => "structure" | BuildFile.Sig => "signature" | BuildFile.Fun => "functor"
            | BuildFile.Ty => "type" | BuildFile.Fix => "fixity"
  fun kindNamed w =
    case w of "structure" => BuildFile.Str | "signature" => BuildFile.Sig | "functor" => BuildFile.Fun
            | "type" => BuildFile.Ty | "fixity" => BuildFile.Fix | _ => raise Bad ("no kind of export is " ^ w)
  fun insert le (x, []) = [x]
    | insert le (x, y :: ys) = if le (x, y) then x :: y :: ys else y :: insert le (x, ys)
  fun sort le xs = List.foldl (insert le) [] xs
  fun distinct xs = List.foldr (fn (x, acc) => case acc of y :: _ => if x = y then acc else x :: acc | [] => [x]) [] xs
  val sortStrings = fn xs => distinct (sort (fn (a : string, b) => a <= b) xs)
  fun exportKey (k, n) = kindWord k ^ " " ^ n
  val sortExports = fn es => sort (fn (a, b) => exportKey a <= exportKey b) es

  (* ---- a field ---- *)

  val hexDigit = "0123456789abcdef"
  fun escape "" = "%-"
    | escape s =
        String.translate (fn c =>
          if c = #"%" orelse Char.ord c <= 32 orelse Char.ord c >= 127
          then "%" ^ String.str (String.sub (hexDigit, Char.ord c div 16)) ^ String.str (String.sub (hexDigit, Char.ord c mod 16))
          else String.str c) s
  fun hexValue c =
    if c >= #"0" andalso c <= #"9" then Char.ord c - 48
    else if c >= #"a" andalso c <= #"f" then Char.ord c - 87
    else raise Bad "a bad escape"
  fun unescape "%-" = ""
    | unescape s =
        let
          val n = String.size s
          fun go (i, acc) =
            if i >= n then String.implode (List.rev acc)
            else if String.sub (s, i) = #"%" then
              if i + 2 >= n then raise Bad "an escape that does not end"
              else go (i + 3, Char.chr (hexValue (String.sub (s, i + 1)) * 16 + hexValue (String.sub (s, i + 2))) :: acc)
            else go (i + 1, String.sub (s, i) :: acc)
        in go (0, []) end

  (* ---- the text ---- *)

  fun line (depth, fields) = CharVector.tabulate (2 * depth, fn _ => #" ") ^ String.concatWith " " fields ^ "\n"
  fun export depth (k, n) = line (depth, ["export", kindWord k, escape n])
  fun exportsText (depth, es) = String.concat (List.map (export depth) es)
  fun stepsText (seen, depth, ss) = String.concat (List.map (fn s => stepText (seen, depth, s)) ss)
  and stepText (seen, depth, s) =
    case s of
      Unit {name, path, mode, annotations} =>
        line (depth, ["unit", escape name, escape path, escape mode] @ List.map escape annotations)
    | Boundary (es, ss) =>
        line (depth, ["boundary"]) ^ exportsText (depth + 1, es) ^ stepsText (seen, depth + 1, ss) ^ line (depth, ["end"])
    | Use (key, ss) =>
        if List.exists (fn k => k = key) (!seen) then line (depth, ["replay", escape key])
        else (seen := key :: !seen;
              let val body = stepsText (seen, depth + 1, ss)
              in line (depth, ["use", escape key]) ^ body ^ line (depth, ["end"]) end)
    | Implements (n, ss) => line (depth, ["implements", escape n]) ^ stepsText (seen, depth + 1, ss) ^ line (depth, ["end"])
  fun requiresText (depth, names) = String.concat (List.map (fn n => line (depth, ["requires", escape n])) names)
  fun inlinesText (depth, functors, values) =
    String.concat (List.map (fn n => line (depth, ["inline", "functor", escape n])) functors) ^
    String.concat (List.map (fn n => line (depth, ["inline", "val", escape n])) values)
  fun libraryText ({name, dir, form, requires, inline, inlineValues, views, friends, shadows, steps} : library) =
    let
      val (word, exports) = case form of Open => ("open", []) | Block es => ("block", es) | Header es => ("header", es)
    in
      line (0, ["library", escape name, escape dir]) ^ line (1, ["form", word]) ^ requiresText (1, requires) ^
      inlinesText (1, inline, inlineValues) ^ exportsText (1, exports) ^
      String.concat (List.map (fn (v, es) => line (1, ["view", escape v]) ^ exportsText (2, es) ^ line (1, ["end"])) views) ^
      String.concat (List.map (fn f => line (1, ["friend", escape f])) friends) ^
      String.concat (List.map (fn (k, n) => line (1, ["shadow", kindWord k, escape n])) shadows) ^
      stepsText (ref [], 1, steps) ^ line (0, ["end"])
    end
  (* what two forms of one build must agree on; inputs say how it was made *)
  fun body ({basis, view, inline, inlineValues, libraries, requires, program, ...} : t) : string =
    line (0, ["rune-plan", "1"]) ^ line (0, ["basis", basis]) ^
    (case view of NONE => "" | SOME v => line (0, ["view", escape v])) ^ inlinesText (0, inline, inlineValues) ^
    String.concat (List.map libraryText libraries) ^
    line (0, ["program"]) ^ requiresText (1, requires) ^ stepsText (ref [], 1, program) ^ line (0, ["end"])
  fun print (p : t) : string =
    body p ^ line (0, ["provenance"]) ^
    String.concat (List.map (fn {path, hash} => line (1, ["input", escape path, escape hash])) (#inputs p)) ^
    line (0, ["end"])

  fun read (text : string) : t =
    let
      val lines = ref (List.mapPartial
        (fn l => case String.tokens Char.isSpace l of [] => NONE | ws => SOME ws)
        (String.fields (fn c => c = #"\n") text))
      fun peek () = case !lines of l :: _ => SOME l | [] => NONE
      fun next () = case !lines of l :: rest => (lines := rest; l) | [] => raise Bad "the text ends early"
      fun field s = unescape s
      fun fields ws = List.map unescape ws
      fun expect w = case next () of [x] => if x = w then () else raise Bad ("expected " ^ w ^ ", found " ^ x)
                                   | _ => raise Bad ("expected " ^ w)
      (* the lines of one form, while f takes them *)
      fun collect (f, acc) =
        case Option.mapPartial f (peek ()) of
          SOME x => (ignore (next ()); collect (f, x :: acc))
        | NONE => List.rev acc
      fun exports () = collect (fn ["export", k, n] => SOME (kindNamed k, field n) | _ => NONE, [])
      fun requires () = collect (fn ["requires", n] => SOME (field n) | _ => NONE, [])
      fun inlines w = collect (fn ["inline", x, n] => if x = w then SOME (field n) else NONE | _ => NONE, [])
      val used = ref [] : (string * step list) list ref
      fun readSteps acc =
        case peek () of
          NONE => raise Bad "the text ends inside steps"
        | SOME ("end" :: _) => List.rev acc
        | SOME _ => readSteps (readStep () :: acc)
      and closed () = let val ss = readSteps [] in expect "end"; ss end
      and readStep () =
        case next () of
          "unit" :: name :: path :: mode :: annotations =>
            Unit {name = field name, path = field path, mode = field mode, annotations = fields annotations}
        | ["boundary"] => let val es = exports () in Boundary (es, closed ()) end
        | ["use", key] =>
            let val key = field key
                val ss = closed ()
            in used := (key, ss) :: !used; Use (key, ss) end
        | ["replay", key] =>
            let val key = field key
            in case List.find (fn (k, _) => k = key) (!used) of
                 SOME (_, ss) => Use (key, ss)
               | NONE => raise Bad ("replay of " ^ key ^ ", which no use came before")
            end
        | ["implements", n] => Implements (field n, closed ())
        | w :: _ => raise Bad ("a plan of version 1 has no step " ^ w)
        | [] => raise Bad "an empty line"
      fun views () =
        case peek () of
          SOME ["view", v] =>
            let val () = ignore (next ())
                val es = exports ()
                val () = expect "end"
            in (field v, es) :: views () end
        | _ => []
      fun readLibrary (name, dir) =
        let
          val () = used := []
          val word = case next () of ["form", w] => w | _ => raise Bad "a library says its form"
          val rs = requires ()
          val inl = inlines "functor"
          val inlv = inlines "val"
          val es = exports ()
          val form = case word of "open" => Open | "block" => Block es | "header" => Header es
                                | _ => raise Bad ("no form of library is " ^ word)
          val vs = views ()
          val fs = collect (fn ["friend", f] => SOME (field f) | _ => NONE, [])
          val shs = collect (fn ["shadow", k, n] => SOME (kindNamed k, field n) | _ => NONE, [])
          val ss = closed ()
        in
          {name = name, dir = dir, form = form, requires = rs, inline = inl, inlineValues = inlv,
           views = vs, friends = fs, shadows = shs, steps = ss}
        end
      val () = case next () of ["rune-plan", "1"] => () | _ => raise Bad "not a plan of version 1"
      val basis = case next () of ["basis", b] => b | _ => raise Bad "a plan says its basis"
      val view = case peek () of SOME ["view", v] => (ignore (next ()); SOME (field v)) | _ => NONE
      val inline = inlines "functor"
      val inlineValues = inlines "val"
      fun libraries acc =
        case peek () of
          SOME ["library", name, dir] => (ignore (next ()); libraries (readLibrary (field name, field dir) :: acc))
        | _ => List.rev acc
      val libs = libraries []
      val () = expect "program"
      val () = used := []
      val rs = requires ()
      val program = closed ()
      val inputs =
        case peek () of
          SOME ["provenance"] =>
            (ignore (next ());
             let val is = collect (fn ["input", p, h] => SOME {path = field p, hash = field h} | _ => NONE, [])
             in expect "end"; is end)
        | _ => []
      val () = case peek () of NONE => () | SOME _ => raise Bad "text after the plan"
    in
      {basis = basis, view = view, inline = inline, inlineValues = inlineValues, libraries = libs, requires = rs,
       program = program, inputs = inputs}
    end

  (* ---- flattening ---- *)

  (* the units of steps, a build file used twice giving its units once *)
  fun unitsOf steps =
    let
      val seen = ref [] : string list ref
      fun all ss = List.concat (List.map one ss)
      and one (Unit u) = [u]
        | one (Boundary (_, ss)) = all ss
        | one (Implements (_, ss)) = all ss
        | one (Use (key, ss)) =
            if List.exists (fn k => k = key) (!seen) then [] else (seen := key :: !seen; all ss)
    in all steps end

  (* The files of a compile, in order: each library's, each before what is
     written on it; the program's; the libraries' final files, which come after
     it. A whole library is listed: what a compile takes of it is selection's. *)
  fun flatten ({libraries, program, ...} : t) : string list =
    let
      fun final ({annotations, ...} : {name : string, path : string, mode : string, annotations : string list}) =
        P.classOf annotations = "final"
      val units = List.concat (List.map (fn l : library => unitsOf (#steps l)) libraries)
      val (last, first) = List.partition final units
    in List.map #path first @ List.map #path (unitsOf program) @ List.map #path last end

  (* ---- a plan from what the compiler reads ---- *)

  (* A compile's plan: its project, with the plans of the libraries it names
     (libraries, --library's among them) and of those they are written on,
     each read from its build file, under lib. The units are named as a compile
     names them, whose order that is: the libraries, the program, the final
     files. A unit's name says where it is; a path that is not under a library
     keeps its spelling. *)
  fun make {project : P.plan, libraries : string list, lib : string option, mode : Source.mode,
            scope : W.scope, windows : bool, read : string -> {text : string, revision : string},
            hash : string -> string} : t =
    let
      val names = W.names scope
      val ranks = W.ranks ()
      val known = ref [] : (string * P.plan) list ref
      fun planOf dir =
        case List.find (fn (d, _) => d = dir) (!known) of
          SOME (_, p) => p
        | NONE =>
            let val p = P.plan {file = P.concat windows (dir, "library.build"), windows = windows, readBuild = read}
            in known := (dir, p) :: !known; p end
      val dirs = case lib of
                   NONE => []
                 | SOME root => BasisManifest.librariesBy (fn dir => #libraries (planOf dir)) (root, libraries)
      (* the names of a file's units, in the order a compile comes to them *)
      val named = ref StringMap.empty : string list StringMap.map ref
      fun give (path, name) =
        named := StringMap.insert (!named, path, getOpt (StringMap.find (!named, path), []) @ [W.fresh (ranks, name)])
      fun take path =
        case StringMap.find (!named, path) of
          SOME (name :: rest) => (named := StringMap.insert (!named, path, rest); name)
        | _ => raise Bad ("a unit with no name: " ^ path)
      fun below (dir, path) =
        if String.isPrefix (dir ^ "/") path then String.extract (path, size dir + 1, NONE) else path
      val normal = P.pathKey windows
      val libraryUnits =
        List.concat (List.map (fn dir =>
          List.map (fn (path, annotations) => (dir, normal path, annotations)) (P.units (#steps (planOf dir)))) dirs)
      val (finals, firsts) = List.partition (fn (_, _, annotations) => P.classOf annotations = "final") libraryUnits
      fun library (dir, path, _) = give (path, W.ofEntry (names, {dir = dir, file = below (dir, path)}))
      val () = List.app library firsts
      val () = List.app (fn (path, _) => give (path, W.name (names, path))) (P.units (#steps project))
      val () = List.app library finals
      fun convert (spelt, modeOf) steps =
        let
          val memo = ref [] : (string * step) list ref
          fun one (P.SUnit (path, annotations)) =
                let val path = spelt path
                in Unit {name = take path, path = path, mode = Source.modeName (modeOf annotations), annotations = annotations} end
            | one (P.SLibrary (es, ss)) = Boundary (sortExports es, all ss)
            | one (P.SImplements (n, ss)) = Implements (n, all ss)
            | one (P.SUse (key, ss)) =
                case List.find (fn (k, _) => k = key) (!memo) of
                  SOME (_, s) => s
                | NONE => let val s = Use (key, all ss) in memo := (key, s) :: !memo; s end
          and all ss = List.map one ss
        in all steps end
      fun libraryOf dir : library =
        let
          val p = planOf dir
          val (form, steps) =
            case (#header p, #steps p) of
              (SOME _, [P.SLibrary (es, ss)]) => (Header (sortExports es), ss)
            | (NONE, [P.SLibrary (es, ss)]) => (Block (sortExports es), ss)
            | (_, ss) => (Open, ss)
          val {friends, views, shadows} =
            case #header p of
              SOME {friends, views, shadows, ...} =>
                {friends = sortStrings friends, views = List.map (fn (v, es) => (v, sortExports es)) views,
                 shadows = sortExports shadows}
            | NONE => {friends = [], views = [], shadows = []}
        in
          {name = W.libraryName names (W.keyOf (windows, #cwd scope) dir), dir = dir, form = form, requires = #libraries p,
           inline = sortStrings (#inline p), inlineValues = sortStrings (#inlineValues p), views = views, friends = friends,
           shadows = shadows, steps = convert (normal, fn _ => Source.Ascii) steps}
        end
      val librariesPlanned = List.map libraryOf dirs
      val program = convert (fn path => path, fn annotations => P.modeOf (mode, annotations)) (#steps project)
      val inputs =
        List.foldl (fn ({path, text, ...} : P.input, all) =>
                      if List.exists (fn ({path = p, ...} : input) => p = path) all then all
                      else all @ [{path = path, hash = hash text}])
                   [] (#inputs project @ List.concat (List.map (fn dir => #inputs (planOf dir)) dirs))
    in
      {basis = #basis project, view = #view project, inline = sortStrings (#inline project),
       inlineValues = sortStrings (#inlineValues project),
       libraries = librariesPlanned, requires = libraries, program = program, inputs = inputs}
    end
end
