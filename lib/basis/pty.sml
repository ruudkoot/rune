(* Pseudo-terminal ownership over the system-layer PTY operations.

   Implements: PTY

   Status: extension *)
structure Pty =
struct
  local
    val spawn' = _prim "pty_spawn" : string * string list * string list * string * int * int -> int list
    val resize' = _prim "pty_resize" : int * int * int -> int
    val close' = _prim "pty_close" : int -> int
  in
    datatype session = Session of {pid : int, token : int, reader : int, writer : int, closed : bool ref}
    exception Closed
    fun size (columns, rows) = if columns > 0 andalso columns <= 32767 andalso rows > 0 andalso rows <= 32767 then () else raise Domain
    fun spawn {program, args, env, dir, columns, rows} =
      let val () = size (columns, rows)
          val () = if null args then raise Domain else ()
      in case spawn' (program, args, getOpt (env, Posix.ProcEnv.environ ()), getOpt (dir, ""), columns, rows) of
           [pid, token, reader, writer] => Session {pid = pid, token = token, reader = reader, writer = writer, closed = ref false}
         | _ => raise RuneError.lastError ()
      end
    fun require (Session {closed, ...}) = if !closed then raise Closed else ()
    fun input (s as Session {reader, ...}) = (require s; reader)
    fun output (s as Session {writer, ...}) = (require s; writer)
    fun process (Session {pid, ...}) = pid
    fun resize (s as Session {token, ...}, {columns, rows}) =
      (require s; size (columns, rows); if resize' (token, columns, rows) = 0 then () else raise RuneError.lastError ())
    fun close (Session {token, closed, ...}) =
      if !closed then () else (closed := true; if close' token = 0 then () else raise RuneError.lastError ())
  end
end
