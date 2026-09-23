(* Runtime: what the VM counts, for the program it is running (Rune's own, not
   of the specification). Each counter is a primitive that reads a field of
   the VM and allocates nothing, so the six are read without disturbing five
   of them. *)
structure RuneRuntime =
struct
  local
    val instructions' = _prim "rt_instructions" : unit -> int
    val bytes' = _prim "rt_bytes" : unit -> int
    val objects' = _prim "rt_objects" : unit -> int
    val collections' = _prim "rt_collections" : unit -> int
    val live' = _prim "rt_live" : unit -> int
    val heapSize' = _prim "rt_heap_size" : unit -> int
    val collect' = _prim "rt_collect" : unit -> unit
    val version' = _prim "rt_version" : unit -> string
    val trace' = _prim "rt_trace" : int -> (string * string * int * int) list
  in
    type stats = { instructions : int, bytes : int, objects : int,
                   collections : int, live : int, heapSize : int }

    (* The heap's five are read first and the instruction count last, so that
       it counts as much of this call as it can. *)
    fun stats () : stats =
      let
        val b = bytes' ()
        val ob = objects' ()
        val c = collections' ()
        val l = live' ()
        val h = heapSize' ()
      in
        {instructions = instructions' (), bytes = b, objects = ob,
         collections = c, live = l, heapSize = h}
      end

    fun collect () = collect' ()

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
             heapSize = #heapSize b - #heapSize a})
      end

    (* The identity of a heap value, which the compiler uses for the
       constructor of an exception and no structure of the library has
       offered until now. *)
    val same = _prim "ptr_eq" : 'a * 'a -> bool

    val version = version' ()
  end
end

(* Implements: RUNTIME

   Status: extension *)
structure Runtime = RuneRuntime
