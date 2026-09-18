(* The imperative streams of one element type: a cell holding a functional
   stream, which every operation replaces by what it has left (signature
   IMPERATIVE_IO). *)
functor RuneImperativeIOFn (structure SIO : STREAM_IO
                            structure V : MONO_VECTOR where type elem = SIO.elem
                                           where type vector = SIO.vector) =
struct
  type elem = SIO.elem
  type vector = SIO.vector
  datatype instream = InStream of SIO.instream ref
  (* An outstream carries the flush of the file under it: the stream layer
     flushes what it holds itself, the VM what it holds for the file. *)
  datatype outstream = OutStream of SIO.outstream * (unit -> unit)

  structure StreamIO = SIO

  fun mkInstream s = InStream (ref s)
  fun getInstream (InStream r) = !r
  fun setInstream (InStream r, s) = r := s
  fun mkOutstream s = OutStream (s, fn () => ())
  fun mkOutstreamOver (s, flushFile) = OutStream (s, flushFile)   (* not in IMPERATIVE_IO *)
  fun getOutstream (OutStream (s, _)) = s
  fun setOutstream (OutStream _, _) = ()   (* an outstream has no state of its own *)

  fun input (InStream r) = let val (v, s) = SIO.input (!r) in r := s; v end
  fun inputN (InStream r, n) = let val (v, s) = SIO.inputN (!r, n) in r := s; v end
  fun inputAll (InStream r) = let val (v, s) = SIO.inputAll (!r) in r := s; v end

  (* "After a call to input1 returning NONE ... the input stream should be
     positioned after the end-of-stream", which StreamIO.input1 cannot say,
     so the end of stream is passed here. *)
  fun input1 (InStream r) =
    case SIO.input1 (!r) of
      SOME (e, s) => (r := s; SOME e)
    | NONE => (r := SIO.pastEos (!r); NONE)

  fun lookahead (InStream r) =
    case SIO.input1 (!r) of SOME (e, _) => SOME e | NONE => NONE

  fun canInput (InStream r, n) = SIO.canInput (!r, n)
  (* "closeIn must also replace the functional stream with an empty stream":
     what was read ahead is dropped. *)
  fun closeIn (InStream r) = (SIO.closeIn (!r); r := SIO.emptied (!r))
  fun endOfStream (InStream r) = SIO.endOfStream (!r)

  fun output (OutStream (s, _), v) = SIO.output (s, v)
  fun output1 (OutStream (s, _), e) = SIO.output1 (s, e)
  fun flushOut (OutStream (s, flushFile)) = (SIO.flushOut s; flushFile ())
  fun closeOut (OutStream (s, _)) = SIO.closeOut s
  fun getPosOut (OutStream (s, _)) = SIO.getPosOut s
  fun setPosOut p = SIO.setPosOut p
end
