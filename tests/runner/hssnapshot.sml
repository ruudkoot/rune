(* bin/rhc against the whole program (the haskell98 roadmap's D45, its A;
   rulings 66 and 67; src/rhc/driver.sml, RhcDriver.front): bin/rhc takes
   the library's units from its snapshot, bin/rhc.layer, made by make, and
   reads, checks and desugars only a program's own modules, a unit at a
   time; `--whole` reads and checks the library too, the reference. The
   two must print the same.

   - `hs/snapshot/layer`: bin/rhc.layer holds the units of this rhc
     (`bin/rhc --identity`) and of no other, and is newer than every file
     of share/rhc, which `make bin/rhc` holds it to.
   - `hs/snapshot/accept/K-of-N`, `hs/snapshot/errors/K-of-N`,
     `hs/snapshot/lang/K-of-N`: every program of the directory checked
     both ways, `bin/rhc --typecheck-only --lint=2` with its `.cargs`,
     prints the same, standard output and error, and ends with the same
     status; at level 2, the runner's own (RUNE_LINT=2), HsLint replays
     each way the records of the modules the program reaches, against the
     snapshot each unit after the parts of those before. A program's own
     options that shape the library's reading (`--cycle-default=scc`)
     send both ways whole. A program of tests/hs/lang is also run both
     ways on Core's interpreter, its `.stdin` its standard input, in a
     directory of its own, to the same output and status, and every
     eighth of a shard has its Core compared too (`--desugar-only
     --dump-after=desugar`): what main reaches of the units, the library's
     taken from the snapshot, is the Core a whole desugaring gives.
     tests/hs/lang's shards are twice as many.

   The programs of a directory are judged in `shards` jobs, the K-th
   taking every N-th from the K-th, each a line FAIL for each program
   that differs, all nightly; make check's job of a directory, `sample`,
   takes the sample of ruling 47 (HsLang.sampled: one program in
   HsLang.sampleOneIn, by its name's hash, never one of lang-nightly.txt)
   (the roadmap's D56, the lead's rulings 45 and 47). `bin/rune-test
   hs-snapshot-one KIND NAME` judges one. *)
structure HsSnapshotJobs =
struct
  open Sh

  fun fail s = say ("FAIL " ^ s ^ "\n")

  val suffixes = [".hs", ".lhs"]
  val mains = ["Main.hs", "Main.lhs"]
  val kinds = ["accept", "errors", "lang"]
  val shards = 4

  fun programs kind = Lang.programsOf ("tests/hs/" ^ kind, suffixes, mains)

  fun rhc () = fromRoot "bin/rhc"

  (* the first line where `a` and `b` differ, `a` from `way`, `b` whole *)
  fun firstDifferenceBy way (a, b) =
    let
      fun go (n, x :: xs, y :: ys) = if x = y then go (n + 1, xs, ys) else (n, x, y)
        | go (n, x :: _, []) = (n, x, "(nothing)")
        | go (n, [], y :: _) = (n, "(nothing)", y)
        | go (n, [], []) = (n, "", "")
      val (n, x, y) = go (1, String.fields (fn c => c = #"\n") a, String.fields (fn c => c = #"\n") b)
    in
      "line " ^ Int.toString n ^ ": `" ^ x ^ "` " ^ way ^ ", `" ^ y ^ "` whole"
    end

  val firstDifference = firstDifferenceBy "against the snapshot"

  (* a command of rhc's on a program both ways, `way` with `flags` and
     whole: `stage` names it, `args` are its own, before the program's
     `.cargs` and file; its standard output, error and status alike *)
  fun compareStage {family : string, way : string, flags : string list} (stage, args, stdin) (kind, p : Lang.program) =
    let
      val out = run ^ "/" ^ String.translate (fn #"/" => "-" | c => str c) family ^ "/" ^ kind ^ "/" ^ #name p
      val () = mkdirs out
      val cargs = words (#base p ^ ".cargs")
      fun one (tag, flags) =
        let
          val file = out ^ "/" ^ stage ^ "-" ^ tag
          (* in a directory of its own, where a program writes its files *)
          val here = out ^ "/" ^ stage ^ "-" ^ tag ^ ".dir"
          val () = (rmTree here; mkdirs here)
          val status = exec {cmd = [rhc ()] @ flags @ args @ cargs @ [fromRoot (#src p)], dir = SOME here, stdin = stdin,
                             stdout = file ^ ".out", stderr = file ^ ".err", timeout = 600}
        in
          (status, read (file ^ ".out"), read (file ^ ".err"))
        end
      (* a check at level 2, where HsLint replays the records each way
         gives; a run and its Core at level 0, what they print the point *)
      val lint = if stage = "check" then "--lint=2" else "--lint=0"
      val (s1, o1, e1) = one ("way", flags @ [lint])
      val (s2, o2, e2) = one ("whole", ["--whole", lint])
      val what = family ^ "/" ^ kind ^ "/" ^ #name p ^ (if stage = "check" then "" else " (" ^ stage ^ ")")
    in
      if s1 <> s2 then
        fail (what ^ ": status " ^ Int.toString s1 ^ " " ^ way ^ ", " ^ Int.toString s2 ^ " whole")
      else if o1 <> o2 then fail (what ^ ": standard output: " ^ firstDifferenceBy way (o1, o2))
      else if e1 <> e2 then fail (what ^ ": standard error: " ^ firstDifferenceBy way (e1, e2))
      else ()
    end

  (* a program checked both ways: `way`, with `flags`, and whole; the
     family's jobs are `family/KIND/...` *)
  fun compareWith way (kind, p) = compareStage way ("check", ["--typecheck-only"], "") (kind, p)

  (* a run program of tests/hs/lang run both ways, on Core's interpreter,
     its `.stdin` file its standard input; with `core`, its Core too, as
     desugaring leaves it (`--desugar-only --dump-after=desugar`) *)
  fun compareRun way core (kind, p : Lang.program) =
    let val stdin = if exists (#base p ^ ".stdin") then #base p ^ ".stdin" else ""
    in
      compareStage way ("run", [], stdin) (kind, p);
      if core then compareStage way ("core", ["--desugar-only", "--dump-after=desugar"], stdin) (kind, p) else ()
    end

  val snapshot = {family = "hs/snapshot", way = "against the snapshot", flags = []}

  (* a program of the directory checked both ways *)
  fun compareOne (kind, p) = compareWith snapshot (kind, p)

  (* and for tests/hs/lang run, and its Core compared where `core` *)
  fun compareOneWith core (kind, p) =
    (compareOne (kind, p); if kind = "lang" then compareRun snapshot core (kind, p) else ())

  fun shardOf (kind, k, n) =
    let
      val ps = programs kind
      val names = sort (List.map #name ps)
      val sorted = List.mapPartial (fn nm => List.find (fn (p : Lang.program) => #name p = nm) ps) names
    in
      List.mapPartial (fn (i, p) => if i mod n = k - 1 then SOME p else NONE)
        (ListPair.zip (List.tabulate (length sorted, fn i => i), sorted))
    end

  (* a shard, every eighth program's Core compared too *)
  fun compareShard (kind, k, n) =
    List.app (fn (i, p) => compareOneWith (i mod 8 = 0) (kind, p))
      (let val ps = shardOf (kind, k, n) in ListPair.zip (List.tabulate (length ps, fn i => i), ps) end)
  (* make check's sample, checked both ways *)
  fun compareSample kind = List.app (fn p => compareOne (kind, p)) (List.filter (fn (p : Lang.program) => HsLang.sampled (#name p)) (programs kind))

  fun compareNamed (kind, name) =
    case List.find (fn (p : Lang.program) => #name p = name) (programs kind) of
      SOME p => compareOne (kind, p)
    | NONE => fail ("hs/snapshot: no program " ^ name ^ " in tests/hs/" ^ kind)

  (* the layer: of this rhc alone, and newer than what it is made of *)
  fun layer () =
    let
      val out = run ^ "/hs-snapshot"
      val () = mkdirs out
      val said = out ^ "/identity.out"
      val _ = exec {cmd = [rhc (), "--identity"], dir = SOME root, stdin = "", stdout = said, stderr = said, timeout = 300}
      val identity = firstLine said
      val dir = fromRoot "bin/rhc.layer"
      fun mtime f = OS.FileSys.modTime f
      fun files dir =
        List.concat (List.map (fn e => let val p = dir ^ "/" ^ e in if isDir p then files p else [p] end) (entries dir))
      (* the configurations of the layer, by the identity their about names *)
      val identities =
        if not (isDir dir) then []
        else List.mapPartial
          (fn c => case List.find (String.isPrefix "identity ") (lines (read (dir ^ "/" ^ c ^ "/units/about"))) of
                     SOME l => SOME (String.extract (l, size "identity ", NONE))
                   | NONE => NONE)
          (entries dir)
      val stale =
        if not (isDir dir) then []
        else List.mapPartial (fn f => if Time.> (mtime f, mtime dir) then SOME (f ^ " is newer") else NONE)
               (files (fromRoot "share/rhc"))
    in
      if not (isDir dir) then fail "hs/snapshot/layer: bin/rhc.layer is not there: make bin/rhc"
      else if identity = "" then fail ("hs/snapshot/layer: bin/rhc --identity says nothing")
      else if not (List.exists (fn i => i = identity) identities) then
        fail ("hs/snapshot/layer: bin/rhc.layer holds no unit of this rhc (identity " ^ identity ^ "): make bin/rhc")
      else
        case List.filter (fn i => i <> identity) identities of
          [] => ()
        | i :: _ => fail ("hs/snapshot/layer: bin/rhc.layer holds units of another rhc (identity " ^ i ^ ")");
      case stale of
        [] => ()
      | f :: _ => fail ("hs/snapshot/layer: bin/rhc.layer is stale, " ^ f ^ ": make bin/rhc")
    end

  (* ---- the tree ---- *)

  fun job (name, cmd, timeout) =
    Test.it name
      {program = "/bin/sh", args = ["sh", "-c", "exec " ^ cmd],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = 500,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*", "covers:tests/hs/accept/*",
                "covers:tests/hs/lang/*", "covers:tests/hs/errors/*", "covers:tests/runner/hssnapshot.sml",
                "covers:rhc.build", "covers:rhc.plan"]

  fun tree () =
    let
      val cmd = "\"$RUNE_TEST_ROOT\"/bin/rune-test "
      (* tests/hs/lang's, which run and compare Core too, in twice as many *)
      fun shardsOf kind = if kind = "lang" then 2 * shards else shards
      fun shardJobs kind =
        Test.tag "check" (job (kind ^ "/sample", cmd ^ "hs-snapshot-shard " ^ kind ^ " sample", 3600))
        :: List.tabulate (shardsOf kind, fn i =>
                                    let val k = Int.toString (i + 1) ^ "-of-" ^ Int.toString (shardsOf kind)
                                    in Test.tag "nightly" (job (kind ^ "/" ^ k, cmd ^ "hs-snapshot-shard " ^ kind ^ " " ^ k, 3600)) end)
    in
      Test.describe "hs/snapshot"
        [tagged (["hs"] @ covers)
           (Test.requires ["rhc"]
              (Test.describe ""
                 (Test.tag "check" (job ("layer", cmd ^ "hs-snapshot-layer", 300))
                  :: List.concat (List.map shardJobs kinds))))]
    end

  fun command args =
    case args of
      ["hs-snapshot-layer"] => SOME layer
    | ["hs-snapshot-one", kind, name] => SOME (fn () => compareNamed (kind, name))
    | ["hs-snapshot-shard", kind, "sample"] => SOME (fn () => compareSample kind)
    | ["hs-snapshot-shard", kind, kn] =>
        (case String.fields (fn c => c = #"-") kn of
           [k, "of", n] =>
             (case (Int.fromString k, Int.fromString n) of
                (SOME k, SOME n) => SOME (fn () => compareShard (kind, k, n))
              | _ => NONE)
         | _ => NONE)
    | _ => NONE
end
