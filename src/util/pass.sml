(* The passes of the compiler and what can be asked of each
   (docs/plans/middle-end.md, M2; docs/ir.md): every stage from one
   intermediate representation to the next is run by `stage`, which prints
   it before or after when asked (--dump-before, --dump-after), checks what
   it made (--lint), and says what it cost (--pass-stats). A pass that
   rewrites asks `spend` before each rewrite, so that --fuel can stop the
   rewriting after N of them: halving N finds the one rewrite that breaks a
   program (scripts/bisect-fuel.sh). *)
structure Pass =
struct
  (* The optimisation level, -O0 to -O2, and the options of the passes. *)
  val level = ref 1
  val only : string list option ref = ref NONE     (* --passes: the optional passes to run *)
  val dumpBefore : string list ref = ref []
  val dumpAfter : string list ref = ref []
  val lint = ref false
  val stats = ref false
  val fuel : int option ref = ref NONE

  (* Whether an optional pass runs at the level given: --passes names the
     ones to run, whatever the level; otherwise a pass runs from its level
     up. *)
  fun enabled (name : string, fromLevel : int) : bool =
    case !only of
      SOME names => List.exists (fn n => n = name) names
    | NONE => !level >= fromLevel

  (* Whether a rewrite may be made: always, unless --fuel has run out. *)
  fun spend () : bool =
    case !fuel of
      NONE => true
    | SOME 0 => false
    | SOME n => (fuel := SOME (n - 1); true)

  fun asked (names : string list ref, name : string) =
    List.exists (fn n => n = name orelse n = "all") (!names)

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  (* Run a stage of the pipeline: `name` for the options, `show` to print
     what it made, `check` its lint (raising Error.Bug), `size` a count of
     what it made for --pass-stats. The input is printed with --dump-before
     by the stage before's `show`, which the caller passes as `showIn`. *)
  fun stage {name : string, showIn : ('a -> string) option, show : 'b -> string, check : 'b -> unit,
             size : 'b -> int}
            (f : 'a -> 'b) (x : 'a) : 'b =
    let
      val () =
        case showIn of
          SOME s => if asked (dumpBefore, name) then print ("(* before " ^ name ^ " *)\n" ^ s x ^ "\n") else ()
        | NONE => ()
      val timer = Timer.startCPUTimer ()
      val y = f x
      val {usr, sys} = Timer.checkCPUTimer timer
      val () =
        if !stats then
          eprint ("pass " ^ name ^ ": " ^ Int.toString (size y) ^ " nodes, "
                  ^ Time.toString (Time.+ (usr, sys)) ^ " s\n")
        else ()
      val () = if asked (dumpAfter, name) then print ("(* after " ^ name ^ " *)\n" ^ show y ^ "\n") else ()
      val () =
        if !lint then (check y handle Error.Bug msg => raise Error.Bug ("lint after " ^ name ^ ": " ^ msg))
        else ()
    in
      y
    end
end
