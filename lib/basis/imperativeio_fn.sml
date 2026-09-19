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
  datatype outstream = OutStream of SIO.outstream ref

  structure StreamIO = SIO

  fun mkInstream s = InStream (ref s)
  fun getInstream (InStream r) = !r
  fun setInstream (InStream r, s) = r := s
  fun mkOutstream s = OutStream (ref s)
  (* "flushes strm and returns the underlying StreamIO output stream" *)
  fun getOutstream (OutStream r) = (SIO.flushOut (!r); !r)
  (* "flushes the stream underlying strm, and then assigns a new low-level
     stream strm' to it" *)
  fun setOutstream (OutStream r, s) = (SIO.flushOut (!r); r := s)

  fun input (InStream r) = let val (v, s) = SIO.input (!r) in r := s; v end
  fun inputN (InStream r, n) = let val (v, s) = SIO.inputN (!r, n) in r := s; v end
  fun inputAll (InStream r) = let val (v, s) = SIO.inputAll (!r) in r := s; v end

  (* "After a call to input1 returning NONE to indicate an end-of-stream, the
     input stream should be positioned after the end-of-stream", as
     StreamIO.inputN (f, 1) leaves it. *)
  fun input1 (InStream r) =
    case SIO.input1 (!r) of
      SOME (e, s) => (r := s; SOME e)
    | NONE => (r := #2 (SIO.inputN (!r, 1)); NONE)

  fun lookahead (InStream r) =
    case SIO.input1 (!r) of SOME (e, _) => SOME e | NONE => NONE

  fun canInput (InStream r, n) = SIO.canInput (!r, n)

  (* "closeIn must also replace the functional stream with an empty stream":
     what was read ahead is dropped. After StreamIO.closeIn, the stream ends
     where what was read ahead ends. *)
  fun closeIn (InStream r) =
    let
      fun drain s =
        let val (v, s') = SIO.input s
        in if V.length v = 0 andalso SIO.endOfStream s' then s' else drain s' end
    in SIO.closeIn (!r); r := drain (!r) end
  fun endOfStream (InStream r) = SIO.endOfStream (!r)

  fun output (OutStream r, v) = SIO.output (!r, v)
  fun output1 (OutStream r, e) = SIO.output1 (!r, e)
  fun flushOut (OutStream r) = SIO.flushOut (!r)
  fun closeOut (OutStream r) = SIO.closeOut (!r)
  fun getPosOut (OutStream r) = SIO.getPosOut (!r)
  fun setPosOut (OutStream r, p) = r := SIO.setPosOut p
end
