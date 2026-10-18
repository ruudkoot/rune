(* WideString and the rest of the wide family (optional in the
   specification): the strings of wide characters and their substrings, made
   on the vectors and slices of widechar.sml; then the seal that makes the
   family's types, in the order of the specification; then WideChar,
   WideCharVector and the others, which are views of those types, as Char and
   CharVector are of `char` and `string`. *)
structure RuneWideString =
struct
  structure V = RuneWideCharVector
  structure VS = RuneWideCharVectorSlice

  type char = RuneWideChar.char
  type string = V.vector

  val maxSize = V.maxLen
  val size = V.length
  val sub = V.sub
  (* the copies are made in C (Vector.extract and Vector.append), as
     String's are; the bounds are those of String.extract *)
  fun extract (s, i, NONE) = if Int.< (i, 0) then raise Subscript else Vector.extract (s, i, Int.- (size s, i))
    | extract (s, i, SOME n) = Vector.extract (s, i, n)
  fun substring (s, i, n) = Vector.extract (s, i, n)
  val op ^ = Vector.append
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
  val compare = collate RuneWideCharImpl.compare
  fun op < (a, b) = compare (a, b) = LESS
  fun op <= (a, b) = compare (a, b) <> GREATER
  fun op > (a, b) = compare (a, b) = GREATER
  fun op >= (a, b) = compare (a, b) <> LESS

  (* ---- text ---- *)
  fun toString s = String.concat (List.map RuneWideCharImpl.toString (explode s))
  fun toCString s = String.concat (List.map RuneWideCharImpl.toCString (explode s))

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
      if sml then RuneWideCharImpl.scanInString getc src else RuneWideCharImpl.scanWide (false, getc, src)
    fun narrowSkip (getc, src) = RuneEscape.skipFormat getc src
    fun noSkip (_, src) = (false, src)

    (* from a stream of wide characters: an escape is written with the
       characters of ASCII, and a character that needs none stands for itself *)
    val backslash = RuneWideCharImpl.chr 92
    fun isFormatW c = RuneWideCharImpl.isSpace c
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
              if Int.<= (RuneWideCharImpl.ord c, 255) then SOME (Char.chr (RuneWideCharImpl.ord c), rest) else NONE
          | NONE => NONE
      in
        case getc src of
          NONE => NONE
        | SOME (c, rest) =>
            if c = backslash then
              (case RuneWideCharImpl.scanWide (true, narrowReader, src) of
                 SOME (w, rest') => SOME (w, #2 (wideSkip (getc, rest')))
               | NONE => NONE)
            (* a double quote that no backslash precedes prints, and converts
               to itself as it does for String.scan *)
            else if RuneWideCharImpl.isPrint c orelse Int.> (RuneWideCharImpl.ord c, 255) then
              SOME (c, #2 (wideSkip (getc, rest)))
            else NONE
      end
  in
    fun scan getc src = collect (wideOne, wideSkip, getc, src)
    fun fromString s = StringCvt.scanString (fn getc => fn src => collect (narrowOne true, narrowSkip, getc, src)) s
    fun fromCString s = StringCvt.scanString (fn getc => fn src => collect (narrowOne false, noSkip, getc, src)) s
  end
end

structure RuneWideSubstring =
struct
  structure V = RuneWideCharVector
  structure VS = RuneWideCharVectorSlice

  type char = RuneWideChar.char
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
  fun concatWith sep l = RuneWideString.concatWith sep (List.map string l)
  fun explode ss = VS.foldr (fn (c, acc) => c :: acc) [] ss
  fun isPrefix s ss = RuneWideString.isPrefix s (string ss)
  fun isSubstring s ss = RuneWideString.isSubstring s (string ss)
  fun isSuffix s ss = RuneWideString.isSuffix s (string ss)
  val collate = VS.collate
  val compare = collate RuneWideCharImpl.compare

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
      val n = RuneWideString.size s
      val last = Int.- (size ss, n)
      fun go i =
        if Int.> (i, last) then size ss
        else if RuneWideString.isPrefix s (string (slice (ss, i, SOME n))) then i
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

  fun translate f ss = RuneWideString.concat (List.map f (explode ss))
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

(* The wide family, sealed at once in the order of the specification: the
   strings are a type of their own, and the vectors of wide characters are
   that type, as `CharVector.vector` is `String.string`. The signature is the
   declarations of the specification, with the one constraint its
   declaration of `WideCharVector` lacks, `where type vector =
   WideString.string` (the erratum `MONO_VECTOR/WideCharVector-must-admit-equality`):
   so `WideString.string` admits equality because `STRING` says so, and
   `WideCharVector` needs no signature of its own. The structures are made
   above with the types of the polymorphic vectors and arrays, and the seal
   makes their types names of their own, which the constants of `WideChar`
   and `WideString` are overloaded at. *)
structure RuneWideText :>
sig
  structure WideString : STRING where type char = RuneWideChar.char
  structure WideChar : CHAR
    where type char = RuneWideChar.char
    where type string = WideString.string
  structure WideCharVector : MONO_VECTOR
    where type vector = WideString.string
    where type elem = WideChar.char
  structure WideCharVectorSlice : MONO_VECTOR_SLICE
    where type vector = WideString.string
    where type elem = WideChar.char
  structure WideSubstring : SUBSTRING
    where type substring = WideCharVectorSlice.slice
    where type string = WideString.string
    where type char = WideChar.char
  structure WideCharArray : MONO_ARRAY
    where type vector = WideString.string
    where type elem = WideChar.char
  structure WideCharArraySlice : MONO_ARRAY_SLICE
    where type vector = WideString.string
    where type vector_slice = WideCharVectorSlice.slice
    where type array = WideCharArray.array
    where type elem = WideChar.char
  structure WideCharArray2 : MONO_ARRAY2
    where type vector = WideString.string
    where type elem = WideChar.char
  (* `decodeUtf8 (s, i, n)`: the wide string that the UTF-8 of `s` from byte
     `i` encodes, at most `n` characters long, the byte after it, and 0, or 1
     where a sequence that is not UTF-8 begins there, or 2 where the end of
     `s` cuts one short: what WideTextIO's reader decodes with *)
  val decodeUtf8 : string * int * int -> WideString.string * int * int
end =
struct
  structure WideString = RuneWideString
  structure WideChar = RuneWideCharImpl
  structure WideCharVector = RuneWideCharVector
  structure WideCharVectorSlice = RuneWideCharVectorSlice
  structure WideSubstring = RuneWideSubstring
  structure WideCharArray = RuneWideCharArray
  structure WideCharArraySlice = RuneWideCharArraySlice
  structure WideCharArray2 = RuneWideCharArray2
  val decodeUtf8 = RuneWideChar.decodeUtf8
end

(* WideString: strings of wide characters, and their conversions to and from
   the text of SML and C.

   Implements: STRING where type char = WideChar.char

   Status: optional

   Reading: `WideString.scan/reads-wide-characters`. As the signature of the
   specification writes it, `scan` reads a stream of the structure's own
   characters, where MLton's reads 8-bit ones; `toString`, `fromString`,
   `toCString` and `fromCString` take and give text of `char`, the 8-bit one,
   in which a character above 255 appears as the escape `\uXXXX` or
   `\UXXXXXXXX` (widechar.sml).

   Pinned by: `WideString.scan/reads-wide-characters`,
   `WideString.scan/stops-at-a-character-it-cannot-read`

   Reading: `WideString.scan/unescaped-double-quote`. In the stream of wide
   characters an escape is written with the characters of ASCII, and a
   character that needs none stands for itself, those above 255 too. A
   double quote that no backslash precedes converts to itself, as it does
   for `String.scan` and for `WideString.fromString` on its text of `char`:
   what ends a scan is the end of the stream, a character that does not
   print and a bad escape, and a double quote is none of these.

   Pinned by: `WideString.scan/unescaped-double-quote*` *)
structure WideString = RuneWideText.WideString

(* WideChar: the characters of Unicode, each a code point up to 0x10FFFF, and
   their classes and conversions.

   Implements: CHAR where type char = WideChar.char where type string =
   WideString.string

   Status: optional

   Reading: `WideChar.isAlpha/ascii-classes`. "In WideChar, the functions
   toLower, toUpper, isAlpha, ... and, in general, the definition of a letter
   are locale-dependent": here they are those of ASCII, so a character above
   127 is in no class and is its own upper and lower case. MLton reads it so
   too.

   Pinned by: `WideChar.isAscii/above-127`, `WideChar.isAlpha/e-acute`,
   `WideChar.toLower/leaves-a-wide-character`,
   `WideChar.toUpper/leaves-a-wide-character`

   Implementation: `WideChar.toString/escapes-above-255`. `toString` and
   `toCString` write a character above 255 as `\uXXXX`, or `\UXXXXXXXX` above
   0xFFFF, as MLton writes them, and `fromString` and `fromCString` read those
   escapes. `fromString` also reads `\ddd` of exactly three decimal digits,
   and `fromCString` the escapes of C, whose digits are octal; an octal or a
   `\x` escape of C names a character up to 255 only, so that
   `fromCString "\\x1F600"` is `NONE`. The text they take and
   give is of `char`, the 8-bit one, as the signature writes it, and `scan`
   reads from a stream of `char` and yields a wide character.

   Pinned by: `WideChar:CHAR/toString-gives-a-string-of-char`,
   `WideChar.scan/takes-the-escape-and-leaves-the-rest` *)
structure WideChar = RuneWideText.WideChar

(* WideCharVector: immutable vectors of wide characters, which are the
   strings of `WideString`: `WideCharVector.vector` is `WideString.string`,
   as `CharVector.vector` is `String.string`.

   Implements: MONO_VECTOR where type vector = WideString.string where type
   elem = WideChar.char

   Status: optional

   Reading: `WideCharVector/vector-is-WideString.string`. The page declares
   `WideCharVector :> MONO_VECTOR where type elem = WideChar.char` and nothing
   more, which no implementation can follow and still meet `TEXT` and
   `STRING` (the erratum `MONO_VECTOR/WideCharVector-must-admit-equality`).
   It is declared here as `CharVector` is, `where type vector =
   WideString.string`, so its vectors admit equality because the strings do,
   and plain `MONO_VECTOR` serves.

   Pinned by: `WideCharVector:MONO_VECTOR/vector-is-WideString.string`,
   `WideCharVector:MONO_VECTOR/vector-admits-equality` *)
structure WideCharVector = RuneWideText.WideCharVector

(* WideCharVectorSlice: stretches of `WideCharVector` vectors, without a
   copy, which are the substrings of `WideSubstring`.

   Implements: MONO_VECTOR_SLICE where type vector = WideCharVector.vector
   where type elem = WideChar.char

   Status: optional *)
structure WideCharVectorSlice = RuneWideText.WideCharVectorSlice

(* WideSubstring: pieces of wide strings, taken apart and searched without a
   copy.

   Implements: SUBSTRING where type substring = WideCharVectorSlice.slice where
   type string = WideString.string where type char = WideChar.char

   Status: optional *)
structure WideSubstring = RuneWideText.WideSubstring

(* WideCharArray: mutable arrays of wide characters, a type of their own with
   identity equality, whose vectors are those of `WideCharVector`.

   Implements: MONO_ARRAY where type vector = WideCharVector.vector where type
   elem = WideChar.char

   Status: optional *)
structure WideCharArray = RuneWideText.WideCharArray

(* WideCharArraySlice: stretches of `WideCharArray` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = WideCharVector.vector
   where type vector_slice = WideCharVectorSlice.slice where type array =
   WideCharArray.array where type elem = WideChar.char

   Status: optional *)
structure WideCharArraySlice = RuneWideText.WideCharArraySlice

(* WideCharArray2: two-dimensional arrays of wide characters, whose rows and
   columns are `WideCharVector` vectors.

   Implements: MONO_ARRAY2 where type vector = WideCharVector.vector where
   type elem = WideChar.char

   Status: optional *)
structure WideCharArray2 = RuneWideText.WideCharArray2

(* A constant of the type WideChar.char or WideString.string is read from its
   text where it is evaluated, as the constants of IntInf and Real32 are. *)
structure RuneWideCharLit =
struct
  fun fromLit s = case WideChar.fromString s of SOME c => c | NONE => raise Fail ("wide character constant " ^ s)
end

_overload char WideChar via RuneWideCharLit.fromLit

structure RuneWideStringLit =
struct
  fun fromLit s = case WideString.fromString s of SOME v => v | NONE => raise Fail ("wide string constant " ^ s)
end

_overload string WideString via RuneWideStringLit.fromLit
