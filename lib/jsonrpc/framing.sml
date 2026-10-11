(* Framing: messages to a line, or behind Content-Length.

   Implements: FRAMING *)
structure Framing :> FRAMING =
struct
  datatype framing = Lines | ContentLength
  exception Header of string
  type reader = {framing : framing, buf : string}

  fun reader f = {framing = f, buf = ""}
  fun pending ({buf, ...} : reader) = buf <> ""

  fun frame (Lines, m) = m ^ "\n"
    | frame (ContentLength, m) = "Content-Length: " ^ Int.toString (String.size m) ^ "\r\n\r\n" ^ m

  (* where t is in s from i *)
  fun find (s, t, i) =
    if i + String.size t > String.size s then NONE
    else if String.substring (s, i, String.size t) = t then SOME i
    else find (s, t, i + 1)

  fun lengthOf header =
    let
      val fields = String.tokens (fn c => c = #"\r" orelse c = #"\n") header
      fun value f =
        case String.fields (fn c => c = #":") f of
          name :: rest =>
            if String.map Char.toLower name = "content-length"
            then SOME (String.concatWith ":" rest) else NONE
        | [] => NONE
      fun digits v = let val v = String.implode (List.filter (not o Char.isSpace) (String.explode v))
                     in if v <> "" andalso CharVector.all Char.isDigit v then Int.fromString v else NONE end
    in
      case List.mapPartial value fields of
        v :: _ => (case digits v of SOME n => n | NONE => raise Header ("a length that is no number: " ^ v))
      | [] => raise Header "no Content-Length"
    end

  fun feed ({framing, buf} : reader, more) =
    let
      val s = buf ^ more
      fun lines (i, acc) =
        case find (s, "\n", i) of
          NONE => (rev acc, {framing = framing, buf = String.extract (s, i, NONE)})
        | SOME j =>
            let
              val l = String.substring (s, i, j - i)
              val l = if String.isSuffix "\r" l then String.substring (l, 0, String.size l - 1) else l
            in
              lines (j + 1, if l = "" then acc else l :: acc)
            end
      fun headed (i, acc) =
        case find (s, "\r\n\r\n", i) of
          NONE => (rev acc, {framing = framing, buf = String.extract (s, i, NONE)})
        | SOME j =>
            let
              val n = lengthOf (String.substring (s, i, j - i))
              val body = j + 4
            in
              if body + n > String.size s then (rev acc, {framing = framing, buf = String.extract (s, i, NONE)})
              else headed (body + n, String.substring (s, body, n) :: acc)
            end
    in
      case framing of
        Lines => lines (0, [])
      | ContentLength => headed (0, [])
    end
end
