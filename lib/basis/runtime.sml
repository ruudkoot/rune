(* Runtime: what the VM counts, for the program it is running (Rune's own, not
   of the specification). Each counter is a primitive that reads a field of
   the VM and allocates nothing, so the nine are read without disturbing
   eight of them. *)
structure RuneRuntime =
struct
  local
    val instructions' = _prim "rt_instructions" : unit -> int
    val bytes' = _prim "rt_bytes" : unit -> int
    val objects' = _prim "rt_objects" : unit -> int
    val collections' = _prim "rt_collections" : unit -> int
    val live' = _prim "rt_live" : unit -> int
    val heapSize' = _prim "rt_heap_size" : unit -> int
    val minors' = _prim "rt_minor_collections" : unit -> int
    val majors' = _prim "rt_major_collections" : unit -> int
    val promoted' = _prim "rt_promoted" : unit -> int
    val collect' = _prim "rt_collect" : unit -> unit
    val share' = _prim "rt_share" : unit -> int
    val version' = _prim "rt_version" : unit -> string
    val trace' = _prim "rt_trace" : int -> (string * string * int * int) list
    val save' = _prim "rt_save" : string -> int
    val restore' = _prim "rt_restore" : string -> int
    val link' = _prim "rt_link" : string -> (unit -> unit) option
    val linkError' = _prim "rt_link_error" : unit -> string
    val catchInterrupt' = _prim "rt_interrupt_catch" : exn -> bool
    val maskInterrupt' = _prim "rt_interrupt_mask" : bool -> bool
    val raiseMark' = _prim "rt_raise_mark" : int -> int
    val raiseTrace' = _prim "rt_raise_trace" : unit -> (string * string * int * int) list
    val debugHook' = _prim "rt_debug_hook" : (int -> unit) -> bool
    val debugMode' = _prim "rt_debug_mode" : int -> int
    val debugUser' = _prim "rt_debug_user" : unit -> unit
    val debugBreak' = _prim "rt_debug_break" : string * int * bool -> int
    val debugStep' = _prim "rt_debug_step" : int -> unit
    val debugFrames' = _prim "rt_debug_frames" : unit -> (int * string * string * int * int) list
    val debugWhere' = _prim "rt_debug_where" : int -> int * int
    val debugLive' = _prim "rt_debug_live" : int * int -> int
    val debugExn' = _prim "rt_debug_exn" : unit -> exn
    val debugProgram' = _prim "rt_debug_program" : unit -> int
    val randomBytes' = _prim "rt_random_bytes" : int -> string
    val eventNew' = _prim "win_event_new" : unit -> int
    val eventSet' = _prim "win_event_set" : int -> bool
    val spawn' = _prim "posix_spawn" : string * string list * string list * int * int list -> int
  in
    type stats = { instructions : int, bytes : int, objects : int,
                   collections : int, live : int, heapSize : int,
                   minorCollections : int, majorCollections : int, promoted : int }

    (* The heap's eight are read first and the instruction count last, so
       that it counts as much of this call as it can. *)
    fun stats () : stats =
      let
        val b = bytes' ()
        val ob = objects' ()
        val c = collections' ()
        val l = live' ()
        val h = heapSize' ()
        val mi = minors' ()
        val ma = majors' ()
        val p = promoted' ()
      in
        {instructions = instructions' (), bytes = b, objects = ob,
         collections = c, live = l, heapSize = h,
         minorCollections = mi, majorCollections = ma, promoted = p}
      end

    fun collect () = collect' ()

    fun share () = share' ()

    type frame = { function : string, file : string, line : int, column : int }

    (* The primitive leaves out the innermost frames, which are this
       structure's own: `trace` is one, and `printTrace` calling it is two. A
       program should see its own call stack and nothing of the library's. *)
    fun frames n : frame list =
      List.map (fn (f, file, line, col) =>
                  {function = f, file = file, line = line, column = col})
               (trace' n)

    fun trace () = frames 1

    fun printTrace out =
      List.app (fn {function, file, line, column} =>
                  TextIO.output (out,
                    "  in " ^ function
                    ^ (if file = "" then ""
                       else " at " ^ file ^ ":" ^ Int.toString line ^ ":" ^ Int.toString column)
                    ^ "\n"))
               (frames 2)

    (* The difference between two readings. What measuring costs is inside it
       -- the record of the first reading, and the instructions of both -- so
       `profile (fn () => ())` is that cost and subtracting it from another
       answer removes it. *)
    fun profile f =
      let
        val a = stats ()
        val v = f ()
        val b = stats ()
      in
        (v, {instructions = #instructions b - #instructions a,
             bytes = #bytes b - #bytes a,
             objects = #objects b - #objects a,
             collections = #collections b - #collections a,
             live = #live b - #live a,
             heapSize = #heapSize b - #heapSize a,
             minorCollections = #minorCollections b - #minorCollections a,
             majorCollections = #majorCollections b - #majorCollections a,
             promoted = #promoted b - #promoted a})
      end

    (* The identity of a heap value, which the compiler uses for the
       constructor of an exception and no structure of the library has
       offered until now. *)
    val same = _prim "ptr_eq" : 'a * 'a -> bool

    val version = version' ()

    datatype world = Saved | Restored

    (* The world restored is another process, whose standard input is its
       own: what this one read ahead of its own and did not take is dropped,
       the reader kept. A stream already closed has nothing to drop. *)
    fun freshStdIn () =
      let val (rd, _) = TextIO.StreamIO.getReader (TextIO.getInstream TextIO.stdIn)
      in TextIO.setInstream (TextIO.stdIn, TextIO.StreamIO.mkInstream (rd, "")) end
      handle IO.Io _ => ()

    (* collected first, so that the image holds what is live and no more *)
    fun save file =
      case (collect' (); save' file) of
        0 => Saved
      | 1 => (freshStdIn (); Restored)
      | _ => raise RuneError.lastError ()

    (* The primitive comes back only when it could not read the image: on
       success the world it made is running instead, and nothing here is
       reached again. *)
    fun restore file = (ignore (restore' file); raise RuneError.lastError ())

    fun link bytes =
      case link' (Byte.bytesToString bytes) of
        SOME run => run
      | NONE => raise Fail ("Runtime.link: " ^ linkError' ())

    fun load file =
      let val ins = BinIO.openIn file
      in link (BinIO.inputAll ins before BinIO.closeIn ins) end

    fun catchInterrupt () = catchInterrupt' SML90.Interrupt

    fun maskInterrupt b = maskInterrupt' b

    (* The REPL's: `raiseMark ~1` makes the handler pushed last the one whose
       raises -- those that leave the code the REPL runs -- record the
       frames they leave, and `raiseMark m` puts back a mark it gave before;
       `raiseTrace ()` is those frames, innermost first (rt_raise_mark,
       rt_raise_trace) *)
    fun raiseMark m = raiseMark' m
    fun raiseTrace () : frame list =
      List.map (fn (f, file, l, c) => {function = f, file = file, line = l, column = c}) (raiseTrace' ())

    (* The REPL's debugger (the REPL roadmap's D22 and M12; runtime/debug.c,
       the rt_debug primitives).

       `debugHook f` makes f what the VM calls where the program stops,
       with the event (1 a breakpoint, 2 a step, 3 a pause, 4 a raise, 5 a
       raise the REPL's handler takes), false where the VM has no debugger.
       `debugMode m` sets the mode -- 1 debug mode, 2 a stop at every raise
       of the user's code, 4 at a raise the REPL's handler takes, 8 the
       user's interrupt a pause -- and gives the one it replaces;
       `debugUser ()` makes the files the program has the library's, where
       a step does not stop. `debugBreak (file, line, set)` sets or clears
       a breakpoint, and says how many places of the code begin the line.
       While the hook runs, `debugStep m` says how the stop ends (0 on, 1
       a step in, 2 over, 3 out, 4 the interrupt raised), `debugFrames ()`
       is its frames, innermost first, each with the number of the VM's
       frame (0 the one that stopped), `debugWhere k` that frame's function
       and its pc in it, `debugLive (k, r)` what register r of it holds --
       0 nothing, 1 an immediate, 2 a pointer -- which `RuneDebug.register`
       reads, and `debugExn ()` the
       exception a stop at a raise stopped for. `debugProgram ()` is how
       many functions the program has. *)
    fun debugHook f = debugHook' f
    fun debugMode m = debugMode' m
    fun debugUser () = debugUser' ()
    fun debugBreak (file, line, set) = debugBreak' (file, line, set)
    fun debugStep m = debugStep' m
    fun debugFrames () = debugFrames' ()
    fun debugWhere k = debugWhere' k
    fun debugLive (k, r) = debugLive' (k, r)
    fun debugExn () = debugExn' ()
    fun debugProgram () = debugProgram' ()

    (* `randomBytes n` is n bytes of the system's randomness, "" where it
       has none: a secret, such as the token of the REPL's engine
       (docs/repl-protocol.md). *)
    fun randomBytes n = randomBytes' n

    (* Windows has no signal to interrupt another process by. `interruptEvent ()`
       is an event a child started after inherits, by the number this
       gives, ~1 elsewhere: a child that catches the interrupt and is given
       the number in RUNE_INTERRUPT_EVENT takes `setInterrupt n` -- the
       event set -- as the user's interrupt (docs/runtime.md, Interrupts). *)
    fun interruptEvent () = eventNew' ()
    fun setInterrupt n = eventSet' n

    (* `spawn (path, args, env, fds)` starts the program at path with the
       arguments (its name first), the environment where one is given, and
       the descriptors of its standard input, output and error by number
       (`Posix.FileSys.fdToWord`; ~1: this process's own) -- as fork, dup2
       and exec would, but on Windows too, which has no fork to give a
       child pipes; its process's number.
       Raises: `OS.SysErr` when it cannot be started. *)
    fun spawn (path : string, args : string list, env : string list option, fds : int list) : int =
      let val pid = spawn' (path, args, getOpt (env, []), if isSome env then 2 else 0, fds)
      in if pid < 0 then raise RuneError.lastError () else pid end
  end
end

(* The debugger's reads of a stopped frame, at any type: the REPL's alone,
   which knows the type from the compiler (`-g`). `register (k, r)` is
   register r of frame k of the stop, `env (k, e)` slot e of the
   environment of its closure (RuneRuntime.debugLive first). *)
structure RuneDebug =
struct
  val register = _prim "rt_debug_local" : int * int -> 'a
  val env = _prim "rt_debug_env" : int * int -> 'a
end

(* Runtime: the VM's view of the running program -- its counters, its call
   stack, the identity of objects, saving and restoring the whole of it,
   units appended to it, and the user's interrupt.
   It is Rune's own and not of the specification.

   Implements: RUNTIME

   Status: extension *)
structure Runtime = RuneRuntime
