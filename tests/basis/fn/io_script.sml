(* Readers and writers whose behaviour a test fixes, for the checks of
   fn/stream_io_fn.sml and fn/imperative_io_fn.sml, which run the stream
   layers over them.

     structure R = IOScriptFn (TextRW)

   where TextRW : IO_RW builds the readers and writers of an instance of
   PRIM_IO (TextPrimIO.RD, TextPrimIO.WR) from the operations given and
   takes them apart again. That goes through a signature of its own rather
   than PRIM_IO, so that these checks also run on an implementation whose
   reader record differs from the specification in a field they do not use.
   Elements are written as the characters of a string: fromString and
   toString convert between strings and vectors (for bytes, character i is
   the byte i), and sliceVector is the vector of a vector slice, which only
   an instance whose slices are known provides (io_primio_sig.sml).

   A reader follows the rules of
   https://smlfamily.github.io/Basis/prim-io.html that concern its client:
   readVec n returns at most n elements, the empty vector for an
   end-of-stream, and every function but close raises Io {cause =
   ClosedStream, ...} after close. What it did is recorded in its log. *)
signature IO_RW =
sig
  type vector
  type vector_slice
  type reader
  type writer
  val fromString : string -> vector
  val toString : vector -> string
  val sliceVector : vector_slice -> vector
  val fullSlice : vector -> vector_slice
  (* a reader with the given name, chunkSize, readVec, readVecNB and close;
     avail says NONE and there is nothing else *)
  val mkReader : {name : string, chunkSize : int, readVec : int -> vector,
                  readVecNB : (int -> vector option) option, close : unit -> unit} -> reader
  (* a writer with the given name, chunkSize, writeVec and close, and
     writeArr made from writeVec, which a stream may need ("outstream
     supports: output, output1, etc. if augmented writer implements:
     writeArr", stream-io.html); nothing else *)
  val mkWriter : {name : string, chunkSize : int, writeVec : vector_slice -> int, close : unit -> unit} -> writer
  val readerName : reader -> string
  val readerReadVec : reader -> (int -> vector) option
  val readerClose : reader -> unit
  val writerName : writer -> string
  val writerWriteVec : writer -> (vector_slice -> int) option
  val writerClose : writer -> unit
end

functor IOScriptFn (RW : IO_RW) =
struct
  type log = {returned : string list ref,   (* what readVec returned, latest first *)
              reads : int ref,              (* calls of readVec and readVecNB *)
              closes : int ref,             (* calls of close *)
              written : string ref,         (* what the writer received, in order *)
              writes : int ref}             (* calls of writeVec *)

  fun newLog () : log = {returned = ref [], reads = ref 0, closes = ref 0, written = ref "", writes = ref 0}
  fun returned (log : log) = List.rev (!(#returned log))

  fun closedIo (name, function) = IO.Io {name = name, function = function, cause = IO.ClosedStream}

  (* Error of a reader or writer that a test breaks on purpose. *)
  exception Broken

  (* scripted {name, chunkSize, pieces, broken, blocked, nonBlocking}: a
     reader whose readVec hands out the pieces one after another. A piece
     longer than n is handed out in parts; the piece "" is an end-of-stream;
     after the last piece the reader stays at end-of-stream. While !broken
     is true readVec raises Broken. With nonBlocking it has readVecNB, which
     answers NONE (a read would block) while !blocked is true. *)
  fun scripted {name : string, chunkSize : int, pieces : string list,
                broken : bool ref, blocked : bool ref, nonBlocking : bool} : RW.reader * log =
    let
      val log = newLog ()
      val left = ref pieces
      fun check function = if !(#closes log) > 0 then raise closedIo (name, function) else ()
      fun take n =
        case !left of
          [] => ""
        | p :: rest =>
            if String.size p <= n then (left := rest; p)
            else (left := String.extract (p, n, NONE) :: rest; String.substring (p, 0, n))
      fun readVec n =
        (check "readVec";
         #reads log := !(#reads log) + 1;
         if n < 0 then raise Size
         else if !broken then raise Broken
         else let val s = take n in #returned log := s :: !(#returned log); RW.fromString s end)
      fun readVecNB n =
        (check "readVecNB";
         if !blocked then NONE else SOME (readVec n))
    in
      (RW.mkReader {name = name, chunkSize = chunkSize, readVec = readVec,
                    readVecNB = if nonBlocking then SOME readVecNB else NONE,
                    close = fn () => #closes log := !(#closes log) + 1},
       log)
    end

  (* reader (name, pieces): a scripted reader that is neither broken nor
     non-blocking, with a large chunkSize. *)
  fun reader (name : string, pieces : string list) : RW.reader * log =
    scripted {name = name, chunkSize = 1000, pieces = pieces, broken = ref false, blocked = ref false,
              nonBlocking = false}

  (* memWriter {name, chunkSize, most, broken}: a writer that keeps what it
     receives in the log. writeVec writes at most `most` elements at a time
     (a partial write, which the stream must complete), and raises Broken
     while !broken is true. *)
  fun memWriter {name : string, chunkSize : int, most : int, broken : bool ref} : RW.writer * log =
    let
      val log = newLog ()
      fun check function = if !(#closes log) > 0 then raise closedIo (name, function) else ()
      fun writeVec sl =
        let
          val () = check "writeVec"
          val () = #writes log := !(#writes log) + 1
          val s = RW.toString (RW.sliceVector sl)
          val k = if String.size s < most then String.size s else most
        in
          if !broken then raise Broken
          else (#written log := !(#written log) ^ String.substring (s, 0, k); k)
        end
    in
      (RW.mkWriter {name = name, chunkSize = chunkSize, writeVec = writeVec,
                    close = fn () => #closes log := !(#closes log) + 1},
       log)
    end

  (* writer name: a memWriter that takes everything at once, with a large
     chunkSize. *)
  fun writer (name : string) : RW.writer * log =
    memWriter {name = name, chunkSize = 1000, most = 1000000, broken = ref false}

  fun written (log : log) = !(#written log)
  fun closes (log : log) = !(#closes log)
  fun reads (log : log) = !(#reads log)

  (* The Io exception that f () raises, shown field by field. *)
  fun ioOf (f : unit -> unit) = (f (); NONE) handle IO.Io r => SOME r
  fun ioCause f =
    case ioOf f of
      SOME {cause = IO.ClosedStream, ...} => "ClosedStream"
    | SOME {cause = IO.RandomAccessNotSupported, ...} => "RandomAccessNotSupported"
    | SOME {cause = IO.BlockingNotSupported, ...} => "BlockingNotSupported"
    | SOME {cause = IO.NonblockingNotSupported, ...} => "NonblockingNotSupported"
    | SOME {cause = Broken, ...} => "Broken"
    | SOME {cause = Size, ...} => "Size"
    | SOME {cause = Subscript, ...} => "Subscript"
    | SOME _ => "<another cause>"
    | NONE => "<no Io>"
  fun ioName f = case ioOf f of SOME {name, ...} => name | NONE => "<no Io>"
  (* The exception at the end of the chain of causes of the Io that f ()
     raises, for an operation that may report the Io of another one it calls
     as its cause. *)
  fun ioRootCause f =
    let
      fun root (IO.Io {cause, ...}) = root cause
        | root e = e
    in
      case ((f (); NONE) handle e as IO.Io _ => SOME (root e)) of
        SOME Broken => "Broken"
      | SOME _ => "<another cause>"
      | NONE => "<no Io>"
    end
  val isIo = fn IO.Io _ => true | _ => false
end
