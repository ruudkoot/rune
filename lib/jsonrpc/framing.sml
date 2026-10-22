(* Framing: persistent streaming readers. Received chunks are retained
   until one message is complete, and concatenated once for that message.

   Implements: FRAMING *)
structure Framing :> FRAMING =
struct
  datatype framing = Lines | ContentLength
  exception Header of string
  exception Limit of string
  datatype state = Line of string list * int
                 | Head of string list * int * int
                 | Body of string list * int
  type reader = {framing : framing, headerLimit : int option, bodyLimit : int option, state : state}
  fun initial Lines = Line ([], 0) | initial ContentLength = Head ([], 0, 0)
  fun reader f = {framing = f, headerLimit = NONE, bodyLimit = NONE, state = initial f}
  fun bounded {framing, maxHeaderBytes, maxBodyBytes} =
    if maxHeaderBytes <= 0 orelse maxBodyBytes <= 0 then raise Domain
    else {framing = framing, headerLimit = SOME maxHeaderBytes, bodyLimit = SOME maxBodyBytes,
          state = initial framing}
  fun pending ({state, ...} : reader) =
    case state of Line (_, n) => n > 0 | Head (_, n, _) => n > 0 | Body _ => true
  fun frame (Lines, m) = m ^ "\n"
    | frame (ContentLength, m) = "Content-Length: " ^ Int.toString (size m) ^ "\r\n\r\n" ^ m
  fun guard (NONE, _, _) = ()
    | guard (SOME limit, n, what) = if n <= limit then () else raise Limit what
  fun plus (a, b) =
    if a > String.maxSize - b then raise Limit "message exceeds String.maxSize" else a + b
  fun trim s =
    let fun space c = c = #" " orelse c = #"\t"
        fun left i = if i < size s andalso space (String.sub (s, i)) then left (i + 1) else i
        fun right i = if i > 0 andalso space (String.sub (s, i - 1)) then right (i - 1) else i
        val a = left 0
    in String.substring (s, a, Int.max (0, right (size s) - a)) end
  fun lower s = String.map Char.toLower s
  fun headerLines s =
    let
      fun finish (a, b) =
        let val part = String.substring (s, a, b - a)
        in if CharVector.exists (fn c => c = #"\r" orelse c = #"\n") part
           then raise Header "header lines must use CRLF" else part end
      fun loop (start, i, acc) =
        if i + 1 >= size s then rev (finish (start, size s) :: acc)
        else if String.sub (s, i) = #"\r" andalso String.sub (s, i + 1) = #"\n"
        then loop (i + 2, i + 2, finish (start, i) :: acc)
        else loop (start, i + 1, acc)
    in loop (0, 0, []) end
  fun lengthOf (header, limit) =
    let
      fun pair line =
        case CharVector.findi (fn (_, c) => c = #":") line of
          SOME (i, _) =>
            let val name = lower (trim (String.substring (line, 0, i)))
            in if name = "" orelse CharVector.exists Char.isSpace name then raise Header "invalid header name"
               else (name, trim (String.extract (line, i + 1, NONE))) end
        | NONE => raise Header "header has no colon"
      val fields = List.map pair (headerLines header)
      val lengths = List.mapPartial (fn ("content-length", v) => SOME v | _ => NONE) fields
      val text = case lengths of [v] => v | [] => raise Header "no Content-Length"
                              | _ => raise Header "repeated Content-Length"
      val () = if text <> "" andalso CharVector.all Char.isDigit text then ()
               else raise Header "Content-Length is not a nonnegative decimal integer"
      val maximum = case limit of SOME n => Int.min (n, String.maxSize) | NONE => String.maxSize
      fun digit (c, n) =
        let val d = Char.ord c - Char.ord #"0"
        in if n > maximum div 10 orelse (n = maximum div 10 andalso d > maximum mod 10)
           then raise Limit "body" else n * 10 + d end
      val length = CharVector.foldl digit 0 text
      fun charset (name, value) =
        if name <> "content-type" then ()
        else List.app (fn parameter =>
          case CharVector.findi (fn (_, c) => c = #"=") parameter of
            NONE => if lower (trim parameter) = "charset" then raise Header "charset has no value" else ()
          | SOME (i, _) =>
              if lower (trim (String.substring (parameter, 0, i))) <> "charset" then ()
              else
                let val raw = lower (trim (String.extract (parameter, i + 1, NONE)))
                    val encoding = if size raw >= 2 andalso String.sub (raw, 0) = #"\""
                                      andalso String.sub (raw, size raw - 1) = #"\""
                                   then String.substring (raw, 1, size raw - 2) else raw
                in if encoding = "utf-8" orelse encoding = "utf8" then ()
                   else raise Header "unsupported character encoding" end)
          (String.fields (fn c => c = #";") value)
      val () = List.app charset fields
    in length end
  fun advance (matched, c) =
    if c = (if matched = 0 orelse matched = 2 then #"\r" else #"\n") then matched + 1
    else if c = #"\r" then 1 else 0
  fun feed ({framing, headerLimit, bodyLimit, state} : reader, more) =
    let
      val n = size more
      fun part (start, stop, parts) =
        if start = stop then parts else String.substring (more, start, stop - start) :: parts
      fun done (messages, state) =
        (rev messages, {framing = framing, headerLimit = headerLimit, bodyLimit = bodyLimit, state = state})
      fun loop (i, state, messages) =
        if i = n then done (messages, state)
        else
          case state of
            Body (parts, remaining) =>
              let val count = Int.min (remaining, n - i)
                  val parts = part (i, i + count, parts)
              in if count = remaining then
                   loop (i + count, initial framing, String.concat (rev parts) :: messages)
                 else done (messages, Body (parts, remaining - count)) end
          | Line (parts, bytes) =>
              let fun scan j =
                    if j = n then
                      let val total = plus (bytes, j - i)
                          val () = guard (bodyLimit, total, "line")
                      in done (messages, Line (part (i, j, parts), total)) end
                    else if String.sub (more, j) = #"\n" then
                      let val total = plus (bytes, j - i)
                          val () = guard (bodyLimit, total, "line")
                          val text = String.concat (rev (part (i, j, parts)))
                          val text = if String.isSuffix "\r" text then String.substring (text, 0, size text - 1) else text
                      in loop (j + 1, initial framing, if text = "" then messages else text :: messages) end
                    else (guard (bodyLimit, plus (bytes, j - i + 1), "line"); scan (j + 1))
              in scan i end
          | Head (parts, bytes, matched) =>
              let fun scan (j, matched) =
                    if j = n then done (messages, Head (part (i, j, parts), plus (bytes, j - i), matched))
                    else
                      let val c = String.sub (more, j)
                          val total = plus (bytes, j - i + 1)
                          val () = guard (headerLimit, total, "header")
                          val () = if (c >= #" " andalso Char.ord c < 127) orelse c = #"\t"
                                      orelse c = #"\r" orelse c = #"\n" then ()
                                   else raise Header "invalid header character"
                          val matched = advance (matched, c)
                      in if matched = 4 then
                           let val text = String.concat (rev (part (i, j + 1, parts)))
                               val length = lengthOf (String.substring (text, 0, size text - 4), bodyLimit)
                           in if length = 0 then loop (j + 1, initial framing, "" :: messages)
                              else loop (j + 1, Body ([], length), messages) end
                         else scan (j + 1, matched) end
              in scan (i, matched) end
    in loop (0, state, []) end
end
