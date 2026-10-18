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
   `chunkSize` is 4096 characters, as that of a file of `TextIO` is 4096
   bytes.

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
    val empty = WideCharVector.fromList []

    (* the reader of a stream of TextIO, in UTF-8: the bytes come in the
       blocks TextIO.input gives, and C decodes them (RuneWideText.decodeUtf8,
       which takes the well-formed sequences of the Unicode Standard's
       Table 3-7 and nothing else). A sequence that the end of a block cuts
       short waits for the next one. The characters before a sequence that is
       not UTF-8, or before one that the end of the file cuts short, are given
       first; the read after them raises Io, and so does every read after
       that. *)
    fun reader (ins, name) =
      let
        val bytes = ref ""            (* read from ins, decoded up to !at *)
        val at = ref 0
        val bad = ref false           (* what !at begins is not UTF-8 *)
        fun malformed () = (bad := true; notUtf8 (name, "input"))
        fun readVec n =
          if Int.< (n, 0) then raise Size
          else if !bad then malformed ()
          else if n = 0 then empty
          else
            let val (v, j, status) = RuneWideText.decodeUtf8 (!bytes, !at, n)
            in
              at := j;
              if Int.> (WideString.size v, 0) then (if status = 1 then bad := true else (); v)
              else if status = 1 then malformed ()
              else
                (* nothing whole is left: what is left, and the next block *)
                let
                  val rest = String.extract (!bytes, j, NONE)
                  val more = TextIO.input ins
                in
                  if String.size more = 0 then (if String.size rest = 0 then empty else malformed ())
                  else (bytes := rest ^ more; at := 0; readVec n)
                end
            end
      in
        WideTextPrimIO.RD {name = name, chunkSize = 4096, readVec = SOME readVec, readArr = NONE,
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
        (WideTextPrimIO.WR {name = name, chunkSize = 4096, writeVec = SOME writeVec, writeArr = NONE,
                            writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                            getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                            close = fn () => TextIO.closeOut outs, ioDesc = NONE},
         {write = fn v => TextIO.output (outs, encodeString (name, v)), flush = fn () => TextIO.flushOut outs})
      end
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
