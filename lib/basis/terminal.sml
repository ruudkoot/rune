(* Terminal: the terminal of a program that edits what is typed at it, over
   the runtime's term_size, term_resizes, term_enter, term_leave and
   term_read (runtime/sys/sys.h). It is Rune's own and not of the
   specification.

   Implements: TERMINAL

   Status: extension *)
structure Terminal =
struct
  local
    val size' = _prim "term_size" : int -> int list
    val resizes' = _prim "term_resizes" : unit -> int
    val enter' = _prim "term_enter" : int * int * string * int -> int
    val leave' = _prim "term_leave" : unit -> int
    val read' = _prim "term_read" : int * int * int -> string option
    val errno = _prim "sys_errno" : unit -> int
  in
    fun size () =
      case (size' 1, size' 0, size' 2) of
        ([c, r], _, _) => SOME {columns = c, rows = r}
      | (_, [c, r], _) => SOME {columns = c, rows = r}
      | (_, _, [c, r]) => SOME {columns = c, rows = r}
      | _ => NONE

    fun resizes () = resizes' ()

    fun enter {undo : string} =
      if enter' (0, 1, undo, 0) = 0 then () else raise RuneError.lastError ()

    fun quiet () = if enter' (0, 1, "", 1) = 0 then () else raise RuneError.lastError ()

    fun leave () = if leave' () = 0 then () else raise RuneError.lastError ()

    (* at most 4096 bytes a read: what a burst of typing or a paste gives
       in one go *)
    fun read (wait : Time.time option) =
      let
        val ms = case wait of
                   NONE => ~1
                 | SOME t => Int.max (0, Int.fromLarge (Time.toMilliseconds t))
      in
        case read' (0, 4096, ms) of
          SOME s => SOME s
        | NONE => if errno () = 0 then NONE else raise RuneError.lastError ()
      end
  end
end
