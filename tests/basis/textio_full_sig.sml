(* requires: TextIO TextPrimIO CharVector StringCvt Substring IO *)
(* uses: spec-sigs/STREAM_IO.sml spec-sigs/TEXT_STREAM_IO.sml spec-sigs/IMPERATIVE_IO.sml spec-sigs/TEXT_IO.sml *)
(* TextIO matches the whole of TEXT_IO, IMPERATIVE_IO among it, and
   TextIO.StreamIO matches TEXT_STREAM_IO `where type reader =
   TextPrimIO.reader where type writer = TextPrimIO.writer where type pos =
   TextPrimIO.pos` (https://smlfamily.github.io/Basis/text-io.html,
   text-stream-io.html, imperative-io.html, stream-io.html). textio_sig.sml
   matches TextIO against the imperative part alone. *)
structure TestTextIOFullSig =
struct
  structure C : SPEC_TEXT_IO = TextIO
  structure I : SPEC_IMPERATIVE_IO = TextIO
  structure S : SPEC_TEXT_STREAM_IO = TextIO.StreamIO
  structure G : SPEC_STREAM_IO = TextIO.StreamIO
  structure W : SPEC_TEXT_STREAM_IO where type reader = TextPrimIO.reader where type writer = TextPrimIO.writer where type pos = TextPrimIO.pos = TextIO.StreamIO

  val () = T.check ("TextIO:TEXT_IO/whole-signature-matches", fn () => true)
  val () = T.check ("TextIO:IMPERATIVE_IO/matches", fn () => true)
  val () = T.check ("TextIO.StreamIO:TEXT_STREAM_IO/matches", fn () => true)
  val () = T.check ("TextIO.StreamIO:STREAM_IO/matches", fn () => true)
  (* TEXT_STREAM_IO: "where type vector = CharVector.vector where type elem =
     Char.char"; TEXT_IO: vector and elem are those of StreamIO. *)
  val () = T.check ("TextIO.StreamIO:TEXT_STREAM_IO/vector-and-elem",
                    fn () => let val v : S.vector = "ab" val e : S.elem = #"a" in CharVector.sub (v, 0) = e end)
  val () = T.check ("TextIO:TEXT_IO/vector-is-StreamIO.vector",
                    fn () => let val v : C.vector = ("x" : TextIO.StreamIO.vector) val e : C.elem = (#"x" : TextIO.StreamIO.elem)
                             in String.sub (v, 0) = e end)
  (* The types of the substructure are those of TextIO.StreamIO and
     TextPrimIO, seen through the signatures. *)
  val () = T.check ("TextIO:TEXT_IO/StreamIO-is-TextIO.StreamIO",
                    fn () => let
                               val ins : TextIO.StreamIO.instream = C.getInstream (TextIO.openString "abc")
                               val (v, _) = C.StreamIO.input ins
                             in v = "abc" end)
  val () = T.check ("TextIO.StreamIO:TEXT_STREAM_IO/reader-is-TextPrimIO.reader",
                    fn () => let
                               val ins = W.mkInstream (TextPrimIO.nullRd (), "")
                               val (r : TextPrimIO.reader, v) = W.getReader ins
                             in v = "" end)
  val () = T.check ("TextIO.StreamIO:TEXT_STREAM_IO/writer-is-TextPrimIO.writer",
                    fn () => let
                               val out = W.mkOutstream (TextPrimIO.nullWr (), IO.NO_BUF)
                               val (w : TextPrimIO.writer, m) = W.getWriter out
                             in m = IO.NO_BUF end)
  val () = T.check ("TextIO:IMPERATIVE_IO/same-streams",
                    fn () => I.inputAll (TextIO.openString "abc") = "abc"
                             andalso TextIO.inputAll (I.mkInstream (TextIO.getInstream (TextIO.openString "d"))) = "d")

  (* The signatures of the Basis Library that the pages define ask no more
     than the pages do: the structures seen through the transcriptions match
     them. *)
  (*<< sig-STREAM_IO *)
  structure SigS : STREAM_IO = G
  val () = T.check ("TextIO.StreamIO:STREAM_IO/signature-STREAM_IO", fn () => true)
  (*>> sig-STREAM_IO *)
  (*<< sig-TEXT_STREAM_IO *)
  structure SigT : TEXT_STREAM_IO = S
  val () = T.check ("TextIO.StreamIO:TEXT_STREAM_IO/signature-TEXT_STREAM_IO", fn () => true)
  (*>> sig-TEXT_STREAM_IO *)
  (*<< sig-IMPERATIVE_IO *)
  structure SigI : IMPERATIVE_IO = I
  val () = T.check ("TextIO:IMPERATIVE_IO/signature-IMPERATIVE_IO", fn () => true)
  (*>> sig-IMPERATIVE_IO *)
  (*<< sig-TEXT_IO *)
  structure SigX : TEXT_IO = C
  val () = T.check ("TextIO:TEXT_IO/signature-TEXT_IO", fn () => true)
  (*>> sig-TEXT_IO *)
end
