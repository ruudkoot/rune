(* Implements: HS_SOURCE *)
structure HsSource :> HS_SOURCE =
struct
  type span = {file : string, start : int, stop : int}

  val noSpan : span = {file = "", start = 0, stop = 0}

  fun join (a : span, b : span) : span =
    {file = #file a, start = Int.min (#start a, #start b), stop = Int.max (#stop a, #stop b)}

  type text = {file : string, bytes : string, lines : int vector}

  fun text {file, bytes} : text =
    let
      val n = size bytes
      fun go (i, acc) =
        if i >= n then Vector.fromList (List.rev acc)
        else if String.sub (bytes, i) = #"\n" then go (i + 1, (i + 1) :: acc)
        else go (i + 1, acc)
    in
      {file = file, bytes = bytes, lines = go (0, [0])}
    end

  fun file (t : text) = #file t
  fun bytes (t : text) = #bytes t

  (* The characters of [from, to): a well-formed sequence of UTF-8 counts
     one, and so does every other byte. *)
  fun characters (s, from, to) =
    let
      fun go (i, k) =
        if i >= to then k
        else if Char.ord (String.sub (s, i)) < 128 then go (i + 1, k + 1)
        else
          case Utf8.decode (s, i) of
            SOME (_, w) => go (i + w, k + 1)
          | NONE => go (i + 1, k + 1)
    in
      go (from, 0)
    end

  fun position ({bytes, lines, ...} : text, offset) =
    let
      val offset = Int.max (0, Int.min (offset, size bytes))
      (* the last line that starts at or before offset *)
      fun search (lo, hi) =
        if lo >= hi then lo
        else
          let val mid = (lo + hi + 1) div 2
          in if Vector.sub (lines, mid) <= offset then search (mid, hi) else search (lo, mid - 1) end
      val line = search (0, Vector.length lines - 1)
    in
      {line = line + 1, column = characters (bytes, Vector.sub (lines, line), offset) + 1}
    end

  exception Error of span * string

  fun hex c =
    let val s = Int.fmt StringCvt.HEX c
    in "\\u{" ^ s ^ "}" end

  fun escapeName name =
    String.translate
      (fn c => if Char.ord c < 32 orelse Char.ord c = 127 then hex (Char.ord c) else String.str c)
      name

  fun message (t : text, {start, ...} : span, msg) =
    let val {line, column} = position (t, start)
    in
      String.concat [escapeName (#file t), ":", Int.toString line, ":", Int.toString column, ": error: ", msg]
    end
end
