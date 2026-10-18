(* WideTextPrimIO (optional in the specification): the readers and writers of
   the wide character.

   Implements: PRIM_IO where type array = WideCharArray.array where type vector
   = WideCharVector.vector where type elem = WideChar.char where type
   vector_slice = WideCharVectorSlice.slice where type array_slice =
   WideCharArraySlice.slice

   Status: optional *)
structure WideTextPrimIO =
  RunePrimIOFn (structure V = WideCharVector
                structure A = WideCharArray
                structure VS = WideCharVectorSlice
                structure AS = WideCharArraySlice
                val someElem = WideChar.chr 0
                type pos = RuneWideTextPos.pos
                val compare = RuneWideTextPos.compare
                val index = SOME {fromInt = RuneWideTextPos.fromInt, toInt = RuneWideTextPos.toInt})

(* WideTextIO (optional in the specification): the imperative streams of the
   wide character. The specification names no signature for it -- the
   transcription of TEXT_IO writes its types as `string` and `char`, which are
   those of `TextIO` -- so this page is where the structure is described. Its
   members are those of TEXT_IO over `WideString.string` and `WideChar.char`.

   Area: Input and output

   Implementation: `WideTextIO/files-hold-utf-8`. The specification names no
   encoding, so a stream of `WideTextIO` is a stream of `TextIO` encoded in
   UTF-8: one byte for a code point below 128, up to four above it. What is
   not UTF-8 raises `IO.Io` with the cause `Fail "UTF-8"`. On input that is a
   byte sequence that the Unicode Standard's Table 3-7 does not list: an
   overlong form, a surrogate, a value past 0x10FFFF, a lead byte C0, C1 or
   F5 to FF, a continuation byte where a sequence begins, a sequence cut
   short. On output it is a surrogate, which a `WideChar.char` may be (it
   holds every code point) and UTF-8 does not hold. A stream made with
   `mkInstream` over a reader of one's own carries wide characters as they
   are, surrogates included, without an encoding. No host has a `WideTextIO`
   to compare with.

   Pinned by: `WideTextIO.output/writes-utf-8`,
   `WideTextIO.inputAll/reads-utf-8`,
   `WideTextIO.inputN/counts-characters-not-bytes`,
   `WideTextIO.inputAll/refuses-*`, `WideTextIO.output/refuses-surrogate-*`

   Limitation: `WideTextIO/file-streams-have-no-positions`. The reader and
   the writer of a file of wide characters have no positions, no `ioDesc`,
   no operations that do not block, and neither `canInput` nor `avail`: a
   position in the file is one of bytes and not of characters. Their
   `chunkSize` is 1024 characters, where a file of `TextIO` has 4096.

   Pinned by: `WideTextIO.openIn/the-reader-has-no-positions`

   Status: optional *)
structure WideTextIO =
struct
  local
    structure SI =
      RuneStreamIOFn (structure PIO = WideTextPrimIO structure V = WideCharVector
                      structure VS = WideCharVectorSlice
                      val advance = SOME RuneWideTextPos.advance
                      val isNewline = fn c => WideChar.ord c = 10)
  in
    (* WideTextIO.StreamIO: the functional streams of wide text under
       `WideTextIO`, with the operations on lines and substrings of
       TEXT_STREAM_IO. *)
    structure StreamIO =
    struct
      open SI

      (* as TextIO.StreamIO.inputLine: up to and including the newline, with
         one added at an end-of-stream, and NONE when there is nothing left *)
      fun inputLine strm =
        let
          val newline = WideChar.chr 10
          fun index (v, i) =
            if Int.>= (i, WideCharVector.length v) then NONE
            else if WideCharVector.sub (v, i) = newline then SOME i
            else index (v, Int.+ (i, 1))
          fun go (strm, acc) =
            let val (v, strm') = input strm
            in
              if WideCharVector.length v = 0 then
                case acc of
                  [] => NONE
                | _ => SOME (WideCharVector.concat (List.rev (WideCharVector.fromList [newline] :: acc)), strm')
              else
                case index (v, 0) of
                  SOME k =>
                    SOME (WideCharVector.concat
                            (List.rev (WideCharVectorSlice.vector (WideCharVectorSlice.slice (v, 0, SOME (Int.+ (k, 1)))) :: acc)),
                          #2 (inputN (strm, Int.+ (k, 1))))
                | NONE => go (strm', v :: acc)
            end
        in go (strm, []) end

      fun outputSubstr (strm, ss) = output (strm, WideSubstring.string ss)
    end
  end

  structure Imperative = RuneImperativeIOFn (structure SIO = StreamIO structure V = WideCharVector)

  type vector = WideString.string
  type elem = WideChar.char
  datatype instream = datatype Imperative.instream
  datatype outstream = datatype Imperative.outstream

  val input = Imperative.input
  val input1 = Imperative.input1
  val inputN = Imperative.inputN
  val inputAll = Imperative.inputAll
  val canInput = Imperative.canInput
  val lookahead = Imperative.lookahead
  val closeIn = Imperative.closeIn
  val endOfStream = Imperative.endOfStream
  val output = Imperative.output
  val output1 = Imperative.output1
  val flushOut = Imperative.flushOut
  val closeOut = Imperative.closeOut
  val mkInstream = Imperative.mkInstream
  val getInstream = Imperative.getInstream
  val setInstream = Imperative.setInstream
  val mkOutstream = Imperative.mkOutstream
  val getOutstream = Imperative.getOutstream
  val setOutstream = Imperative.setOutstream
  val getPosOut = Imperative.getPosOut
  val setPosOut = Imperative.setPosOut

  local
    (* ---- UTF-8 ----
       A wide character is a code point, surrogates included; UTF-8 holds
       the scalar values, which are the code points that are not surrogates
       (the Unicode Standard, 3.9). So neither direction takes a surrogate,
       and each raises Io with the cause Fail "UTF-8" on what is not UTF-8. *)
    fun notUtf8 (name, function) = raise IO.Io {name = name, function = function, cause = Fail "UTF-8"}
    fun isSurrogate n = Int.>= (n, 0xD800) andalso Int.<= (n, 0xDFFF)
    fun byte n = Char.chr (Int.mod (n, 256))
    fun encode name c =
      let val n = WideChar.ord c
      in
        if Int.< (n, 0x80) then String.str (Char.chr n)
        else if Int.< (n, 0x800) then
          String.implode [byte (Int.+ (0xC0, Int.div (n, 64))), byte (Int.+ (0x80, Int.mod (n, 64)))]
        else if isSurrogate n then notUtf8 (name, "output")
        else if Int.< (n, 0x10000) then
          String.implode [byte (Int.+ (0xE0, Int.div (n, 4096))),
                          byte (Int.+ (0x80, Int.mod (Int.div (n, 64), 64))),
                          byte (Int.+ (0x80, Int.mod (n, 64)))]
        else
          String.implode [byte (Int.+ (0xF0, Int.div (n, 262144))),
                          byte (Int.+ (0x80, Int.mod (Int.div (n, 4096), 64))),
                          byte (Int.+ (0x80, Int.mod (Int.div (n, 64), 64))),
                          byte (Int.+ (0x80, Int.mod (n, 64)))]
      end
    (* the whole vector is encoded before a byte of it is written *)
    fun encodeString (name, v) = String.concat (List.map (encode name) (WideString.explode v))
    (* one code point from the bytes that next () gives, NONE at the end. The
       sequences taken are the well-formed ones of the Unicode Standard's
       Table 3-7, and anything else raises: a byte 80 to BF where a sequence
       begins, a lead byte C0, C1 or F5 to FF, a second byte out of its lead
       byte's range (which is what an overlong form, a surrogate and a value
       past 0x10FFFF have), a later byte that is not 80 to BF, and a sequence
       that the end cuts short. *)
    fun decode (name, next) =
      let
        fun malformed () = notUtf8 (name, "input")
        (* the next byte, from lo to hi, as the six bits it carries *)
        fun continuation (lo, hi) =
          case next () of
            SOME c =>
              let val n = Char.ord c
              in if Int.>= (n, lo) andalso Int.<= (n, hi) then Int.- (n, 0x80) else malformed () end
          | NONE => malformed ()
        fun more (acc, k) =
          if k = 0 then acc else more (Int.+ (Int.* (acc, 64), continuation (0x80, 0xBF)), Int.- (k, 1))
        (* the bits of the lead byte, the range of the second byte, and how
           many bytes follow that *)
        fun sequence (bits, lo, hi, k) = more (Int.+ (Int.* (bits, 64), continuation (lo, hi)), k)
      in
        case next () of
          NONE => NONE
        | SOME c =>
            let val n = Char.ord c
            in
              SOME (WideChar.chr
                      (if Int.< (n, 0x80) then n
                       else if Int.< (n, 0xC2) then malformed ()
                       else if Int.< (n, 0xE0) then sequence (Int.- (n, 0xC0), 0x80, 0xBF, 0)
                       else if n = 0xE0 then sequence (0, 0xA0, 0xBF, 1)
                       else if n = 0xED then sequence (0xD, 0x80, 0x9F, 1)
                       else if Int.< (n, 0xF0) then sequence (Int.- (n, 0xE0), 0x80, 0xBF, 1)
                       else if n = 0xF0 then sequence (0, 0x90, 0xBF, 2)
                       else if Int.< (n, 0xF4) then sequence (Int.- (n, 0xF0), 0x80, 0xBF, 2)
                       else if n = 0xF4 then sequence (4, 0x80, 0x8F, 2)
                       else malformed ()))
            end
      end

    (* the reader and the writer of a stream of TextIO, in UTF-8 *)
    fun reader (ins, name) =
      let
        fun readVec n =
          let
            fun go (0, acc) = List.rev acc
              | go (k, acc) =
                case decode (name, fn () => TextIO.input1 ins) of
                  SOME c => go (Int.- (k, 1), c :: acc)
                | NONE => List.rev acc
          in WideCharVector.fromList (go (n, [])) end
      in
        WideTextPrimIO.RD {name = name, chunkSize = 1024, readVec = SOME readVec, readArr = NONE,
                           readVecNB = NONE, readArrNB = NONE, block = NONE, canInput = NONE,
                           avail = fn () => NONE, getPos = NONE, setPos = NONE, endPos = NONE,
                           verifyPos = NONE, close = fn () => TextIO.closeIn ins, ioDesc = NONE}
      end
    fun writer (outs, name) =
      let
        fun writeVec sl =
          let val v = WideCharVectorSlice.vector sl
          in TextIO.output (outs, encodeString (name, v)); WideCharVector.length v end
      in
        (WideTextPrimIO.WR {name = name, chunkSize = 1024, writeVec = SOME writeVec, writeArr = NONE,
                            writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                            getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                            close = fn () => TextIO.closeOut outs, ioDesc = NONE},
         {write = fn v => TextIO.output (outs, encodeString (name, v)), flush = fn () => TextIO.flushOut outs})
      end
    val empty = WideCharVector.fromList []
    fun instreamOf (ins, name) = mkInstream (StreamIO.mkInstream (reader (ins, name), empty))
    fun outstreamOf (outs, name) =
      let val (w, device) = writer (outs, name)
      in mkOutstream (StreamIO.mkOutstreamOver (w, IO.NO_BUF, device)) end
  in
    fun openIn name = instreamOf (TextIO.openIn name, name)
    fun openOut name = outstreamOf (TextIO.openOut name, name)
    fun openAppend name = outstreamOf (TextIO.openAppend name, name)
    (* a wide string is read as it is, with no encoding *)
    fun openString s = mkInstream (StreamIO.mkInstream (WideTextPrimIO.openVector s, empty))

    val stdIn = instreamOf (TextIO.stdIn, "<stdIn>")
    val stdOut = outstreamOf (TextIO.stdOut, "<stdOut>")
    val stdErr = outstreamOf (TextIO.stdErr, "<stdErr>")
  end

  fun inputLine (InStream r) =
    case StreamIO.inputLine (!r) of
      SOME (l, s) => (r := s; SOME l)
    | NONE => NONE

  fun outputSubstr (strm, ss) = output (strm, WideSubstring.string ss)

  fun print s = (output (stdOut, s); flushOut stdOut)

  fun scanStream scan (InStream r) =
    case scan StreamIO.input1 (!r) of
      SOME (v, rest) => (r := rest; SOME v)
    | NONE => NONE
end
