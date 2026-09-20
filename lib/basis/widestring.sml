(* WideString and WideSubstring (optional in the specification): the strings
   of WideChar, which are the vectors of WideCharVector, and their substrings,
   which are the slices of WideCharVectorSlice. *)
structure RuneWideString =
struct
  structure V = WideCharVector
  structure VS = WideCharVectorSlice

  type char = WideChar.char
  type string = V.vector

  val maxSize = V.maxLen
  val size = V.length
  val sub = V.sub
  fun extract (s, i, n) = VS.vector (VS.slice (s, i, n))
  fun substring (s, i, n) = extract (s, i, SOME n)
  fun op ^ (a, b) = V.concat [a, b]
  val concat = V.concat
  val str = fn c => V.fromList [c]
  val implode = V.fromList
  fun explode s = V.foldr (fn (c, acc) => c :: acc) [] s
  val empty = implode []
  fun concatWith sep [] = empty
    | concatWith sep (s :: rest) = concat (s :: List.foldr (fn (x, acc) => sep :: x :: acc) [] rest)
  val map = V.map
  fun translate f s = concat (List.map f (explode s))

  (* fields: every delimiter separates; tokens: runs of delimiters collapse
     and the empty pieces vanish *)
  fun fields isDelim s =
    let
      fun go (i, start, acc) =
        if Int.>= (i, size s) then List.rev (substring (s, start, Int.- (i, start)) :: acc)
        else if isDelim (sub (s, i)) then
          go (Int.+ (i, 1), Int.+ (i, 1), substring (s, start, Int.- (i, start)) :: acc)
        else go (Int.+ (i, 1), start, acc)
    in go (0, 0, []) end
  fun tokens isDelim s = List.filter (fn t => Int.> (size t, 0)) (fields isDelim s)

  fun isPrefix p s =
    Int.<= (size p, size s) andalso
    let fun go i = Int.>= (i, size p) orelse (sub (p, i) = sub (s, i) andalso go (Int.+ (i, 1)))
    in go 0 end
  fun isSuffix p s =
    Int.<= (size p, size s) andalso
    let
      val d = Int.- (size s, size p)
      fun go i = Int.>= (i, size p) orelse (sub (p, i) = sub (s, Int.+ (i, d)) andalso go (Int.+ (i, 1)))
    in go 0 end
  fun isSubstring p s =
    let
      val last = Int.- (size s, size p)
      fun go i = Int.<= (i, last) andalso (isPrefix p (extract (s, i, SOME (size p))) orelse go (Int.+ (i, 1)))
    in Int.>= (last, 0) andalso go 0 end

  val collate = V.collate
  val compare = collate WideChar.compare
  fun op < (a, b) = compare (a, b) = LESS
  fun op <= (a, b) = compare (a, b) <> GREATER
  fun op > (a, b) = compare (a, b) = GREATER
  fun op >= (a, b) = compare (a, b) <> LESS

  (* ---- text ---- *)
  fun toString s = String.concat (List.map WideChar.toString (explode s))
  fun toCString s = String.concat (List.map WideChar.toCString (explode s))

  local
    (* As many characters as can be read, as RuneEscape.scanString does for
       the 8-bit strings: NONE only when nothing at all could be read, no
       character and no formatting sequence. *)
    fun collect (one, skip, getc, src) =
      let
        val (skipped, src) = skip (getc, src)
        fun go (src, acc) =
          case one getc src of
            SOME (c, rest) => go (rest, c :: acc)
          | NONE => (acc, src)
        val (acc, rest) = go (src, [])
        val atEnd = case getc src of NONE => true | SOME _ => false
      in
        case acc of
          [] => if skipped orelse atEnd then SOME (empty, rest) else NONE
        | _ => SOME (implode (List.rev acc), rest)
      end

    (* from text of char: the escapes of widechar.sml, with the formatting
       sequences around a character skipped as WideChar.scan does *)
    fun narrowOne sml getc src =
      if sml then RuneWideCharImpl.scan getc src else RuneWideCharImpl.scanWide (false, getc, src)
    fun narrowSkip (getc, src) = RuneEscape.skipFormat getc src
    fun noSkip (_, src) = (false, src)

    (* from a stream of wide characters: an escape is written with the
       characters of ASCII, and a character that needs none stands for itself *)
    val backslash = WideChar.chr 92
    val quote = WideChar.chr 34
    fun isFormatW c = WideChar.isSpace c
    fun wideSkip (getc, src) =
      let
        fun close s =
          case getc s of
            SOME (c, s') => if isFormatW c then close s' else if c = backslash then SOME s' else NONE
          | NONE => NONE
        fun go (src, any) =
          case getc src of
            SOME (c, rest) =>
              if c <> backslash then (any, src)
              else (case getc rest of
                      SOME (c2, rest2) =>
                        if isFormatW c2 then (case close rest2 of SOME after => go (after, true) | NONE => (any, src))
                        else (any, src)
                    | NONE => (any, src))
          | NONE => (any, src)
      in go (src, false) end
    fun wideOne getc src0 =
      let
        val (_, src) = wideSkip (getc, src0)
        fun narrowReader s =
          case getc s of
            SOME (c, rest) =>
              if Int.<= (WideChar.ord c, 255) then SOME (Char.chr (WideChar.ord c), rest) else NONE
          | NONE => NONE
      in
        case getc src of
          NONE => NONE
        | SOME (c, rest) =>
            if c = backslash then
              (case RuneWideCharImpl.scanWide (true, narrowReader, src) of
                 SOME (w, rest') => SOME (w, #2 (wideSkip (getc, rest')))
               | NONE => NONE)
            else if c = quote then NONE
            else if WideChar.isPrint c orelse Int.> (WideChar.ord c, 255) then
              SOME (c, #2 (wideSkip (getc, rest)))
            else NONE
      end
  in
    fun scan getc src = collect (wideOne, wideSkip, getc, src)
    fun fromString s = StringCvt.scanString (fn getc => fn src => collect (narrowOne true, narrowSkip, getc, src)) s
    fun fromCString s = StringCvt.scanString (fn getc => fn src => collect (narrowOne false, noSkip, getc, src)) s
  end
end

(* Implements: STRING where type string = WideCharVector.vector where type
   char = WideChar.char

   Status: optional

   Reading: `WideString.scan/reads-wide-characters`. As the signature of the
   specification writes it, `scan` reads a stream of the structure's own
   characters, where MLton's reads 8-bit ones; `toString`, `fromString`,
   `toCString` and `fromCString` take and give text of `char`, the 8-bit one,
   in which a character above 255 appears as the escape `\uXXXX` or
   `\UXXXXXXXX` (widechar.sml).

   Pinned by: `WideString.scan/reads-wide-characters`,
   `WideString.scan/stops-at-a-character-it-cannot-read` *)
structure WideString :> STRING
  where type string = WideCharVector.vector
  where type char = WideChar.char = RuneWideString

(* as RuneWideCharLit for a string constant *)
structure RuneWideStringLit =
struct
  fun fromLit s = case WideString.fromString s of SOME v => v | NONE => raise Fail ("wide string constant " ^ s)
end

_overload string WideString via RuneWideStringLit.fromLit

structure RuneWideSubstring =
struct
  structure V = WideCharVector
  structure VS = WideCharVectorSlice

  type char = WideChar.char
  type string = V.vector
  type substring = VS.slice

  val size = VS.length
  val sub = VS.sub
  val base = VS.base
  val full = VS.full
  val slice = VS.subslice
  fun extract (s, i, n) = VS.slice (s, i, n)
  fun substring (s, i, n) = extract (s, i, SOME n)
  val string = VS.vector
  fun isEmpty ss = size ss = 0
  val getc = VS.getItem
  fun first ss = case getc ss of SOME (c, _) => SOME c | NONE => NONE
  fun triml k ss =
    if Int.< (k, 0) then raise Subscript
    else slice (ss, Int.min (k, size ss), NONE)
  fun trimr k ss =
    if Int.< (k, 0) then raise Subscript
    else slice (ss, 0, SOME (Int.max (0, Int.- (size ss, k))))
  fun concat l = V.concat (List.map string l)
  fun concatWith sep l = WideString.concatWith sep (List.map string l)
  fun explode ss = VS.foldr (fn (c, acc) => c :: acc) [] ss
  fun isPrefix s ss = WideString.isPrefix s (string ss)
  fun isSubstring s ss = WideString.isSubstring s (string ss)
  fun isSuffix s ss = WideString.isSuffix s (string ss)
  val collate = VS.collate
  val compare = collate WideChar.compare

  fun splitAt (ss, k) =
    if Int.< (k, 0) orelse Int.> (k, size ss) then raise Subscript
    else (slice (ss, 0, SOME k), slice (ss, k, NONE))
  fun splitl pred ss =
    let
      fun go i = if Int.< (i, size ss) andalso pred (sub (ss, i)) then go (Int.+ (i, 1)) else i
    in splitAt (ss, go 0) end
  fun splitr pred ss =
    let
      fun go i = if Int.> (i, 0) andalso pred (sub (ss, Int.- (i, 1))) then go (Int.- (i, 1)) else i
    in splitAt (ss, go (size ss)) end
  fun dropl pred ss = #2 (splitl pred ss)
  fun dropr pred ss = #1 (splitr pred ss)
  fun takel pred ss = #1 (splitl pred ss)
  fun taker pred ss = #2 (splitr pred ss)

  (* "the pair (pref, suff) where suff is the longest suffix of ss that has s
     as a prefix, and pref the prefix before it"; ss itself and the empty
     suffix when s does not occur *)
  fun position s ss =
    let
      val n = WideString.size s
      val last = Int.- (size ss, n)
      fun go i =
        if Int.> (i, last) then size ss
        else if WideString.isPrefix s (string (slice (ss, i, SOME n))) then i
        else go (Int.+ (i, 1))
    in splitAt (ss, go 0) end

  (* "span (ss, ss') ... the substring from the start of ss to the end of
     ss'"; they must come from the same string *)
  fun span (ss, ss') =
    let
      val (s, i, n) = base ss
      val (s', i', n') = base ss'
    in
      if s <> s' orelse Int.> (i, Int.+ (i', n')) then raise Span
      else slice (full s, i, SOME (Int.- (Int.+ (i', n'), i)))
    end

  fun translate f ss = WideString.concat (List.map f (explode ss))
  fun fields isDelim ss =
    let
      fun go (i, start, acc) =
        if Int.>= (i, size ss) then List.rev (slice (ss, start, SOME (Int.- (i, start))) :: acc)
        else if isDelim (sub (ss, i)) then
          go (Int.+ (i, 1), Int.+ (i, 1), slice (ss, start, SOME (Int.- (i, start))) :: acc)
        else go (Int.+ (i, 1), start, acc)
    in go (0, 0, []) end
  fun tokens isDelim ss = List.filter (fn t => Int.> (size t, 0)) (fields isDelim ss)
  val app = VS.app
  val foldl = VS.foldl
  val foldr = VS.foldr
end

structure WideSubstring :> SUBSTRING
  where type substring = WideCharVectorSlice.slice
  where type string = WideCharVector.vector
  where type char = WideChar.char = RuneWideSubstring
