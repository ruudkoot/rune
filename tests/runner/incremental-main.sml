structure IncrementalMain =
struct
  open Sh
  exception Usage of string
  fun natural text = case Int.fromString text of SOME n => if n >= 0 then n else raise Usage "negative count" | NONE => raise Usage "invalid count"
  fun mutations args =
    let val compiler = ref "bin/rune"
        val directory = ref (run ^ "/mutate")
        val flags = ref []
        val basis = ref []
        val steps = ref 50
        val seed = ref (0w1 : Word64.word)
        val history = ref 0
        val repo = ref root
        val projects = ref []
        val replay = ref false
        fun parse [] = ()
          | parse ("--rune" :: value :: rest) = (compiler := value; parse rest)
          | parse ("--out" :: value :: rest) = (directory := fromRoot value; parse rest)
          | parse ("--steps" :: value :: rest) = (steps := natural value; parse rest)
          | parse ("--seed" :: value :: rest) = (seed := (case IntInf.fromString value of SOME n => Word64.fromLargeInt n | NONE => raise Usage "invalid seed"); parse rest)
          | parse ("--flags" :: value :: rest) = (flags := String.tokens Char.isSpace value; parse rest)
          | parse ("--basis" :: value :: rest) = (basis := String.tokens (fn c => c = #",") value; parse rest)
          | parse ("--history" :: value :: rest) = (history := natural value; parse rest)
          | parse ("--repo" :: value :: rest) = (repo := fromRoot value; parse rest)
          | parse ("--replay-v1" :: rest) = (replay := true; parse rest)
          | parse (arg :: rest) = if String.isPrefix "--flags=" arg then (flags := String.tokens Char.isSpace (String.extract (arg,8,NONE)); parse rest)
              else if String.isPrefix "-" arg then raise Usage ("unknown or incomplete option " ^ arg)
              else (projects := !projects @ [arg]; parse rest)
        val () = parse args
        val directory = OS.Path.mkCanonical (!directory)
        val () = if String.isPrefix (root ^ "/tests/out/") directory orelse String.isPrefix (run ^ "/") directory then ()
                 else raise Usage "mutation output must be a private test results directory"
        val () = (rmTree directory; mkdirs directory)
    in if !replay then MutationChecks.replay (!compiler) directory (fromRoot "tests/runner/incremental-edits-v1.json") else
       let val checker = MutationChecks.create (!compiler) directory (!flags)
           val generator = ref (Random.fromSeed (!seed))
           val () = if !history = 0 then () else MutationHistory.replay checker (!repo) (!history)
           fun project spec =
             let val sources = if spec = "compiler" then MutationHistory.compilerSources (!compiler) else
                   let val dir = fromRoot spec
                       val () = if exists (dir ^ "/files") then () else raise Usage ("missing project file list: " ^ dir)
                   in List.map (fn file => (file,CachePlant.binary (dir ^ "/" ^ file))) (words (dir ^ "/files")) end
             in MutationChecks.generate checker generator (!steps) spec sources (!basis) end
           val () = List.app project (!projects)
       in MutationChecks.summary checker end
    end
  (* soundness --old BIN --new BIN [--steps N] [--seed S] [--weaken N] [--out DIR] [--probes]
     [--expect-violations] PROJECT...: the old and new compilers'
     fingerprints over each project's edits and over issue 16's probes
     (Soundness); with --expect-violations it succeeds where it finds some,
     which is how the check itself is tested against a weak hash *)
  fun soundness args =
    let val old = ref "bin/rune"
        val new = ref "bin/rune"
        val directory = ref (run ^ "/soundness")
        val steps = ref 30
        val seed = ref (0w1 : Word64.word)
        val weaken = ref NONE
        val probes = ref false
        val expect = ref false
        val projects = ref []
        fun parse [] = ()
          | parse ("--old" :: value :: rest) = (old := value; parse rest)
          | parse ("--new" :: value :: rest) = (new := value; parse rest)
          | parse ("--out" :: value :: rest) = (directory := fromRoot value; parse rest)
          | parse ("--steps" :: value :: rest) = (steps := natural value; parse rest)
          | parse ("--seed" :: value :: rest) = (seed := (case IntInf.fromString value of SOME n => Word64.fromLargeInt n | NONE => raise Usage "invalid seed"); parse rest)
          | parse ("--weaken" :: value :: rest) = (weaken := SOME (natural value); parse rest)
          | parse ("--probes" :: rest) = (probes := true; parse rest)
          | parse ("--expect-violations" :: rest) = (expect := true; parse rest)
          | parse (arg :: rest) = if String.isPrefix "-" arg then raise Usage ("unknown or incomplete option " ^ arg)
                                  else (projects := !projects @ [arg]; parse rest)
        val () = parse args
        val directory = OS.Path.mkCanonical (!directory)
        val () = if String.isPrefix (root ^ "/tests/out/") directory orelse String.isPrefix (run ^ "/") directory then ()
                 else raise Usage "soundness output must be a private test results directory"
        val () = (rmTree directory; mkdirs directory)
        val oldSide = {compiler = !old, weaken = NONE} : Soundness.side
        val newSide = {compiler = !new, weaken = !weaken} : Soundness.side
        val t = Soundness.tally ()
        val generator = ref (Random.fromSeed (!seed))
        fun project spec =
          let val sources = if spec = "compiler" then MutationHistory.compilerSources (!new) else
                let val dir = fromRoot spec
                    val () = if exists (dir ^ "/files") then () else raise Usage ("missing project file list: " ^ dir)
                in List.map (fn file => (file, CachePlant.binary (dir ^ "/" ^ file))) (words (dir ^ "/files")) end
          in Soundness.project t oldSide newSide (directory ^ "/work-" ^ OS.Path.file spec) generator (!steps) (spec, sources) end
        val () = if !probes then List.app (Soundness.probe t oldSide newSide directory) Soundness.probes else ()
        val () = List.app project (!projects)
    in
      Soundness.summary t;
      if !expect then (if !(#violations t) > 0 then () else raise Incremental.Failed "the check found no violation of a weak hash")
      else if !(#violations t) = 0 then () else raise Incremental.Failed "fingerprint soundness violations"
    end
  fun scenarios args =
    let val compiler = ref "bin/rune"
        val filter = ref ""
        fun parse [] = ()
          | parse ("--rune" :: value :: rest) = (compiler := value; parse rest)
          | parse (arg :: rest) = if String.isPrefix "-" arg then raise Usage ("unknown scenario option " ^ arg) else (filter := arg; parse rest)
        val () = parse args
        val names = List.filter (String.isSubstring (!filter)) IncrementalExtra.cases
        val () = if null names then raise Usage "no incremental scenario matches" else ()
    in List.app (fn name => IncrementalExtra.runCase name (!compiler)) names end
  fun main ["faults"] = IncrementalFaults.one ()
    | main ["mlton",source] = MLtonIncremental.run source "tests/out/mlton"
    | main ["mlton",source,output] = MLtonIncremental.run source output
    | main ("scenarios" :: args) = scenarios args
    | main ("mutate" :: args) = mutations args
    | main ("soundness" :: args) = soundness args
    | main ["one",name,compiler] = IncrementalExtra.runCase name compiler
    | main ("plant" :: args) = CachePlant.command args
    | main _ = raise Usage "scenarios [--rune BIN] [FILTER] | mutate [OPTIONS] PROJECT... | soundness [OPTIONS] PROJECT... | plant [OPTIONS]"
end
val () =
  let fun message (IncrementalMain.Usage text)=text
        | message (Incremental.Failed text)=text
        | message (MLtonIncremental.Failed text)=text
        | message (CachePlant.Invalid text)=text
        | message e=General.exnMessage e
  in IncrementalMain.main (CommandLine.arguments ()) handle e =>
       (Sh.say ("FAIL incremental controller: " ^ message e ^ "\n"); Posix.Process.exit 0w1) end
