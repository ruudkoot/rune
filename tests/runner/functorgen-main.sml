(* bin/rune-functor-gen: the generated programs of functors (FunctorGen;
   docs/testing.md, *Generated functor programs* there).

     check [--seed N] [--seeds K] [--count N] [--max-size N] [--shrinks N]
           [--known FILE] [--rune BIN] [--vm BIN] [--memory KB] [--timeout S]
           [--out DIR]
       runs K runs (1 by default) of N programs each (25), from the seeds N
       to N + K - 1, each program in every mode; a failure is shrunk and
       kept under DIR/failures, and the run goes on with the next seed. A
       failure FILE's lines know (tests/functors/known.txt) is counted and
       not failed. Exits 0 when every run passed.
     regressions [--known FILE] [OPTIONS] DIR
       runs each program of DIR (tests/functors) in every mode: each must
       pass, or fail as a line of FILE says; and each line must be met by a
       program, or it is stale.
     show [--seed N] [--size N]
       prints the program of a case, as a failure's replay token HEX:SIZE
       names it with --seed 0xHEX.
     run [OPTIONS] FILE
       runs a program as `show` prints it, or as a failure keeps it
       (program.sml), in every mode, and keeps it and what each mode did in
       DIR (modes.txt). *)
structure FunctorGenMain =
struct
  exception Usage of string

  fun natural text =
    case Int.fromString text of
      SOME n => if n >= 0 then n else raise Usage ("not a count: " ^ text)
    | NONE => raise Usage ("not a count: " ^ text)
  fun seedOf text =
    if String.isPrefix "0x" text then
      case StringCvt.scanString (Word64.scan StringCvt.HEX) (String.extract (text, 2, NONE)) of
        SOME w => w
      | NONE => raise Usage ("not a seed: " ^ text)
    else Word64.fromInt (natural text)

  type options = {seed : string, seeds : int, count : int, maxSize : int, shrinks : int, rune : string, vm : string,
                  memory : int, timeout : int, out : string, size : int, files : string list, known : string}

  fun parse args =
    let
      val seed = ref "1" and seeds = ref 1 and count = ref 25 and maxSize = ref 100 and shrinks = ref 400
      val rune = ref "bin/rune" and vm = ref "bin/runevm" and memory = ref 6000000 and timeout = ref 60
      val out = ref (Sh.run ^ "/functors") and size = ref 50 and files = ref [] and known = ref ""
      fun go [] = ()
        | go ("--seed" :: v :: rest) = (seed := v; go rest)
        | go ("--seeds" :: v :: rest) = (seeds := natural v; go rest)
        | go ("--count" :: v :: rest) = (count := natural v; go rest)
        | go ("--max-size" :: v :: rest) = (maxSize := natural v; go rest)
        | go ("--shrinks" :: v :: rest) = (shrinks := natural v; go rest)
        | go ("--rune" :: v :: rest) = (rune := v; go rest)
        | go ("--vm" :: v :: rest) = (vm := v; go rest)
        | go ("--memory" :: v :: rest) = (memory := natural v; go rest)
        | go ("--timeout" :: v :: rest) = (timeout := natural v; go rest)
        | go ("--out" :: v :: rest) = (out := Sh.fromRoot v; go rest)
        | go ("--size" :: v :: rest) = (size := natural v; go rest)
        | go ("--known" :: v :: rest) = (known := v; go rest)
        | go (a :: rest) = if String.isPrefix "-" a then raise Usage ("unknown or incomplete option " ^ a)
                           else (files := !files @ [a]; go rest)
    in
      go args;
      {seed = !seed, seeds = !seeds, count = !count, maxSize = !maxSize, shrinks = !shrinks, rune = !rune, vm = !vm,
       memory = !memory, timeout = !timeout, out = !out, size = !size, files = !files, known = !known} : options
    end

  fun config (o' : options) : FunctorGen.config = {rune = #rune o', vm = #vm o', memory = #memory o', timeout = #timeout o'}
  fun known (o' : options) = if #known o' = "" then [] else FunctorGen.readKnown (Sh.fromRoot (#known o'))

  fun check args =
    let
      val o' = parse args
      val first = Word64.toInt (seedOf (#seed o'))
      val () = Sh.mkdirs (#out o')
      val results = List.tabulate (#seeds o', fn i =>
                                     FunctorGen.check (config o')
                                                      {seed = first + i, count = #count o', maxSize = #maxSize o',
                                                       shrinks = #shrinks o', out = #out o', known = known o'})
      val failed = List.length (List.filter not results)
    in
      Sh.say ("functor programs: " ^ Int.toString (#seeds o' * #count o') ^ " asked in " ^ Int.toString (#seeds o')
              ^ " runs from seed " ^ Int.toString first ^ ", " ^ Int.toString failed ^ " runs failed\n");
      if failed = 0 then () else Posix.Process.exit 0w1
    end

  fun show args =
    let val o' = parse args
    in print (FunctorGen.show (FunctorGen.sample (seedOf (#seed o'), #size o'))) end

  fun runOne args =
    let
      val o' = parse args
      val file = case #files o' of [f] => f | _ => raise Usage "run takes one program"
      val dir = #out o'
      val (verdict, hits) = FunctorGen.keep (config o', dir ^ "/work", dir, FunctorGen.parse (Sh.read file), known o', "")
    in
      Sh.rmTree (dir ^ "/work");
      List.app (fn k => Sh.say ("known: " ^ FunctorGen.describeKnown k ^ "\n")) hits;
      case verdict of
        NONE => Sh.say ("PASS " ^ file ^ " (" ^ dir ^ "/modes.txt)\n")
      | SOME (k, m, why) => (Sh.say ("FAIL " ^ file ^ ": " ^ k ^ " in " ^ m ^ ": " ^ why ^ " (" ^ dir ^ "/modes.txt)\n");
                             Posix.Process.exit 0w1)
    end

  fun regressions args =
    let
      val o' = parse args
      val dir = case #files o' of [d] => Sh.fromRoot d | _ => raise Usage "regressions takes one directory"
      val () = Sh.mkdirs (#out o')
    in if FunctorGen.regressions (config o', dir, #out o', known o') then () else Posix.Process.exit 0w1 end

  fun main ("check" :: args) = check args
    | main ("show" :: args) = show args
    | main ("run" :: args) = runOne args
    | main ("regressions" :: args) = regressions args
    | main _ = raise Usage "check [OPTIONS] | regressions [OPTIONS] DIR | show [--seed N] [--size N] | run [OPTIONS] FILE"
end
val () =
  FunctorGenMain.main (CommandLine.arguments ())
  handle FunctorGenMain.Usage text => (Sh.say ("rune-functor-gen: " ^ text ^ "\n"); Posix.Process.exit 0w2)
