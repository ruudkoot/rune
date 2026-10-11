(* Parallel builds (the incremental roadmap's M11): with -j N, units are
   compiled by child processes, and the cache is how they hand them on.

   The parent goes through the units in order, each through the cache, as a
   build without -j does. Before each, it forks a child for every unit after
   it that will likely be compiled -- one with no entry in the cache, or one
   that needs a unit compiled in this build -- whose units before it are
   done, and that is big enough to be worth a process, up to N at once. A
   unit the parent reaches and misses it compiles itself, unless a child has
   it, whose end it waits for. A unit needs the units before it that declare
   a name it uses (Deps, by name; a unit that breaks the discipline, and an
   `always` file of the Basis, is needed by every unit after it, and needs
   every one before it).

   A child is the parent's copy at the unit it was forked at, with all of
   the parent's basis: it goes on through the units that its own needs,
   which the cache has, skips the others, compiles its unit into the cache
   and exits. What the build gives is what the parent's pass gives, which is
   a build without -j: an entry that a child compiled without some unit in
   its basis is one whose usages the parent checks, and compiles again
   where they do not hold. *)
structure Parallel =
struct
  structure P = Posix.Process

  (* a unit's child: running, with the file its output goes to; done, and
     whether it compiled the unit or found it in the cache; failed *)
  datatype state = Pending | Running of P.pid * string | Done of string * bool | Failed

  datatype action = Run of {quiet : bool} | Skip | Compile

  val names : string vector ref = ref (Vector.fromList [])
  val needs : int list vector ref = ref (Vector.fromList [])
  val index : int StringMap.map ref = ref StringMap.empty
  val states : state array ref = ref (Array.fromList [])
  (* the units compiled in this build, by the parent or a child *)
  val compiled : bool array ref = ref (Array.fromList [])
  (* whether the cache has an entry of the unit, whatever its usages, and
     whether it is worth a child: a child costs a fork, its collections over
     pages it shares with the parent, and the parent's reading of what it
     compiled, which is about what compiling a small unit costs *)
  val hasEntry : (int -> bool) ref = ref (fn _ => false)
  val worth : (int -> bool) ref = ref (fn _ => true)
  val explain : bool ref = ref false
  val jobs = ref 1
  val running = ref 0
  val active = ref false
  (* in a child: the units it goes through, and the one it was forked for *)
  val child : (bool array * int) option ref = ref NONE
  exception Forked

  (* units: each unit's name, the names it declares and uses, and whether
     every unit after it needs it *)
  fun start {units : (string * string list * string list * bool) list, jobs = j : int, hasEntry = h,
             worth = w : int -> bool, explain = e : bool} : unit =
    let
      val n = List.length units
      fun go ([], _, _, _, acc) = List.rev acc
        | go ((_, declares, uses, global) :: rest, i, latest, globals, acc) =
            let
              val deps = if global then List.tabulate (i, fn j => j)
                         else globals @ List.mapPartial (fn u => StringMap.find (latest, u)) uses
              val deps = List.foldl (fn (d, m) => IntMap.insert (m, d, ())) IntMap.empty deps
              val latest = List.foldl (fn (d, m) => StringMap.insert (m, d, i)) latest declares
            in go (rest, i + 1, latest, if global then i :: globals else globals, IntMap.listKeys deps :: acc) end
    in
      names := Vector.fromList (List.map #1 units);
      needs := Vector.fromList (go (units, 0, StringMap.empty, [], []));
      index := List.foldl (fn ((name, i), m) => if isSome (StringMap.find (m, name)) then m else StringMap.insert (m, name, i))
                          StringMap.empty (ListPair.zip (List.map #1 units, List.tabulate (n, fn i => i)));
      states := Array.array (n, Pending);
      compiled := Array.array (n, false);
      (* asked once a unit: it hashes the unit's text *)
      hasEntry := (let val known = Array.array (n, NONE)
                   in fn i => case Array.sub (known, i) of
                                SOME b => b
                              | NONE => let val b = h i in Array.update (known, i, SOME b); b end
                   end);
      worth := w;
      explain := e;
      jobs := j;
      running := 0;
      active := (n > 1 andalso j > 1)
    end

  fun state i = Array.sub (!states, i)
  (* RUNE_PARALLEL_DEBUG set: each child's start and end, on stderr *)
  val debug = isSome (OS.Process.getEnv "RUNE_PARALLEL_DEBUG")
  fun say m = if debug then TextIO.output (TextIO.stdErr, "parallel: " ^ m ^ "\n") else ()

  (* the units a child for i goes through: i and those it needs, all the way *)
  fun closure i =
    let
      val keep = Array.array (Vector.length (!names), false)
      fun visit j = if Array.sub (keep, j) then () else (Array.update (keep, j, true); List.app visit (Vector.sub (!needs, j)))
    in visit i; keep end

  fun remove f = OS.FileSys.remove f handle OS.SysErr _ => ()

  (* a child's end: its unit compiled, found, or neither *)
  fun mark (pid, status) =
    let
      val n = Vector.length (!names)
      fun find i = if i >= n then NONE
                   else case state i of Running (p, log) => if p = pid then SOME (i, log) else find (i + 1) | _ => find (i + 1)
    in
      case find 0 of
        NONE => ()
      | SOME (i, log) =>
          (running := !running - 1;
           say ("end " ^ Int.toString i ^ (case status of P.W_EXITED => " compiled" | P.W_EXITSTATUS w => " status " ^ Word8.toString w
                                                          | _ => " signal"));
           case status of
             P.W_EXITED => (Array.update (!states, i, Done (log, true)); Array.update (!compiled, i, true))
           | P.W_EXITSTATUS 0w2 => Array.update (!states, i, Done (log, false))
           | _ => (remove log; Array.update (!states, i, Failed)))
    end

  fun reap () = if !running = 0 then () else case P.waitpid_nh (P.W_ANY_CHILD, []) of SOME r => (mark r; reap ()) | NONE => ()
  fun wait () = if !running > 0 then mark (P.waitpid (P.W_ANY_CHILD, [])) else ()

  (* the child's output to its file, which the parent reads for
     --explain-rebuild *)
  fun redirect log =
    let val fd = Posix.FileSys.creat (log, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
    in Posix.IO.dup2 {old = fd, new = Posix.FileSys.stdout}; Posix.IO.dup2 {old = fd, new = Posix.FileSys.stderr};
       Posix.IO.close fd
    end

  fun fork i =
    let
      val log = OS.FileSys.tmpName ()
      val () = (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr)
    in
      case P.fork () of
        SOME pid => (say ("fork " ^ Int.toString i ^ " " ^ Vector.sub (!names, i));
                     Array.update (!states, i, Running (pid, log)); running := !running + 1)
      | NONE => (redirect log; child := SOME (closure i, i); active := false; raise Forked)
    end

  (* the units from p on that a child may start now: what they need done,
     and likely to be compiled; one whose need failed fails *)
  fun launch (p, from) =
    let
      val n = Vector.length (!names)
      fun go i =
        if i >= n orelse !running >= !jobs then ()
        else
          (case state i of
             Pending =>
               let val ds = Vector.sub (!needs, i)
               in
                 if List.exists (fn d => d >= p andalso state d = Failed) ds then Array.update (!states, i, Failed)
                 else if !worth i
                         andalso List.all (fn d => d < p orelse (case state d of Done _ => true | _ => false)) ds
                         andalso (not (!hasEntry i) orelse List.exists (fn d => Array.sub (!compiled, d)) ds)
                 then fork i
                 else ()
               end
           | _ => ();
           go (i + 1))
    in go from end

  (* what a child does at unit p: go through it where its unit needs it *)
  fun inChild p = case !child of SOME (keep, _) => if Array.sub (keep, p) then Run {quiet = false} else Skip
                               | NONE => Run {quiet = false}

  (* the parent at p, its child done: what it printed for --explain-rebuild *)
  fun taken p =
    case state p of
      Done (log, compiledIt) =>
        ((if !explain andalso compiledIt then
           (let
              val s = TextIO.openIn log
              fun go () = case TextIO.inputLine s of
                            NONE => ()
                          | SOME l => (if String.isPrefix "rune: compiled " l then TextIO.output (TextIO.stdErr, l) else (); go ())
            in go (); TextIO.closeIn s end)
           handle IO.Io _ => ()
         else ();
         remove log;
         Array.update (!states, p, Done ("", compiledIt));
         Run {quiet = compiledIt}))
    | _ => Run {quiet = false}

  (* until p's child is done, others started as they can *)
  fun waitFor p =
    case state p of
      Running _ => (wait (); reap (); launch (p, p + 1); waitFor p)
    | _ => ()

  (* before unit `name`, which the parent goes through next *)
  fun at (name : string) : action =
    case (StringMap.find (!index, name), !child) of
      (NONE, _) => Run {quiet = false}
    | (SOME p, SOME _) => inChild p
    | (SOME p, NONE) =>
        if not (!active) then Run {quiet = false}
        else if !Error.errors > 0 then (active := false; Run {quiet = false})
        else ((reap (); launch (p, p + 1); waitFor p; taken p) handle Forked => inChild p)

  (* the parent missed unit `name` in the cache: it compiles it itself,
     having started the children it can for the units after it, unless a
     child has the unit, whose end it waits for and then looks again *)
  fun missed (name : string) : action =
    case (StringMap.find (!index, name), !child) of
      (SOME p, NONE) =>
        if not (!active) orelse !Error.errors > 0 then Compile
        else
          ((reap (); launch (p, p + 1);
            case state p of
              Running _ => (waitFor p; case state p of Done _ => taken p | _ => Compile)
            | _ => Compile)
           handle Forked => inChild p)
    | _ => Compile

  (* after unit `name`: a child ends with its own unit, 0 where it compiled
     it, 2 where it found it, 1 where it failed *)
  fun after (name : string, compiledIt : bool) : unit =
    case (StringMap.find (!index, name), !child) of
      (SOME p, SOME (_, target)) =>
        if p <> target then ()
        else (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr;
              P.exit (if !Error.errors > 0 then 0w1 else if compiledIt then 0w0 else 0w2))
    | (SOME p, NONE) => if compiledIt andalso !active then Array.update (!compiled, p, true) else ()
    | _ => ()

  (* the build over: the children left waited for, their files removed *)
  fun finish () =
    if isSome (!child) then ()
    else
      (while !running > 0 do wait ();
       Array.app (fn Done (log, _) => if log = "" then () else remove log | _ => ()) (!states);
       active := false)
end
