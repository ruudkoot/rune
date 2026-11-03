(* The flags oracle (docs/testing.md, The checks of the cache; E18): every
   option of `rune` and every variable it reads reaches a key, or is declared
   not to. A setting in no key gives a hit where a miss is due, and root
   blanking cannot see it, since a flag left at its default changes nothing
   there.

   flag-all reads the options out of the sources and wants a row for each,
   and each row's name there: an option added without a word on the cache
   fails here. Each row that makes a compile is then run:
   Key    a cache filled without it, a build with it, against the same build
          without a cache; and the other way about. Units must compile, both
          ways, and the two builds agree in status, bytes and what they print.
   Level  the mark of what an entry was checked at: Key one way, and an entry
          checked more is taken the other.
   Free   no unit compiles, and the builds agree.
   Input  it changes which units there are: the builds agree.
   Apart  not run, and says why: it stops before a unit is compiled, or it is
          what names the inputs or the cache. *)
structure CacheFlags =
struct
  open Incremental

  datatype class = Key | Level | Free | Input | Apart of string
  type row = {label : string, name : string, args : string list, env : (string * string) list,
              base : string list, fixture : string, printing : bool, class : class}

  fun row (label, name, args, class) : row =
    {label = label, name = name, args = args, env = [], base = [], fixture = "plain", printing = true, class = class}
  fun key (label, name, args) = row (label, name, args, Key)
  fun free (label, name, args) = row (label, name, args, Free)
  fun apart (name, why) = row (String.translate (fn #"-" => "" | c => str (Char.toLower c)) name, name, [], Apart why)
  (* on a fixture of its own *)
  fun on fixture (r : row) : row =
    {label = #label r, name = #name r, args = #args r, env = #env r, base = #base r, fixture = fixture,
     printing = #printing r, class = #class r}
  (* over what a build without it had already *)
  fun over base (r : row) : row =
    {label = #label r, name = #name r, args = #args r, env = #env r, base = base, fixture = #fixture r,
     printing = #printing r, class = #class r}
  (* it prints what a compile prints, and a hit does not *)
  fun chatty (r : row) : row =
    {label = #label r, name = #name r, args = #args r, env = #env r, base = #base r, fixture = #fixture r,
     printing = false, class = #class r}
  fun variable (label, name, value, class) : row =
    {label = label, name = name, args = [], env = [(name, value)], base = [], fixture = "plain", printing = true, class = class}

  val stopping = "stops before a unit is compiled"
  val naming = "says which files are compiled, whose names and texts are in their keys"
  val cacheItself = "is the cache's own: what it decides is whether a key is asked"
  val testSwitch = "a test's switch, used without a cache: it corrupts or times what one compile makes"

  val rows : row list =
    [(* in the configuration *)
     key ("O0", "-O0", ["-O0"]), free ("O1", "-O1", ["-O1"]), key ("O2", "-O2", ["-O2"]),
     key ("passes", "--passes", ["--passes=simplify"]),
     key ("int-bits-64", "--int-bits", ["--int-bits=64"]), free ("int-bits-63", "--int-bits", ["--int-bits=63"]),
     key ("flex-records", "--flex-records", ["--flex-records=program"]),
     key ("overloading", "--overloading", ["--overloading=topdec"]),
     key ("free-tyvars", "--free-tyvars", ["--free-tyvars=monotype"]),
     key ("fuel", "--fuel", ["--fuel=1"]),
     key ("functor-budget-0", "--functor-budget", ["--functor-budget=0"]),
     key ("functor-budget-1", "--functor-budget", ["--functor-budget=1"]),
     free ("functor-budget-default", "--functor-budget", ["--functor-budget=1000000"]),
     key ("type-work-1", "--type-work", ["--type-work=1"]),
     key ("type-work-more", "--type-work", ["--type-work=1000000000"]),
     free ("type-work-default", "--type-work", ["--type-work=50000000"]),
     key ("match-work-1", "--match-work", ["--match-work=1"]),
     key ("match-work-more", "--match-work", ["--match-work=1000000000"]),
     free ("match-work-default", "--match-work", ["--match-work=1000000"]),
     key ("no-inline-functors", "--no-inline-functors", ["--no-inline-functors"]),
     key ("target-stack", "--target", ["--target=stack"]), free ("target-registers", "--target", ["--target=registers"]),
     (* in the key of the input files' units *)
     on "prim" (key ("allow-prim", "--allow-prim", ["--allow-prim"])),
     on "orpat" (key ("or-patterns", "--or-patterns", ["--or-patterns"])),
     on "unicode" (key ("unicode", "--unicode", ["--unicode"])),
     on "unicode" (key ("unicode-latin1", "--unicode", ["--unicode=latin1"])),
     on "lookalike" (over ["--unicode"] (key ("no-unicode-lints", "--no-unicode-lints", ["--unicode", "--no-unicode-lints"]))),
     on "int64" (key ("default-int64", "--default-type", ["--default-type=int64"])),
     on "word64" (key ("default-word64", "--default-type", ["--default-type=word64"])),
     free ("default-int", "--default-type", ["--default-type=int"]), free ("default-word", "--default-type", ["--default-type=word"]),
     (* the mark on an entry *)
     over ["--lint=0"] (row ("lint", "--lint", ["--lint"], Level)), over ["--lint=0"] (row ("lint-1", "--lint", ["--lint=1"], Level)),
     free ("lint-0", "--lint", ["--lint=0"]),
     variable ("RUNE_LINT", "RUNE_LINT", "2", Level),
     (* what a build does with what the units come to, or how it says so *)
     row ("basis-all", "--basis", ["--basis", "all"], Input), free ("basis-demand", "--basis", ["--basis", "demand"]),
     free ("whole", "--whole", ["--whole"]), free ("emit-units", "--emit-units", ["--emit-units", "emitted"]),
     free ("jobs-short", "-j", ["-j", "2"]), free ("jobs", "--jobs", ["--jobs", "2"]),
     free ("explain-rebuild", "--explain-rebuild", ["--explain-rebuild"]),
     free ("no-warnings", "--no-warnings", ["--no-warnings"]),
     free ("color-always", "--color", ["--color=always"]), free ("color-never", "--color", ["--color=never"]),
     free ("diagnostics-full", "--diagnostics", ["--diagnostics=full"]),
     free ("diagnostics-short", "--diagnostics", ["--diagnostics=short"]),
     free ("diagnostics-json", "--diagnostics-json", ["--diagnostics-json", "diagnostics.json"]),
     free ("mid-roundtrip", "--mid-roundtrip", ["--mid-roundtrip"]),
     free ("typecheck-only", "--typecheck-only", ["--typecheck-only"]),
     chatty (free ("dump-witnesses", "--dump-witnesses", ["--dump-witnesses"])),
     chatty (free ("dump-lambda", "--dump-lambda", ["--dump-lambda"])),
     chatty (free ("dump-code", "--dump-code", ["--dump-code"])),
     chatty (free ("dump-before", "--dump-before", ["--dump-before=simplify"])),
     chatty (free ("dump-after", "--dump-after", ["--dump-after=simplify"])),
     chatty (free ("pass-stats", "--pass-stats", ["--pass-stats"])),
     chatty (free ("pass-stats-hash", "--pass-stats", ["--pass-stats=hash"])),
     variable ("RUNE_SHAPES", "RUNE_SHAPES", "0", Free),
     variable ("RUNE_REGVERIFY", "RUNE_REGVERIFY", "0", Free),
     variable ("RUNE_REGVERIFY_LINK", "RUNE_REGVERIFY_LINK", "1", Free),
     variable ("RUNE_RBCCHECK", "RUNE_RBCCHECK", "1", Free),
     variable ("RUNE_LINK_CHECK", "RUNE_LINK_CHECK", "0", Free),
     variable ("RUNE_PARALLEL_MIN", "RUNE_PARALLEL_MIN", "1", Free),
     variable ("RUNE_COLORS", "RUNE_COLORS", "light", Free),
     chatty (variable ("RUNE_MEM", "RUNE_MEM", "1", Free)),
     (* not run *)
     apart ("-o", "says where the program goes"),
     apart ("--lib", naming), apart ("--library", naming), apart ("--no-prelude", naming), apart ("-I", naming),
     apart ("--build", naming), apart ("--path", naming),
     apart ("--basis-deps", stopping), apart ("--basis-check", stopping), apart ("--basis-index", stopping),
     apart ("--build-list", stopping), apart ("--plan", stopping), apart ("--deps", stopping), apart ("--deps-dot", stopping), apart ("--deps-uses", stopping),
     apart ("--dump-tokens", stopping), apart ("--lex-count", stopping), apart ("--dump-ast", stopping),
     apart ("--read-mid", stopping), apart ("--version", stopping), apart ("--help", stopping), apart ("-h", stopping),
     apart ("--serve", "answers requests, each a build of its own with these rows' options"),
     apart ("--units", cacheItself), apart ("--cache-dir", cacheItself), apart ("--no-cache", cacheItself),
     apart ("--verify-cache", cacheItself), apart ("RUNE_CACHE", cacheItself), apart ("RUNE_VERIFY_CACHE", cacheItself),
     apart ("RUNE_VERIFY_DUMP", cacheItself), apart ("RUNE_BLANK_ROOTS", cacheItself), apart ("RUNE_BLANK_UNITS", cacheItself),
     apart ("RUNE_PARALLEL_DEBUG", "says what -j did"),
     apart ("RUNE_FAULT", testSwitch), apart ("RUNE_REGVERIFY_INJECT", testSwitch), apart ("RUNE_RBCCHECK_INJECT", testSwitch),
     apart ("RUNE_ASTLINT_FAULT", testSwitch)]

  val prefix = "flag-"
  val all = prefix ^ "all"
  val cases = all :: List.mapPartial (fn (r : row) => case #class r of Apart _ => NONE | _ => SOME (prefix ^ #label r)) rows

  (* ---- what the sources say ---- *)

  (* the strings of a line of source that are written as an option *)
  fun optionsIn line =
    let
      fun quoted (_, []) = []
        | quoted (false, #"\"" :: rest) = quoted (true, rest)
        | quoted (false, _ :: rest) = quoted (false, rest)
        | quoted (true, cs) =
            let
              fun go (acc, []) = (List.rev acc, [])
                | go (acc, #"\"" :: rest) = (List.rev acc, rest)
                | go (acc, c :: rest) = go (c :: acc, rest)
              val (word, rest) = go ([], cs)
            in String.implode word :: quoted (false, rest) end
      fun optionLike w =
        size w >= 2 andalso w <> "--" andalso String.sub (w, 0) = #"-" andalso CharVector.all (fn c => Char.isAlphaNum c orelse c = #"-" orelse c = #"=") w
      fun stem w = hd (String.fields (fn c => c = #"=") w)
    in List.map stem (List.filter optionLike (quoted (false, String.explode line))) end

  (* the options the parser takes: the help's lines are a string that goes on *)
  fun optionsOf text =
    List.concat (List.map optionsIn (List.filter (fn l => not (String.isPrefix "    \\" l)) (lines text)))

  fun variablesIn line =
    let
      fun go (s : substring) =
        let val (_, found) = Substring.position "\"RUNE_" s
        in
          if Substring.isEmpty found then []
          else
            let
              val rest = Substring.triml 1 found
              val word = Substring.string (Substring.takel (fn c => Char.isUpper c orelse Char.isDigit c orelse c = #"_") rest)
            in word :: go (Substring.triml (size word) rest) end
        end
    in go (Substring.full line) end

  fun sourcesUnder dir =
    List.concat (List.map (fn n =>
      let val p = dir ^ "/" ^ n
      in if isDir p then sourcesUnder p else if String.isSuffix ".sml" n then [p] else [] end) (entries dir))

  fun distinct xs = List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else x :: acc) [] xs

  (* Every option and variable has a row; every row names one that is there *)
  fun everyOption (s : state) =
    let
      val options = distinct (optionsOf (read (fromRoot "src/driver/options.sml")) @ optionsOf (read (fromRoot "src/driver/serve.sml")))
      val sources = List.concat (List.map (sourcesUnder o fromRoot) ["src/driver", "src/main", "lib/compiler"])
      val variables = distinct (List.concat (List.map (List.concat o List.map variablesIn o lines o read) sources))
      val found = options @ variables
      val named = distinct (List.map #name rows)
      fun missing (xs, ys) = List.filter (fn x => not (List.exists (fn y => y = x) ys)) xs
    in
      check s ("no row of tests/runner/cacheflags.sml for " ^ String.concatWith " " (missing (found, named))
               ^ ": say whether it reaches a key") (null (missing (found, named)));
      check s ("rows of tests/runner/cacheflags.sml name what is not there: " ^ String.concatWith " " (missing (named, found)))
            (null (missing (named, found)));
      check s "the sources gave no options" (length options > 40);
      (* the check itself: what it would say of a new option *)
      check s "an option with no row would not be seen"
            (missing (optionsOf "    | \"--new-setting\" :: rest => (setting := true; parse rest)", named) = ["--new-setting"]);
      check s "a variable with no row would not be seen"
            (missing (variablesIn "val x = OS.Process.getEnv \"RUNE_NEW_SETTING\"", named) = ["RUNE_NEW_SETTING"])
    end

  (* ---- running a row ---- *)

  val a = "functor F (X : sig val n : int end) = struct fun f y = y + X.n val big = List.tabulate (40, fn i => i + X.n) end\n\
          \structure A = F (struct val n = 1 end)\n\
          \fun g (x : int) = case x of 0 => \"z\" | 1 => \"o\" | _ => \"m\"\n\
          \fun partial (SOME x) = x + 1\n\
          \datatype t = P | Q | R | W\n\
          \fun h (P, P) = 1 | h (Q, Q) = 2 | h (R, R) = 3 | h (_, _) = 4"
  val b = "structure B = F (struct val n = 2 end)\n\
          \val () = print (g (A.f 0) ^ Int.toString (B.f 1) ^ Real.toString (1.5 + 2.5) ^ \"\\n\")\n\
          \val () = print (Int.toString (List.length B.big + h (P, Q) + partial (SOME 1)) ^ \"\\n\")"
  fun fixture "plain" = (a, b)
    | fixture "prim" = ("val g = _prim \"int_abs\" : int -> int", "val () = print (Int.toString (g ~1) ^ \"\\n\")")
    | fixture "orpat" = ("fun f (1 | 2) = \"a\\n\" | f _ = \"b\\n\"", "val () = print (f 1)")
    | fixture "unicode" = ("val s = \"caf\195\169\\n\"", "val () = print s")
    | fixture "lookalike" = ("val v\208\176l = 1", "val () = print (Int.toString v\208\176l ^ \"\\n\")")
    | fixture "int64" = ("val big = 4611686018427387904", "val () = print (Int64.toString big ^ \"\\n\")")
    | fixture "word64" = ("val big = 0wxF000000000000000", "val () = print (Word64.toString big ^ \"\\n\")")
    | fixture name = raise Failed ("no fixture " ^ name)

  fun text (errors : string) = String.concatWith "\n" (List.filter (fn l => not (String.isPrefix "rune: " l)) (lines errors))

  (* A cache filled by a build under fill, then one under build through it,
     against one under build and no cache: what the second compiled. Each of
     fill and build is its arguments and variables *)
  fun way (s : state) (r : row) (fill : string list * (string * string) list, build : string list * (string * string) list) =
    let
      val () = (rmTree (path s "cache"); rmTree (path s "warm.rbc"); rmTree (path s "cold.rbc"))
      val () = #environment s := #2 fill
      val _ = compile s (["--units", "--cache-dir", "cache"] @ #1 fill) "fill.rbc"
      val () = #environment s := #2 build
      val warm = compile s (["--units", "--cache-dir", "cache", "--explain-rebuild"] @ #1 build) "warm.rbc"
      val cold = compile s (["--units", "--no-cache"] @ #1 build) "cold.rbc"
      val () = #environment s := []
      fun words' (args, env) = String.concatWith " " (List.map (fn (n, v) => n ^ "=" ^ v) env @ args)
      val what = "[" ^ words' fill ^ "] then [" ^ words' build ^ "]: "
      val bytes = exists (path s "warm.rbc") = exists (path s "cold.rbc")
                  andalso (not (exists (path s "warm.rbc")) orelse same (path s "warm.rbc", path s "cold.rbc"))
    in
      check s (what ^ "exit " ^ Int.toString (#status warm) ^ " through the cache, " ^ Int.toString (#status cold) ^ " without")
            (#status warm = #status cold);
      check s (what ^ "other bytes through the cache: a hit the setting should have missed") (#status warm <> 0 orelse bytes);
      check s (what ^ "it prints other text through the cache") (not (#printing r) orelse text (#errors warm) = text (#errors cold));
      (Scenarios.rebuilt (#errors warm), #status warm <> 0)
    end

  fun runRow (s : state) (r : row) =
    let
      val (first, second) = fixture (#fixture r)
      val () = (own s "a.sml b.sml"; put s "a.sml" first; put s "b.sml" second)
      (* the runner's RUNE_LINT is not what a row of the lint starts from *)
      val without = (#base r, if #name r = "RUNE_LINT" then [("RUNE_LINT", "0")] else [])
      val given = (#args r, #env r)
      val forth = way s r (without, given)
      fun back () = way s r (given, without)
      (* a program refused both ways has shown what it can *)
      fun reached (compiled, refused) = refused orelse not (null compiled)
    in
      case #class r of
        Key =>
          (check s "an option said to reach a key compiled nothing through a cache filled without it" (reached forth);
           check s "filled with an option said to reach a key, a build without it compiled nothing" (reached (back ())))
      | Level =>
          (check s "a level of the lint said to be a mark on an entry took one of a lower level" (reached forth);
           check s "an entry checked at a higher level was not taken" (null (#1 (back ()))))
      | Free =>
          check s ("an option said to reach no key compiled " ^ String.concatWith " " (#1 forth)) (null (#1 forth))
      | Input => ()
      | Apart _ => ()
    end

  fun one (s : state) =
    if #name s = all then everyOption s
    else
      case List.find (fn (r : row) => prefix ^ #label r = #name s) rows of
        SOME r => runRow s r
      | NONE => raise Failed ("no row " ^ #name s)
end
