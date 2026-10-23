(* Implements: RUNE_FOREIGN *)
structure RuneForeign :> RUNE_FOREIGN =
struct
  datatype scalar = Void | SInt8 | UInt8 | SInt16 | UInt16 | SInt32 | UInt32
    | SInt64 | UInt64 | Float32 | Float64 | Pointer
  datatype kind = Library | Symbol | Memory | View | Prepared of scalar list | DataPointer
  datatype resource = Resource of {id : Word64.word, live : bool ref, kind : kind}
  datatype argument = Signed of Int64.int | Unsigned of Word64.word | Real of real | Address of resource option
  type error = {number : int, native : Word32.word, message : string}
  type result = {bytes : string, pointer : resource option, error : error}
  exception Error of error
  val primitive = _prim "foreign" : int * Word64.word * Word64.word * string * string ->
    bool * Word64.word * string * string * int * Word32.word
  fun failure message = raise Error {number = 22, native = 0w0, message = message}
  fun identity (Resource {id, live, ...}) = if !live then id else failure "stale foreign resource"
  fun resource kind id = Resource {id = id, live = ref true, kind = kind}
  fun request (operation, id, auxiliary, metadata, bytes) =
    let val (ok, result, bytes, message, number, native) = primitive (operation, id, auxiliary, metadata, bytes)
        val error = {number = number, native = native, message = message}
    in if ok then (result, bytes, error) else raise Error error end
  fun available () = let val (value, _, _) = request (0, 0w0, 0w0, "", "") in value <> 0w0 end
  fun target () =
    let val (bits, _, _) = request (11, 0w0, 0w0, "", "")
    in {pointerBytes = Word64.toInt(Word64.andb(bits,0w255)),
        littleEndian = Word64.andb(bits,0w256) <> 0w0,
        stdcall = Word64.andb(bits,0w512) <> 0w0} end
  fun openLibrary name = let val (id, _, _) = request (1, 0w0, 0w0, name, "") in resource Library id end
  fun symbol (owner, name) = let val (id, _, _) = request (2, identity owner, 0w0, name, "") in resource Symbol id end
  fun allocate length = let val (id, _, _) = request (3, 0w0, length, "", "") in resource Memory id end
  fun wordBytes word = String.implode (List.tabulate (8, fn i =>
    Char.chr (Word64.toInt (Word64.andb (Word64.>> (word, Word.fromInt (i * 8)), 0w255)))))
  fun read (memory, offset, length) =
    if length < 0 then failure "negative foreign read length" else
    let val (_, bytes, _) = request (4, identity memory, offset, wordBytes (Word64.fromInt length), "") in bytes end
  fun write (memory, offset, bytes) = (ignore (request (5, identity memory, offset, "", bytes)); ())
  fun view (memory, offset, length) =
    let val (id, _, _) = request (6, identity memory, offset, wordBytes length, "") in resource View id end
  fun code Void = 0 | code SInt8 = 1 | code UInt8 = 2 | code SInt16 = 3 | code UInt16 = 4
    | code SInt32 = 5 | code UInt32 = 6 | code SInt64 = 7 | code UInt64 = 8
    | code Float32 = 9 | code Float64 = 10 | code Pointer = 11
  fun prepare {symbol, abi, result, arguments} =
    if abi < 0 orelse abi > 255 then failure "invalid foreign ABI" else
    let val metadata = String.implode (Char.chr abi :: Char.chr (code result) :: List.map (Char.chr o code) arguments)
        val (id, _, _) = request (8, identity symbol, 0w0, metadata, "")
    in resource (Prepared arguments) id end
  fun invoke (call as Resource {kind, ...}, arguments) =
    let val types = case kind of Prepared types => types | _ => failure "resource is not a prepared call"
        val () = if List.length types = List.length arguments then () else failure "foreign argument count mismatch"
        fun encode (ty, value) =
          let val bytes = case (ty, value) of
                (SInt8, Signed n) => wordBytes (Word64.fromLargeInt (Int64.toLarge n))
              | (SInt16, Signed n) => wordBytes (Word64.fromLargeInt (Int64.toLarge n))
              | (SInt32, Signed n) => wordBytes (Word64.fromLargeInt (Int64.toLarge n))
              | (SInt64, Signed n) => wordBytes (Word64.fromLargeInt (Int64.toLarge n))
              | (UInt8, Unsigned n) => wordBytes n | (UInt16, Unsigned n) => wordBytes n
              | (UInt32, Unsigned n) => wordBytes n | (UInt64, Unsigned n) => wordBytes n
              | (Float32, Real n) => Byte.bytesToString (PackReal64Little.toBytes n)
              | (Float64, Real n) => Byte.bytesToString (PackReal64Little.toBytes n)
              | (Pointer, Address NONE) => wordBytes 0w0
              | (Pointer, Address (SOME pointer)) => wordBytes (identity pointer)
              | _ => failure "foreign argument kind mismatch"
          in str (Char.chr (code ty)) ^ bytes end
        val data = String.concat (ListPair.map encode (types, arguments))
        val (pointer, bytes, error) = request (9, identity call, 0w0, "", data)
    in {bytes = bytes, pointer = if pointer = 0w0 then NONE else SOME (resource DataPointer pointer), error = error} end
  fun release (value as Resource {live, ...}) = (ignore (request (7, identity value, 0w0, "", "")); live := false)
  fun live () = let val (count, _, _) = request (10, 0w0, 0w0, "", "") in count end
end
