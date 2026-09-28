(* The runner (docs/plans/quickcheck.md, D9 and D13). Case k of a run has the
   k-th word of the run's generator as its seed, and the size k * maxSize /
   (tests - 1). *)

(* Implements: CHECK *)
structure Check :> CHECK =
struct
  structure S = PropertySource

  type config = {seed : Word64.word option, tests : int, maxSize : int, maxDiscards : int}

  val default : config = {seed = NONE, tests = 100, maxSize = 100, maxDiscards = 1000}

  datatype result =
      Passed of {tests : int, discarded : int, labels : (string * int) list, short : (string * real * real) list}
    | Failed of {test : int, size : int, class : string, message : string, counterexample : string list,
                 replay : string}
    | GaveUp of {tests : int, discarded : int}

  fun hex (w : Word64.word) : string = StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX w)

  fun token (seed : Word64.word, size : int) : string = hex seed ^ ":" ^ Int.toString size

  fun count (m : (string * int) list, l : string) : (string * int) list =
    case List.partition (fn (l', _) => l' = l) m of
      ([(_, n)], rest) => (l, n + 1) :: rest
    | _ => (l, 1) :: m

  fun check ({seed, tests, maxSize, maxDiscards} : config) (name : string) (p : Prop.prop) : result =
    let
      val seed = case seed of SOME s => s | NONE => Random.hashString name
      fun sizeOf k = if tests <= 1 then maxSize else Int.min (k, tests - 1) * maxSize div (tests - 1)
      fun loop (g, passed, discarded, labels, covers) =
        if passed >= tests then
          let
            (* the coverage asked for, and what the run had *)
            val asked = List.foldl (fn ((l, pct, _), m) => if List.exists (fn (l', _) => l' = l) m then m else (l, pct) :: m)
                                   [] covers
            val short =
              List.mapPartial (fn (l, pct) =>
                                 let val had = 100.0 * real (List.length (List.filter (fn (l', _, b) => l' = l andalso b) covers))
                                               / real (Int.max (passed, 1))
                                 in if had < pct then SOME (l, pct, had) else NONE end)
                              asked
          in
            Passed {tests = passed, discarded = discarded, labels = labels, short = short}
          end
        else if discarded > maxDiscards then GaveUp {tests = passed, discarded = discarded}
        else
          let
            val (caseSeed, g) = Random.word64 g
            val size = sizeOf passed
            val r = Prop.run p (S.new (caseSeed, size, []), S.root)
          in
            case #verdict r of
              Prop.Pass => loop (g, passed + 1, discarded, List.foldl (fn (l, m) => count (m, l)) labels (#labels r),
                                  #covers r @ covers)
            | Prop.Discard => loop (g, passed, discarded + 1, labels, covers)
            | Prop.Fail {class, message} =>
                Failed {test = passed + discarded, size = size, class = class, message = message,
                        counterexample = #shown r, replay = token (caseSeed, size)}
          end
    in
      loop (Random.fromSeed seed, 0, 0, [], [])
    end

  fun replay (t : string) (p : Prop.prop) : Prop.result option =
    case String.fields (fn c => c = #":") t of
      [s, n] =>
        (case (StringCvt.scanString (Word64.scan StringCvt.HEX) s, Int.fromString n) of
           (SOME seed, SOME size) => SOME (Prop.run p (S.new (seed, size, []), S.root))
         | _ => NONE)
    | _ => NONE

  fun passed (Passed {short, ...}) = List.null short
    | passed _ = false

  fun pct (x : real) : string = Real.fmt (StringCvt.FIX (SOME 1)) x ^ "%"

  fun report (name : string) (r : result) : string =
    case r of
      Passed {tests, discarded, labels, short} =>
        (if List.null short then "PASS " else "FAIL ") ^ name ^ ": " ^ Int.toString tests ^ " cases"
        ^ (if discarded > 0 then ", " ^ Int.toString discarded ^ " discarded" else "") ^ "\n"
        ^ String.concat (List.map (fn (l, n) => "  " ^ pct (100.0 * real n / real (Int.max (tests, 1))) ^ " " ^ l ^ "\n")
                                  (List.rev labels))
        ^ String.concat (List.map (fn (l, want, had) => "  coverage of " ^ l ^ ": " ^ pct had ^ ", asked " ^ pct want ^ "\n")
                                  short)
    | Failed {test, size, class, message, counterexample, replay} =>
        "FAIL " ^ name ^ ": " ^ class ^ " at case " ^ Int.toString (test + 1) ^ " (size " ^ Int.toString size ^ ")"
        ^ (if message = "" then "" else ": " ^ message) ^ "\n"
        ^ String.concat (List.map (fn x => "  " ^ x ^ "\n") counterexample)
        ^ "  replay " ^ replay ^ "\n"
    | GaveUp {tests, discarded} =>
        "FAIL " ^ name ^ ": gave up after " ^ Int.toString tests ^ " cases and " ^ Int.toString discarded
        ^ " discarded\n"

  fun main (ps : (string * Prop.prop) list) : unit =
    let
      val results = List.map (fn (name, p) => let val r = check default name p in print (report name r); r end) ps
    in
      if List.all passed results then () else OS.Process.exit OS.Process.failure
    end
end
