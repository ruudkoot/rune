(* Paired comparison with the exact pre-change Framing implementation,
   compiled as OriginalFraming in the same program. Correctness is checked
   against the independently constructed body after the timed work. *)
structure LspFramingPerformance =
struct
  exception Failed of string
  fun need (b, s) = if b then () else raise Failed s
  fun chunks width text =
    let fun loop (i, acc) = if i = size text then rev acc
          else let val n = Int.min (width, size text - i)
               in loop (i + n, String.substring (text, i, n) :: acc) end
    in loop (0, []) end
  fun original parts =
    let val (out, reader) = List.foldl (fn (part, (out, reader)) =>
          let val (messages, next) = OriginalFraming.feed (reader, part)
          in (out @ messages, next) end) ([], OriginalFraming.reader OriginalFraming.ContentLength) parts
    in (out, OriginalFraming.pending reader) end
  fun current parts =
    let val (out, reader) = List.foldl (fn (part, (out, reader)) =>
          let val (messages, next) = Framing.feed (reader, part)
          in (out @ messages, next) end)
          ([], Framing.bounded {framing = Framing.ContentLength, maxHeaderBytes = 8192, maxBodyBytes = 1024 * 1024}) parts
    in (out, Framing.pending reader) end
  fun measured action =
    let val () = Runtime.collect ()
        val stats = Runtime.stats ()
        val start = Runtime.clock ()
        val answer = action ()
        val elapsed = Time.- (Runtime.clock (), start)
        val afterStats = Runtime.stats ()
    in (answer, elapsed, #bytes afterStats - #bytes stats) end
  fun one (bytes, width) =
    let
      val body = String.implode (List.tabulate (bytes, fn i => Char.chr (32 + i mod 95)))
      val wire = "Content-Length: " ^ Int.toString (size body) ^ "\r\n\r\n" ^ body
      val parts = chunks width wire
      fun run (name, action, rep) =
        let val ((messages, pending), elapsed, allocated) = measured (fn () => action parts)
            val () = need (messages = [body] andalso not pending, "framing result differs for " ^ name)
            val row = Json.Object [("implementation", Json.String name), ("body_bytes", Json.int bytes),
              ("chunk_bytes", Json.int width), ("repetition", Json.int rep),
              ("wall_us", Json.intInf (Time.toMicroseconds elapsed)), ("allocated_bytes", Json.int allocated)]
        in if rep < 0 then () else print (Json.encode row ^ "\n") end
      fun pair i = if i mod 2 = 0 then (run ("old", original, i); run ("new", current, i))
                   else (run ("new", current, i); run ("old", original, i))
      val () = run ("old", original, ~1)
      val () = run ("new", current, ~1)
    in List.app pair (List.tabulate (5, fn i => i)) end
  fun main () = List.app one [(4096, 1), (16384, 1), (16384, 64), (16384, 4096)]
end
val () = LspFramingPerformance.main ()
  handle e => (TextIO.output (TextIO.stdErr, "FAIL framing-performance: " ^ General.exnMessage e ^ "\n");
               OS.Process.exit OS.Process.failure)
