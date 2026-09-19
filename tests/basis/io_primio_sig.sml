(* requires: TextPrimIO BinPrimIO OS Position Word8 Word8Vector Word8Array CharVector CharArray *)
(* uses: spec-sigs/PRIM_IO.sml *)
(* TextPrimIO and BinPrimIO match PRIM_IO, with the constraints of
   https://smlfamily.github.io/Basis/prim-io.html: `structure BinPrimIO :>
   PRIM_IO where type array = Word8Array.array where type vector =
   Word8Vector.vector where type elem = Word8.word where type pos =
   Position.int` and `structure TextPrimIO :> PRIM_IO where type array =
   CharArray.array where type vector = CharVector.vector where type elem =
   Char.char`.

   The page leaves vector_slice and array_slice abstract. A reader or writer
   of one's own cannot be written without them, and the implementations make
   them the slices of the vector and array structures; the section `slices`
   checks that, which the behaviour tests (io_primio.sml, textio_streamio.sml,
   binio_streamio.sml) rely on. *)
structure TestIOPrimIOSig =
struct
  structure CT : SPEC_PRIM_IO = TextPrimIO
  structure WT : SPEC_PRIM_IO where type array = CharArray.array where type vector = CharVector.vector where type elem = Char.char = TextPrimIO
  structure CB : SPEC_PRIM_IO = BinPrimIO
  structure WB : SPEC_PRIM_IO where type array = Word8Array.array where type vector = Word8Vector.vector where type elem = Word8.word where type pos = Position.int = BinPrimIO

  val () = T.check ("TextPrimIO:PRIM_IO/matches", fn () => true)
  val () = T.check ("BinPrimIO:PRIM_IO/matches", fn () => true)
  val () = T.check ("TextPrimIO:PRIM_IO/vector-is-CharVector.vector",
                    fn () => CharVector.length ("abc" : WT.vector) = 3)
  val () = T.check ("TextPrimIO:PRIM_IO/array-and-elem",
                    fn () => let val a : WT.array = CharArray.array (2, #"x") val e : WT.elem = #"x"
                             in CharArray.sub (a, 1) = e end)
  val () = T.check ("BinPrimIO:PRIM_IO/vector-array-elem",
                    fn () => let
                               val v : WB.vector = Word8Vector.fromList [Word8.fromInt 7]
                               val a : WB.array = Word8Array.array (1, Word8.fromInt 7)
                               val e : WB.elem = Word8.fromInt 7
                             in Word8Vector.sub (v, 0) = e andalso Word8Array.sub (a, 0) = e end)
  (* "where type pos = Position.int" for BinPrimIO; pos is an eqtype. *)
  val () = T.check ("BinPrimIO:PRIM_IO/pos-is-Position.int",
                    fn () => let val p : WB.pos = Position.fromInt 5 in WB.compare (p, Position.fromInt 5) = EQUAL end)
  val () = T.check ("TextPrimIO:PRIM_IO/pos-is-an-eqtype", fn () => let val same : TextPrimIO.pos * TextPrimIO.pos -> bool = op = in true end)
  (* The constructors of the signature are those of the structure: a reader
     built through the signature is a reader of TextPrimIO. *)
  val () = T.check ("TextPrimIO:PRIM_IO/same-reader",
                    fn () => let
                               val r : TextPrimIO.reader = CT.nullRd ()
                               val TextPrimIO.RD {name, ...} = r
                               val CT.RD {name = name', ...} = r
                             in name = name' end)
  val () = T.check ("BinPrimIO:PRIM_IO/same-writer",
                    fn () => let
                               val w : BinPrimIO.writer = CB.nullWr ()
                               val BinPrimIO.WR {chunkSize, ...} = w
                               val CB.WR {chunkSize = chunkSize', ...} = w
                             in chunkSize = chunkSize' end)
  (* ioDesc : OS.IO.iodesc option *)
  val () = T.check ("TextPrimIO:PRIM_IO/ioDesc-is-OS.IO.iodesc",
                    fn () => let val TextPrimIO.RD {ioDesc, ...} = TextPrimIO.nullRd ()
                             in case ioDesc of SOME d => OS.IO.compare (d, d) = EQUAL | NONE => true end)

  (* the signature can be implemented opaquely *)
  structure OT :> SPEC_PRIM_IO where type array = CharArray.array where type vector = CharVector.vector where type elem = Char.char = TextPrimIO
  val () = T.check ("TextPrimIO:PRIM_IO/opaque", fn () => let val OT.RD {chunkSize, ...} = OT.openVector "abc" in chunkSize >= 1 end)

  (* The signature PRIM_IO of the Basis Library asks no more than the page:
     the structures seen through the transcription match it. *)
  (*<< sig-PRIM_IO *)
  structure SigT : PRIM_IO = CT
  structure SigB : PRIM_IO = CB
  val () = T.check ("TextPrimIO:PRIM_IO/signature-PRIM_IO", fn () => true)
  (*>> sig-PRIM_IO *)

  (*<< slices *)
  structure ST : SPEC_PRIM_IO where type vector_slice = CharVectorSlice.slice where type array_slice = CharArraySlice.slice = TextPrimIO
  structure SB : SPEC_PRIM_IO where type vector_slice = Word8VectorSlice.slice where type array_slice = Word8ArraySlice.slice = BinPrimIO
  val () = T.check ("TextPrimIO:PRIM_IO/slices-are-CharVectorSlice-and-CharArraySlice", fn () => true)
  val () = T.check ("BinPrimIO:PRIM_IO/slices-are-Word8VectorSlice-and-Word8ArraySlice", fn () => true)
  (*>> slices *)
end
