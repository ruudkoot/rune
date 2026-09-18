(* The functional streams of one element type (signature STREAM_IO).

   An instream is a position in a chain of segments that the reader fills in
   as they are wanted: each segment is a non-empty chunk or the end of the
   stream, and the chain goes on after an end of stream, because a file may
   grow. So two streams that share a segment read the same elements, and
   reading twice from one stream gives the same result twice. *)
functor RuneStreamIOFn (structure PIO : PRIM_IO
                        structure V : MONO_VECTOR where type elem = PIO.elem where type vector = PIO.vector
                        structure VS : MONO_VECTOR_SLICE where type elem = PIO.elem
                                       where type vector = PIO.vector where type slice = PIO.vector_slice) =
struct
  type elem = PIO.elem
  type vector = PIO.vector
  type reader = PIO.reader
  type writer = PIO.writer
  type pos = PIO.pos

  datatype segment = Unread | Chunk of vector * segment ref | Eos of segment ref

  datatype instream = In of {segment : segment ref, offset : int, state : state}
  withtype state = {reader : reader, closed : bool ref}

  fun ioError (name, function, cause) = raise IO.Io {name = name, function = function, cause = cause}
  fun readerName (PIO.RD {name, ...}) = name

  (* The segment at s, read from the reader when it is not there yet. A
     closed stream is at its end. *)
  fun force (s : segment ref, {reader, closed} : state, function) =
    case !s of
      Unread =>
        if !closed then (s := Eos (ref Unread); !s)
        else
          let
            val PIO.RD {readVec, chunkSize, name, ...} = reader
            val v =
              case readVec of
                SOME f => (f (if chunkSize < 1 then 1 else chunkSize)
                           handle OS.SysErr e => ioError (name, function, OS.SysErr e))
              | NONE => ioError (name, function, IO.BlockingNotSupported)
          in
            s := (if V.length v = 0 then Eos (ref Unread) else Chunk (v, ref Unread));
            !s
          end
    | got => got

  fun mkInstream (reader, v) =
    let
      val rest = ref Unread
      val first = ref (if V.length v = 0 then Unread else Chunk (v, rest))
    in In {segment = first, offset = 0, state = {reader = reader, closed = ref false}} end

  fun closeIn (In {state = {reader = PIO.RD {close, ...}, closed}, ...}) =
    if !closed then () else (closed := true; close ())

  fun getReader (In {segment, offset, state = {reader, closed}}) =
    let
      (* what has been read but not taken from the stream *)
      fun rest (s, off, acc) =
        case !s of
          Chunk (v, next) => rest (next, 0, VS.vector (VS.slice (v, off, NONE)) :: acc)
        | _ => V.concat (List.rev acc)
    in closed := true; (reader, rest (segment, offset, [])) end

  fun endOfStream (In {segment, offset, state}) =
    case force (segment, state, "endOfStream") of
      Chunk (v, _) => offset >= V.length v
    | _ => true

  (* input: the rest of the chunk, or "" at the end of the stream, which it
     passes: "the stream f' is immediately past the next end-of-stream". *)
  fun input (strm as In {segment, offset, state}) =
    case force (segment, state, "input") of
      Chunk (v, next) =>
        if offset >= V.length v then input (In {segment = next, offset = 0, state = state})
        else (VS.vector (VS.slice (v, offset, NONE)), In {segment = next, offset = 0, state = state})
    | Eos next => (V.fromList [], In {segment = next, offset = 0, state = state})
    | Unread => (V.fromList [], strm)

  fun input1 (In {segment, offset, state}) =
    case force (segment, state, "input1") of
      Chunk (v, next) =>
        if offset >= V.length v then input1 (In {segment = next, offset = 0, state = state})
        else SOME (V.sub (v, offset), In {segment = segment, offset = offset + 1, state = state})
    | _ => NONE

  (* An empty stream with the same state: what closeIn leaves behind, since
     "the closeIn function must also replace the functional stream with an
     empty stream". Not in STREAM_IO. *)
  fun emptied (In {state, ...}) = In {segment = ref Unread, offset = 0, state = state}

  (* The stream after an end of stream that input1 or lookahead found, so
     that the imperative layer can pass it. *)
  fun pastEos (strm as In {segment, offset, state}) =
    case !segment of
      Chunk (v, next) => if offset >= V.length v then pastEos (In {segment = next, offset = 0, state = state}) else strm
    | Eos next => In {segment = next, offset = 0, state = state}
    | Unread => strm

  fun inputN (strm, n) =
    if n < 0 then raise Size
    else
      let
        fun go (strm as In {segment, offset, state}, left, acc) =
          if left = 0 then (V.concat (List.rev acc), strm)
          else
            case force (segment, state, "inputN") of
              Chunk (v, next) =>
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
            | _ => (V.concat (List.rev acc), strm)
      in go (strm, n, []) end

  fun inputAll strm =
    let
      fun go (strm, acc) =
        let val (v, strm') = input strm
        in if V.length v = 0 then (V.concat (List.rev acc), strm') else go (strm', v :: acc) end
    in go (strm, []) end

  (* What can be had without waiting: what has been read already, and what
     the reader says it has. *)
  fun canInput (In {segment, offset, state}, n) =
    if n < 0 then raise Size
    else
      let
        val {reader = PIO.RD {avail, ...}, closed} = state
        fun ready (s, off, acc) =
          if acc >= n then SOME n
          else
            case !s of
              Chunk (v, next) => ready (next, 0, acc + V.length v - off)
            | Eos _ => SOME (if acc > n then n else acc)
            | Unread =>
                if !closed then SOME (if acc > n then n else acc)
                else
                  case avail () of
                    SOME k => SOME (let val total = acc + k in if total > n then n else total end)
                  | NONE => if acc = 0 then NONE else SOME (if acc > n then n else acc)
      in if n = 0 then SOME 0 else ready (segment, offset, 0) end

  fun filePosIn (In {segment, offset, state = {reader = PIO.RD {getPos, name, ...}, ...}}) =
    case getPos of
      SOME f => f ()
    | NONE => ioError (name, "filePosIn", IO.RandomAccessNotSupported)

  (* ---- output ----
     The buffer holds what has not been written yet; NO_BUF writes at once,
     LINE_BUF at the end of a line. *)
  datatype outstream =
    Out of {writer : writer, mode : IO.buffer_mode ref, buffer : vector list ref, closed : bool ref}
  type out_pos = {stream : outstream, position : pos}

  fun writerName (PIO.WR {name, ...}) = name
  fun writerOf (Out {writer, ...}) = writer

  fun writeAll (PIO.WR {writeVec, name, ...}, v, function) =
    case writeVec of
      NONE => ioError (name, function, IO.BlockingNotSupported)
    | SOME f =>
        let
          fun go i =
            if i >= V.length v then ()
            else go (i + f (VS.slice (v, i, NONE)))
        in go 0 handle OS.SysErr e => ioError (name, function, OS.SysErr e) end

  fun flushBuffer (Out {writer, buffer, ...}, function) =
    case !buffer of
      [] => ()
    | chunks => (buffer := []; writeAll (writer, V.concat (List.rev chunks), function))

  fun mkOutstream (writer, mode) =
    Out {writer = writer, mode = ref mode, buffer = ref [], closed = ref false}

  fun checkOpen (Out {writer, closed, ...}, function) =
    if !closed then ioError (writerName writer, function, IO.ClosedStream) else ()

  fun outputWith (strm as Out {mode, buffer, ...}, v, function) =
    (checkOpen (strm, function);
     case !mode of
       IO.NO_BUF => writeAll (writerOf strm, v, function)
     | IO.LINE_BUF => (buffer := v :: !buffer; flushBuffer (strm, function))
     | IO.BLOCK_BUF => buffer := v :: !buffer)

  fun output (strm, v) = outputWith (strm, v, "output")
  fun output1 (strm, e) = outputWith (strm, V.fromList [e], "output1")
  (* Flushing a closed stream does nothing, as on the three hosts. *)
  fun flushOut (strm as Out {closed, ...}) = if !closed then () else flushBuffer (strm, "flushOut")
  fun closeOut (strm as Out {writer = PIO.WR {close, ...}, closed, ...}) =
    if !closed then () else (flushBuffer (strm, "closeOut"); closed := true; close ())

  fun setBufferMode (strm as Out {mode, ...}, m) =
    (mode := m; case m of IO.NO_BUF => flushBuffer (strm, "setBufferMode") | _ => ())
  fun getBufferMode (Out {mode, ...}) = !mode
  fun getWriter (strm as Out {writer, mode, closed, ...}) =
    (flushBuffer (strm, "getWriter"); closed := true; (writer, !mode))

  fun getPosOut (strm as Out {writer = PIO.WR {getPos, name, ...}, ...}) =
    (flushBuffer (strm, "getPosOut");
     case getPos of
       SOME f => {stream = strm, position = f ()}
     | NONE => ioError (name, "getPosOut", IO.RandomAccessNotSupported))
  fun setPosOut {stream = strm as Out {writer = PIO.WR {setPos, name, ...}, ...}, position} =
    (flushBuffer (strm, "setPosOut");
     case setPos of
       SOME f => f position
     | NONE => ioError (name, "setPosOut", IO.RandomAccessNotSupported))
  fun filePosOut ({position, ...} : out_pos) = position
end
