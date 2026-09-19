(* The functional streams of one element type (signature STREAM_IO).

   An instream is a position in a chain of segments that the reader fills in
   as they are wanted: each segment is a non-empty chunk or the end of the
   stream, and the chain goes on after an end of stream, because a file may
   grow. So two streams that share a segment read the same elements, and
   reading twice from one stream gives the same result twice. A segment
   records where it starts in the reader, when the reader tells positions;
   a position is the offset of an element, as for the files of the VM.

   An outstream buffers what the mode asks for and hands the rest to its
   writer. One that mkOutstreamOver makes for a file of the VM (not in
   STREAM_IO) hands everything to the VM at once, which buffers the file
   itself, and asks the VM to flush where the mode says so; its writer, which
   getWriter returns, writes through.

   isNewline tells the element at which LINE_BUF flushes; "For binary
   streams, LINE_BUF mode should be treated as a synonym for BLOCK_BUF". *)
functor RuneStreamIOFn (structure PIO : PRIM_IO where type pos = int
                        structure V : MONO_VECTOR where type elem = PIO.elem where type vector = PIO.vector
                        structure VS : MONO_VECTOR_SLICE where type elem = PIO.elem
                                       where type vector = PIO.vector where type slice = PIO.vector_slice
                        val isNewline : PIO.elem -> bool) =
struct
  type elem = PIO.elem
  type vector = PIO.vector
  type reader = PIO.reader
  type writer = PIO.writer
  type pos = PIO.pos

  fun ioError (name, function, cause) = raise IO.Io {name = name, function = function, cause = cause}
  (* guarded (name, function) f x: f x, with what the reader or writer raises
     reported as the cause of Io ("the underlying exception is caught and
     propagated up as the cause component of the IO.Io exception value"). *)
  fun guarded (name, function) f x =
    f x handle e as IO.Io _ => raise e | e => ioError (name, function, e)

  (* ---- input ---- *)
  datatype segment = Unread | Chunk of vector * pos option * segment ref | Eos of pos option * segment ref

  (* The reader as given (for getReader) and with what augmentReader adds
     (for reading); active is false once the stream is truncated or closed. *)
  datatype instream = In of {segment : segment ref, offset : int, state : state}
  withtype state = {reader : reader, augmented : reader, active : bool ref, closed : bool ref}

  fun readerName (PIO.RD {name, ...}) = name
  (* here getPos: where the reader is, if it can tell; a reader that has
     getPos may still not know (a pipe), and then the chunk it reads next has
     no position. *)
  fun here (SOME getPos) = (SOME (getPos ()) handle _ => NONE)
    | here NONE = NONE

  (* The segment at s, read from the reader when it is not there yet. The
     stream of a truncated or closed stream ends there. *)
  fun force (s : segment ref, {augmented, active, ...} : state, function) =
    case !s of
      Unread =>
        if not (!active) then (s := Eos (NONE, ref Unread); !s)
        else
          let
            val PIO.RD {readVec, getPos, chunkSize, name, ...} = augmented
            val p = here getPos
            val v =
              case readVec of
                SOME f => guarded (name, function) f (if chunkSize < 1 then 1 else chunkSize)
              | NONE => ioError (name, function, IO.BlockingNotSupported)
          in
            s := (if V.length v = 0 then Eos (p, ref Unread) else Chunk (v, p, ref Unread));
            !s
          end
    | got => got

  fun mkInstream (reader, v) =
    let
      val augmented = PIO.augmentReader reader
      val PIO.RD {getPos, ...} = augmented
      (* the elements of v were read from the reader just before it is at *)
      val start =
        if V.length v = 0 then NONE
        else case getPos of SOME f => (SOME (f () - V.length v) handle _ => NONE) | NONE => NONE
      val first = ref (if V.length v = 0 then Unread else Chunk (v, start, ref Unread))
    in
      In {segment = first, offset = 0,
          state = {reader = reader, augmented = augmented, active = ref true, closed = ref false}}
    end

  (* "marks the stream closed, and closes the underlying reader"; "one can
     close a truncated or terminated string" *)
  fun closeIn (In {state = {reader = PIO.RD {close, name, ...}, active, closed, ...}, ...}) =
    if !closed then () else (closed := true; active := false; guarded (name, "closeIn") close ())

  (* "marks the input stream f as truncated and returns the underlying reader
     along with any unconsumed data from its buffer. [...] The function raises
     the exception Io if f is closed or truncated." *)
  fun getReader (In {segment, offset, state = {reader, active, ...}}) =
    let
      fun rest (s, off, acc) =
        case !s of
          Chunk (v, _, next) => rest (next, 0, VS.vector (VS.slice (v, off, NONE)) :: acc)
        | _ => V.concat (List.rev acc)
    in
      if not (!active) then ioError (readerName reader, "getReader", IO.ClosedStream)
      else (active := false; (reader, rest (segment, offset, [])))
    end

  fun endOfStream (In {segment, offset, state}) =
    case force (segment, state, "endOfStream") of
      Chunk (v, _, next) =>
        if offset >= V.length v then endOfStream (In {segment = next, offset = 0, state = state}) else false
    | _ => true

  (* input: the rest of the chunk, or "" at the end of the stream, which it
     passes: "the stream f' is immediately past the next end-of-stream". *)
  fun input (strm as In {segment, offset, state}) =
    case force (segment, state, "input") of
      Chunk (v, _, next) =>
        if offset >= V.length v then input (In {segment = next, offset = 0, state = state})
        else (VS.vector (VS.slice (v, offset, NONE)), In {segment = next, offset = 0, state = state})
    | Eos (_, next) => (V.fromList [], In {segment = next, offset = 0, state = state})
    | Unread => (V.fromList [], strm)

  fun input1 (In {segment, offset, state}) =
    case force (segment, state, "input1") of
      Chunk (v, _, next) =>
        if offset >= V.length v then input1 (In {segment = next, offset = 0, state = state})
        else SOME (V.sub (v, offset), In {segment = segment, offset = offset + 1, state = state})
    | _ => NONE

  (* "If fewer than n elements are available before the next end-of-stream,
     it returns all of the elements up to that end-of-stream", and then the
     stream after it, as inputAll does (allAndN); n elements that end at an
     end-of-stream leave the stream before it. *)
  fun inputN (strm, n) =
    if n < 0 then raise Size
    else
      let
        fun go (strm as In {segment, offset, state}, left, acc) =
          if left = 0 then (V.concat (List.rev acc), strm)
          else
            case force (segment, state, "inputN") of
              Chunk (v, _, next) =>
                let val have = V.length v - offset
                in
                  if have <= 0 then go (In {segment = next, offset = 0, state = state}, left, acc)
                  else if have <= left then
                    go (In {segment = next, offset = 0, state = state}, left - have,
                        VS.vector (VS.slice (v, offset, NONE)) :: acc)
                  else
                    (V.concat (List.rev (VS.vector (VS.slice (v, offset, SOME left)) :: acc)),
                     In {segment = segment, offset = offset + left, state = state})
                end
            | Eos (_, next) => (V.concat (List.rev acc), In {segment = next, offset = 0, state = state})
            | Unread => (V.concat (List.rev acc), strm)
      in go (strm, n, []) end

  fun inputAll strm =
    let
      fun go (strm, acc) =
        let val (v, strm') = input strm
        in if V.length v = 0 then (V.concat (List.rev acc), strm') else go (strm', v :: acc) end
    in go (strm, []) end

  (* What can be had without waiting: what has been read already, then what
     readVecNB gives, which the stream keeps ("Such a lookahead commits the
     stream to the characters read by readVecNB"), or else what the reader
     says it has. *)
  fun canInput (In {segment, offset, state}, n) =
    if n < 0 then raise Size
    else if n = 0 then SOME 0
    else
      let
        val {augmented = PIO.RD {readVecNB, avail, getPos, chunkSize, name, ...}, active, ...} = state
        fun atMost k = if k > n then n else k
        fun ready (s, off, acc) =
          if acc >= n then SOME n
          else
            case !s of
              Chunk (v, _, next) => ready (next, 0, acc + V.length v - off)
            | Eos _ => SOME acc
            | Unread =>
                if not (!active) then SOME acc
                else
                  case readVecNB of
                    SOME f =>
                      let val p = here getPos
                      in
                        case guarded (name, "canInput") f (if chunkSize < 1 then 1 else chunkSize) of
                          NONE => if acc = 0 then NONE else SOME acc
                        | SOME v =>
                            (s := (if V.length v = 0 then Eos (p, ref Unread) else Chunk (v, p, ref Unread));
                             ready (s, 0, acc))
                      end
                  | NONE =>
                      case guarded (name, "canInput") avail () of
                        SOME k => SOME (atMost (acc + k))
                      | NONE => if acc = 0 then NONE else SOME acc
      in ready (segment, offset, 0) end

  (* "returns the primitive-level reader position that corresponds to the
     next element to be read from the buffered stream f. This raises the
     exception Io if the stream does not support the operation, or if f has
     been truncated." *)
  fun filePosIn (In {segment, offset, state = {augmented = PIO.RD {getPos, name, ...}, active, ...}}) =
    if not (!active) then ioError (name, "filePosIn", IO.ClosedStream)
    else
      case (getPos, !segment) of
        (NONE, _) => ioError (name, "filePosIn", IO.RandomAccessNotSupported)
      | (_, Chunk (_, SOME p, _)) => p + offset
      | (_, Eos (SOME p, _)) => p
      | (SOME f, Unread) => guarded (name, "filePosIn") f ()
      | _ => ioError (name, "filePosIn", IO.RandomAccessNotSupported)

  (* ---- output ---- *)
  datatype status = Active | Terminated | Closed
  (* device: the file of the VM of a stream of mkOutstreamOver, or NONE *)
  datatype outstream =
    Out of {writer : writer, augmented : writer, mode : IO.buffer_mode ref,
            buffer : vector list ref, buffered : int ref, status : status ref,
            device : {write : vector -> unit, flush : unit -> unit} option}
  type out_pos = {stream : outstream, position : pos}

  fun writerName (PIO.WR {name, ...}) = name

  (* writeAll (writer, v, function): all of v; "If flushing finds that it can
     do only a partial write [...], then the stream function must adjust the
     stream's buffer for the items written and then try again." *)
  fun writeAll (PIO.WR {writeVec, name, ...}, v, function) =
    case writeVec of
      NONE => ioError (name, function, IO.BlockingNotSupported)
    | SOME f =>
        let fun go i = if i >= V.length v then () else go (i + guarded (name, function) f (VS.slice (v, i, NONE)))
        in go 0 end

  (* What the buffer holds goes to the writer; it is emptied first, so that
     nothing is written twice if the writer fails. *)
  fun flushBuffer (Out {augmented, buffer, buffered, ...}, function) =
    case !buffer of
      [] => ()
    | chunks => (buffer := []; buffered := 0; writeAll (augmented, V.concat (List.rev chunks), function))

  fun flushDevice (Out {device, writer, ...}, function) =
    case device of
      SOME {flush, ...} => guarded (writerName writer, function) flush ()
    | NONE => ()

  fun flushAll (strm, function) = (flushBuffer (strm, function); flushDevice (strm, function))

  fun mkOutstream (writer, mode) =
    Out {writer = writer, augmented = PIO.augmentWriter writer, mode = ref mode, buffer = ref [],
         buffered = ref 0, status = ref Active, device = NONE}

  (* A stream over a file of the VM: write hands a vector to the VM, flush
     makes the VM write what it holds. Not in STREAM_IO. *)
  fun mkOutstreamOver (writer, mode, device) =
    Out {writer = writer, augmented = PIO.augmentWriter writer, mode = ref mode, buffer = ref [],
         buffered = ref 0, status = ref Active, device = SOME device}

  fun hasNewline v = V.exists isNewline v

  fun outputWith (strm as Out {writer, augmented, mode, buffer, buffered, status, device}, v, function) =
    if !status <> Active then ioError (writerName writer, function, IO.ClosedStream)
    else
      case device of
        SOME {write, flush} =>
          (guarded (writerName writer, function) write v;
           case !mode of
             IO.NO_BUF => guarded (writerName writer, function) flush ()
           | IO.LINE_BUF => if hasNewline v then guarded (writerName writer, function) flush () else ()
           | IO.BLOCK_BUF => ())
      | NONE =>
          let
            val PIO.WR {chunkSize, ...} = augmented
            fun keep () = (buffer := v :: !buffer; buffered := !buffered + V.length v)
          in
            case !mode of
              IO.NO_BUF => (flushBuffer (strm, function); writeAll (augmented, v, function))
            | IO.LINE_BUF => (keep (); if hasNewline v orelse !buffered >= chunkSize then flushBuffer (strm, function) else ())
            | IO.BLOCK_BUF => (keep (); if !buffered >= chunkSize then flushBuffer (strm, function) else ())
          end

  fun output (strm, v) = outputWith (strm, v, "output")
  fun output1 (strm, e) = outputWith (strm, V.fromList [e], "output1")

  (* "flushes any output in f's buffer to the underlying writer; it is a
     no-op on terminated streams" *)
  fun flushOut (strm as Out {status, ...}) = if !status = Active then flushAll (strm, "flushOut") else ()

  (* "flushes f's buffers, marks the stream closed, and closes the underlying
     writer. This operation has no effect if f is already closed. Note that
     if f is terminated, no flushing will occur." A failed flush leaves the
     stream open. *)
  fun closeOut (strm as Out {writer = PIO.WR {close, name, ...}, status, ...}) =
    case !status of
      Closed => ()
    | Terminated => (status := Closed; guarded (name, "closeOut") close ())
    | Active => (flushAll (strm, "closeOut"); status := Closed; guarded (name, "closeOut") close ())

  (* "Setting the buffer mode to IO.NO_BUF causes any buffered output to be
     flushed. [...] Switching the mode between IO.LINE_BUF and IO.BLOCK_BUF
     should not cause flushing." *)
  fun setBufferMode (strm as Out {mode, status, ...}, m) =
    (if m = IO.NO_BUF andalso !status = Active then flushAll (strm, "setBufferMode") else ();
     mode := m)
  fun getBufferMode (Out {mode, ...}) = !mode

  (* "flushes the stream f, marks it as being terminated and returns the
     underlying writer and the stream's buffer mode. This raises the
     exception Io if f is closed, or if the flushing fails." *)
  fun getWriter (strm as Out {writer, mode, status, ...}) =
    case !status of
      Closed => ioError (writerName writer, "getWriter", IO.ClosedStream)
    | Terminated => (writer, !mode)
    | Active => (flushAll (strm, "getWriter"); status := Terminated; (writer, !mode))

  (* "This raises the exception Io if the stream does not support the
     operation, if any implicit flushing fails, or if f is terminated." *)
  fun getPosOut (strm as Out {writer = PIO.WR {getPos, name, ...}, status, ...}) =
    if !status <> Active then ioError (name, "getPosOut", IO.ClosedStream)
    else
      case getPos of
        SOME f => (flushAll (strm, "getPosOut"); {stream = strm, position = guarded (name, "getPosOut") f ()})
      | NONE => ioError (name, "getPosOut", IO.RandomAccessNotSupported)

  (* "flushes the output buffer of the stream underlying opos, sets the
     current position of the stream to the position recorded in opos, and
     returns the stream" *)
  fun setPosOut {stream = strm as Out {writer = PIO.WR {setPos, name, ...}, status, ...}, position} =
    if !status <> Active then ioError (name, "setPosOut", IO.ClosedStream)
    else
      case setPos of
        SOME f => (flushAll (strm, "setPosOut"); guarded (name, "setPosOut") f position; strm)
      | NONE => ioError (name, "setPosOut", IO.RandomAccessNotSupported)

  fun filePosOut ({position, ...} : out_pos) = position
end
