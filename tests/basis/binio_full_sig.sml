(* requires: BinIO BinPrimIO Word8 Word8Vector Position IO *)
(* uses: spec-sigs/STREAM_IO.sml spec-sigs/IMPERATIVE_IO.sml spec-sigs/BIN_IO.sml *)
(* BinIO matches the whole of BIN_IO, IMPERATIVE_IO `where type
   StreamIO.vector = Word8Vector.vector where type StreamIO.elem = Word8.word
   where type StreamIO.reader = BinPrimIO.reader where type StreamIO.writer =
   BinPrimIO.writer where type StreamIO.pos = BinPrimIO.pos` among it, and
   BinIO.StreamIO matches STREAM_IO; "the BinIO.StreamIO.pos type, equal to
   the BinPrimIO.pos type, is concrete, being a synonym for Position.int"
   (https://smlfamily.github.io/Basis/bin-io.html, imperative-io.html,
   stream-io.html). binio_sig.sml matches BinIO against the imperative part
   alone. *)
structure TestBinIOFullSig =
struct
  structure C : SPEC_BIN_IO = BinIO
  structure I : SPEC_IMPERATIVE_IO = BinIO
  structure G : SPEC_STREAM_IO = BinIO.StreamIO
  structure W : SPEC_STREAM_IO where type vector = Word8Vector.vector where type elem = Word8.word where type reader = BinPrimIO.reader where type writer = BinPrimIO.writer where type pos = Position.int = BinIO.StreamIO

  val () = T.check ("BinIO:BIN_IO/whole-signature-matches", fn () => true)
  val () = T.check ("BinIO:IMPERATIVE_IO/matches", fn () => true)
  val () = T.check ("BinIO.StreamIO:STREAM_IO/matches", fn () => true)
  val () = T.check ("BinIO:BIN_IO/vector-and-elem",
                    fn () => let
                               val v : C.vector = Word8Vector.fromList [Word8.fromInt 1]
                               val e : C.StreamIO.elem = Word8.fromInt 1
                             in Word8Vector.sub (v, 0) = e end)
  val () = T.check ("BinIO.StreamIO:STREAM_IO/pos-is-Position.int",
                    fn () => let val p : W.pos = Position.fromInt 3 : BinPrimIO.pos in p = Position.fromInt 3 end)
  val () = T.check ("BinIO.StreamIO:STREAM_IO/reader-is-BinPrimIO.reader",
                    fn () => let
                               val ins = W.mkInstream (BinPrimIO.nullRd (), Word8Vector.fromList [])
                               val (r : BinPrimIO.reader, v) = W.getReader ins
                             in Word8Vector.length v = 0 end)
  val () = T.check ("BinIO.StreamIO:STREAM_IO/writer-is-BinPrimIO.writer",
                    fn () => let
                               val out = W.mkOutstream (BinPrimIO.nullWr (), IO.BLOCK_BUF)
                               val (w : BinPrimIO.writer, m) = W.getWriter out
                             in m = IO.BLOCK_BUF end)
  val () = T.check ("BinIO:BIN_IO/StreamIO-is-BinIO.StreamIO",
                    fn () => let
                               val ins : BinIO.StreamIO.instream = C.StreamIO.mkInstream (BinPrimIO.nullRd (), Word8Vector.fromList [])
                               val i : BinIO.instream = C.mkInstream ins
                             in Word8Vector.length (I.inputAll i) = 0 end)

  (* The signatures of the Basis Library that the pages define ask no more
     than the pages do: the structures seen through the transcriptions match
     them. *)
  (*<< sig-STREAM_IO *)
  structure SigS : STREAM_IO = G
  val () = T.check ("BinIO.StreamIO:STREAM_IO/signature-STREAM_IO", fn () => true)
  (*>> sig-STREAM_IO *)
  (*<< sig-IMPERATIVE_IO *)
  structure SigI : IMPERATIVE_IO = I
  val () = T.check ("BinIO:IMPERATIVE_IO/signature-IMPERATIVE_IO", fn () => true)
  (*>> sig-IMPERATIVE_IO *)
  (*<< sig-BIN_IO *)
  structure SigB : BIN_IO = C
  val () = T.check ("BinIO:BIN_IO/signature-BIN_IO", fn () => true)
  (*>> sig-BIN_IO *)
end
