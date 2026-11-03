(* The checks of the cache that are not edits of a project (docs/testing.md,
   The checks of the cache). Each is a scenario of bin/rune-incremental.

   blank-*: root blanking. Each root CompilerState knows goes back to its
   sealed baseline, one at a time, before a compile of a unit
   (src/driver/cachecheck.sml): a root that changes what the compile makes is
   one it reads, and tests/incremental/roots.tsv says what covers it, a key,
   a usage or a basis. A root that matters and is not there is an input
   nothing was said of. The roots come from the compiler, so a new root needs
   no line here until a compile reads it.

   across-*: verification of all hits. Each file of a project is given a new
   value, so that the units after it hold across a unit that changed, and
   --verify-cache compares what it can; S98 plants an entry that must fail.

   model: results/L1's model of the cache, the statement of what these are
   for (docs/units.md, Checking it).

   fp-oracle: the fingerprint oracle, each field of a binding and each fact
   of the tables changed alone, against what the description of the codecs
   marks (tools/codecs/compiler.sml). *)
structure CacheChecks =
struct
  open Incremental

  (* ---- root blanking ---- *)

  type group = {label : string, files : string list, flags : string list, units : string option, program : (string * string) list}

  (* a marked function and a marked functor, as a library's are: what the
     tables of what was imported hold *)
  val marked : (string * string) list =
    [("a.sml", "structure A = struct fun inc x = x + 1 datatype t = T of int fun get (T n) = n end\n\
               \functor F (X : sig val n : int end) = struct fun f y = y + X.n end\n\
               \signature S = sig type t val v : t end\n\
               \val aliased = A.inc"),
     ("b.sml", "structure B = F (struct val n = 2 end)\n\
               \structure C :> S = struct type t = string val v = \"c\" end\n\
               \val () = print (Int.toString (A.inc 1 + aliased 2 + A.get (A.T 3) + B.f 1) ^ \"\\n\")"),
     ("p.build", "inline val A.inc end\ninline functor F end\nfiles a.sml b.sml end")]

  fun projectFiles dir =
    let val d = fromRoot dir
    in List.map (fn f => (f, CachePlant.binary (d ^ "/" ^ f))) (words (d ^ "/files")) end

  val groups : group list =
    [{label = "project", files = [], flags = [], units = NONE, program = []},
     {label = "functors", files = [], flags = [], units = NONE, program = []},
     {label = "marked", files = [], flags = ["--build", "p.build"], units = SOME "a.sml,b.sml", program = marked}]
  val blankPrefix = "blank-"

  fun tableRoots () =
    List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                               root :: class :: _ => if String.isPrefix "#" root then NONE else SOME (root, class)
                             | _ => NONE)
                    (lines (read (fromRoot "tests/incremental/roots.tsv")))

  (* the log's lines, as (unit, root, digest), the unit's own compile's by
     root "-" *)
  fun logged file =
    List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                               [u, _, root, digest] => SOME (u, root, digest)
                             | _ => NONE)
                    (lines (read file))

  fun blank (s : state) (g : group) =
    let
      val sources = case #program g of
                      [] => projectFiles ("tests/incremental/" ^ #label g)
                    | p => p
      val () = (own s (String.concatWith " " (List.filter (String.isSuffix ".sml") (List.map #1 sources)));
                List.app (fn (f, t) => CachePlant.writeBinary (path s f) t) sources)
      val log = path s "blank.log"
      val () = #environment s := ("RUNE_BLANK_ROOTS", log)
                                 :: (case #units g of SOME u => [("RUNE_BLANK_UNITS", u)] | NONE => [])
      val r = command s "" ([#compiler s, "--units", "--no-cache"] @ #flags g
                            @ (if null (#flags g) then words (path s "files") else []) @ ["-o", "o.rbc"])
      val () = #environment s := []
      val () = check s ("the compile that blanks failed: " ^ #errors r) (#status r = 0)
      val rows = logged log
      val reference = List.filter (fn (_, root, _) => root = "-") rows
      val () = check s "no unit's compile gave its digest" (not (null reference))
      val children = List.filter (fn (_, root, _) => root <> "-") rows
      val () = check s "too few roots were blanked" (length children >= 300 * length reference)
      fun refOf u = case List.find (fn (v, _, _) => v = u) reference of
                      SOME (_, _, d) => d
                    | NONE => raise Failed ("no digest of " ^ u)
      val matter = List.filter (fn (u, _, d) => d <> refOf u) children
      val table = tableRoots ()
      val undeclared = List.filter (fn (_, root, _) => not (List.exists (fn (r, _) => r = root) table)) matter
      val () = check s ("roots a compile reads that tests/incremental/roots.tsv does not say what covers: "
                        ^ String.concatWith ", " (List.map (fn (u, root, d) => root ^ " (" ^ u ^ ", " ^ d ^ ")")
                                                           (List.take (undeclared, Int.min (length undeclared, 8)))))
                     (null undeclared)
      val known = List.foldl (fn ((_, root, _), acc) => if List.exists (fn x => x = root) acc then acc else root :: acc) [] children
      val gone = List.filter (fn (root, _) => not (List.exists (fn x => x = root) known)) table
      (* a blank that does nothing would pass all of the above *)
      val () = check s "blanking the source files changed nothing" (List.exists (fn (_, root, _) => root = "Source.files") matter)
    in
      check s ("roots.tsv names roots the compiler has not: " ^ String.concatWith " " (List.map #1 gone)) (null gone);
      say (#label g ^ ": " ^ Int.toString (length reference) ^ " units, " ^ Int.toString (length known) ^ " roots blanked each\n")
    end

  (* ---- verification of all hits ---- *)

  val acrossPrefix = "across-"
  val acrossProjects = ["project", "functors"]

  fun countLines (needle, text) = length (List.filter (String.isSubstring needle) (lines text))

  (* Each file in turn given a new value at its end: a unit after it whose
     usages hold by fingerprint is compared, or does not load, as a build
     without --verify-cache would not take it either. *)
  fun across (s : state) project =
    let
      val sources = projectFiles ("tests/incremental/" ^ project)
      val files = List.map #1 sources
      val () = own s (String.concatWith " " files)
      fun restore () = List.app (fn (f, t) => CachePlant.writeBinary (path s f) t) sources
      val compared = ref 0
      val notLoaded = ref 0
      fun step file =
        let
          val () = restore ()
          val () = build s []
          val () = check s "the project does not build" (#status (!(#result s)) = 0)
          val () = CachePlant.writeBinary (path s file) (CachePlant.binary (path s file) ^ "structure Added = struct val added = 1 end\n")
          val () = build s ["--verify-cache"]
          val r = !(#result s)
        in
          check s ("--verify-cache failed after an edit of " ^ file ^ ": " ^ #errors r) (#status r = 0);
          compared := !compared + countLines ("its entry, loaded across a unit that changed, is what compiling it gives", #errors r);
          notLoaded := !notLoaded + countLines ("to verify: its entry holds across a unit that changed and does not load here", #errors r)
        end
      val () = List.app step files
    in
      check s "no entry taken across a change was compared" (!compared > 0);
      say (project ^ ": " ^ Int.toString (!compared) ^ " entries across a change compared, all the same; "
           ^ Int.toString (!notLoaded) ^ " do not load\n")
    end

  (* an entry that holds across a unit that changed and is not what compiling
     the unit gives: its usages one compile's, its contents another's. A
     build takes it; --verify-cache, comparing it, fails *)
  fun planted (s : state) =
    let
      val () = own s "y.sml a.sml c.sml"
      val () = put s "y.sml" "fun op++ (a, b) = a - b"
      fun fixity p extra = put s "a.sml" ("infix " ^ Int.toString p ^ " ++" ^ extra)
      val () = fixity 6 ""
      val () = put s "c.sml" "val v = 10 ++ 3 * 2  val () = print (Int.toString v ^ \"\\n\")"
      val () = build s []
      val () = check s "the project does not build" (#status (!(#result s)) = 0)
      fun entries () = List.filter (fn file => String.isSubstring "c.sml" (CachePlant.binary file)) (cache s)
      val first = entries ()
      fun notFirst files = List.filter (fn file => not (List.exists (fn old => old = file) first)) files
      val () = copy (only first) (path s "old-entry")
      val () = fixity 8 ""
      val () = build s []
      val new = only (notFirst (entries ()))
      val () = CachePlant.stale (path s "old-entry") new
      (* a.sml changes, and what c.sml read of it does not: c.sml's entry
         holds by its fingerprints alone *)
      val () = fixity 8 "  val added = 1"
      val () = build s []
      val () = check s ("the planted entry was not taken across the change: " ^ #errors (!(#result s)))
                     (String.isSubstring "from the cache c.sml, across" (#errors (!(#result s))) orelse
                      not (List.exists (fn f => f = "c.sml") (compiled s)))
      val () = build s ["--verify-cache"]
      val r = !(#result s)
      val () = check s ("--verify-cache did not take the planted entry for one across a change: " ^ #errors r)
                     (String.isSubstring "compiled c.sml: to verify, across a unit that changed" (#errors r))
    in
      check s ("--verify-cache did not find the planted entry: " ^ #errors r)
            (#status r <> 0 andalso String.isSubstring "c.sml: the cache's entry is not what compiling it gives" (#errors r))
    end

  (* S99: an entry whose usages hold and whose code names a unit no longer
     there, in a program that takes nothing across a change, so that nothing
     remaps it: the guard of build-cache issue 4 makes it a miss, where the
     link would find no unit to take the name from *)
  fun absentUnit (s : state) =
    let
      val () = own s "a.sml b.sml main.sml"
      val () = put s "a.sml" "structure A = struct val x = 40 end"
      val () = put s "b.sml" "functor F () = struct val y = A.x + 2 end"
      val () = put s "main.sml" "structure B = F ()\nval () = print (Int.toString B.y ^ \" \" ^ Int.toString (length (Runtime.linkedUnits ()) div 1000000) ^ \"\\n\")"
      val () = build s []
      val () = check s "the project does not build" (#status (!(#result s)) = 0)
      fun entries () = List.filter (fn file => String.isSubstring "b.sml" (CachePlant.binary file)
                                               andalso not (String.isSubstring "main.sml" (CachePlant.binary file))) (cache s)
      val first = entries ()
      val () = copy (only first) (path s "old-entry")
      val () = put s "a.sml" "structure A = struct val x = 40 val z = 3 end"
      val () = build s []
      val new = only (List.filter (fn file => not (List.exists (fn old => old = file) first)) (entries ()))
      val () = CachePlant.stale (path s "old-entry") new
      val () = build s []
      val r = !(#result s)
      val () = check s ("the entry that names a unit no longer there was not refused: " ^ #errors r)
                     (#status r = 0 andalso String.isSubstring "compiled b.sml: its entry names a.sml@" (#errors r))
    in prints s "42 0" end

  (* S100: a signature used and then declared again by the same unit: its usage
     is the signature as the unit began (build-cache issue 17), so an edit
     of the unit that declared it that keeps it compiles that unit alone *)
  fun usedThenDeclared (s : state) =
    let
      val () = own s "a.sml b.sml"
      val () = put s "a.sml" "signature S = sig val x : int end"
      val () = put s "b.sml" ("structure B : S = struct val x = 1 end\n"
                              ^ "signature S = sig val z : string end\n"
                              ^ "structure C : S = struct val z = \"c\" end\n"
                              ^ "val () = print (Int.toString B.x ^ C.z ^ \"\\n\")")
      val () = checkBuild s [] "a.sml b.sml"
      val () = put s "a.sml" "signature S = sig val x : int end\nstructure Other = struct val more = 1 end"
      val () = checkBuild s [] "a.sml"
    in prints s "1c" end

  (* S101: a datatype of a functor's result whose layout the body fixed, where
     the instance's type would give another, and the application left a call
     (--functor-budget=0): an entry's Mid keeps the layout, or the whole
     program made of the units' Mid builds the constructor otherwise than the
     functor's function reads it *)
  fun pinnedLayout (s : state) =
    let
      val () = own s "a.sml b.sml"
      val () = put s "a.sml" ("functor F (X : sig type t val v : t end) = struct\n"
                              ^ "  datatype d = D of X.t | E\n  val made = D X.v\n  fun get (D x) = x | get E = X.v\nend")
      val () = put s "b.sml" ("local\n  structure A = F (struct type t = int * int val v = (1, 2) end)\nin\n"
                              ^ "  val (x, y) = A.get (A.D (3, 4))\n"
                              ^ "  val (u, w) = case A.made of A.D (p, q) => (p, q) | A.E => (0, 0)\nend\n"
                              ^ "val () = print (Int.toString (x + y + 10 * u + 100 * w) ^ \"\\n\")")
      val budget = "--functor-budget=0"
      val whole = compile s [budget] "whole.rbc"
      val () = check s ("the whole compile failed: " ^ #errors whole) (#status whole = 0)
      fun units () =
        let val r = compile s ["--units", "--whole", "--cache-dir", "cache", budget] "units.rbc"
        in
          check s ("the build in units failed: " ^ #errors r) (#status r = 0);
          check s "--units --whole is not the whole compile's bytes" (same (path s "whole.rbc", path s "units.rbc"))
        end
    in units (); units () end

  (* ---- the model ---- *)

  fun model (s : state) =
    let
      val () = reset s
      val out = path s "model.rbc"
      val c = command s "" [#compiler s, fromRoot "tests/incremental/model.sml", "-o", out]
      val () = check s ("the model does not compile: " ^ #errors c) (#status c = 0)
      val r = command s "" [OS.Path.dir (#compiler s) ^ "/runevm", out]
      val expected = read (fromRoot "tests/incremental/model.expected")
    in check s ("the model says otherwise than tests/incremental/model.expected: " ^ #output r) (#output r = expected) end

  (* ---- the fingerprint oracle (the build-system roadmap's D20 and M5) ----

     A compile under RUNE_FP_ORACLE (UnitBasis.fpOracle): of each value, type
     and structure a unit binds, each field changed alone moves the
     fingerprint in the layers the description of the codecs marks it in
     (tools/codecs/compiler.sml) and no other, and the sameness of two
     bindings as it marks; and so does each fact a fingerprint reads of the
     compiler's tables by hand. Every check holds, and the program has a
     binding of each kind, so that each field and each fact is changed at
     least once. *)
  val oracleProgram =
    [("a.sml", "structure A =\nstruct\n  datatype t = T of int | U\n  exception E of string\n  fun inc x = x + 1\n\
               \  val aliased = inc\n  val len = String.size\n  fun same (x : ''a, y) = x = y\n  type 'a pair = 'a * 'a\n\
               \  structure Inner = struct val n = 1 end\nend\n\
               \signature S =\nsig\n  type t\n  datatype d = D | F of int\n  type e\n  val G : int -> e\n  val v : t\n\
               \  exception X\n  val Y : exn\nend\n"),
     ("b.sml", "structure B :> S =\nstruct\n  type t = string\n  datatype d = D | F of int\n  datatype e = G of int\n\
               \  val v = \"b\"\n  exception X\n  exception Y\nend\n\
               \val () = print (Int.toString (A.inc 1 + A.aliased 2 + A.len \"abc\") ^ \"\\n\")\n")]
  val oracleLabels =
    ["Env.Val.scheme", "Env.Val.stamp", "Env.Val.global", "Env.Con.scheme", "Env.Con.info.name", "Env.Con.info.tag",
     "Env.Con.info.hasArg", "Env.Con.info.ncons", "Env.Con.info.isRef", "Env.Con.info.siblings", "Env.Exn.ty", "Env.Exn.info.name",
     "Env.Exn.info.hasArg", "Env.Exn.info.stamp", "Env.Exn.info.isGlobal", "Env.ConAsVal.scheme", "Env.ConAsVal.info.tag",
     "Env.ExnAsVal.ty", "Env.ExnAsVal.info.stamp", "Env.TyStr.fcn.T.TName.c", "Env.TyStr.fcn.T.TAbbrev.ids",
     "Env.TyStr.fcn.T.TAbbrev.t", "Env.TyStr.cons", "Env.Env.vals", "Env.Env.tys", "Env.Env.strs",
     "facts.primAliases", "facts.knownBefore", "facts.globalAliases", "facts.primGlobals",
     "definition.eq", "definition.realisation", "definition.constructors"]

  fun fpOracle (s : state) =
    let
      val () = own s "a.sml b.sml"
      val () = List.app (fn (f, t) => put s f t) oracleProgram
      val log = path s "oracle.log"
      val () = #environment s := [("RUNE_FP_ORACLE", log)]
      val r = command s "" [#compiler s, "--units", "--no-cache", "a.sml", "b.sml", "-o", "o.rbc"]
      val () = #environment s := []
      val () = check s ("the compile under the oracle failed: " ^ #errors r) (#status r = 0)
      val rows = List.map (String.fields (fn c => c = #"\t")) (List.filter (fn l => l <> "") (lines (read log)))
      val fails = List.filter (fn row => case row of v :: _ => v = "FAIL" | [] => false) rows
      val () = check s ("the oracle found fingerprints or samenesses that are not what the description marks: "
                        ^ String.concatWith "; " (List.map (String.concatWith " ") (List.take (fails, Int.min (8, length fails)))))
                     (null fails)
      val labels = List.mapPartial (fn row => case row of _ :: _ :: _ :: l :: _ => SOME l | _ => NONE) rows
      val missing = List.filter (fn l => not (List.exists (fn x => x = l orelse String.isPrefix (l ^ "[") x) labels)) oracleLabels
      val () = check s ("the oracle changed nothing of " ^ String.concatWith ", " missing) (null missing)
    in say ("fp-oracle: " ^ Int.toString (length rows) ^ " checks, " ^ Int.toString (length oracleLabels) ^ " kinds of change\n") end

  val cases = "model" :: "S98" :: "S99" :: "S100" :: "S101" :: "fp-oracle"
              :: List.map (fn (g : group) => blankPrefix ^ #label g) groups
              @ List.map (fn p => acrossPrefix ^ p) acrossProjects

  fun handles name = List.exists (fn c => c = name) ["model", "S98", "S99", "S100", "S101", "fp-oracle"] orelse String.isPrefix blankPrefix name orelse String.isPrefix acrossPrefix name
  fun one (s : state) =
    if #name s = "model" then model s
    else if #name s = "fp-oracle" then fpOracle s
    else if #name s = "S98" then planted s
    else if #name s = "S99" then absentUnit s
    else if #name s = "S100" then usedThenDeclared s
    else if #name s = "S101" then pinnedLayout s
    else if String.isPrefix acrossPrefix (#name s) then across s (String.extract (#name s, size acrossPrefix, NONE))
    else
      case List.find (fn (g : group) => blankPrefix ^ #label g = #name s) groups of
        SOME g => blank s g
      | NONE => raise Failed ("no check " ^ #name s)
end
