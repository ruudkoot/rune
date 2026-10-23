(* Implements: RUNE_FOREIGN *)
structure RuneForeign :> RUNE_FOREIGN =
struct
  datatype scalar = Void | SInt8 | UInt8 | SInt16 | UInt16 | SInt32 | UInt32
    | SInt64 | UInt64 | Float32 | Float64 | Pointer
  datatype kind = Library | Symbol | Memory | View | Prepared of scalar list | DataPointer | Callback | Handle
  datatype resource = Resource of {id : Word64.word, live : bool ref, kind : kind}
  datatype argument = Signed of Int64.int | Unsigned of Word64.word | Real of real | Address of resource option
  datatype callbackFailure = Default of argument | ByArgument of
    {index : int, cases : (Word64.word * argument) list, default : argument}
  datatype failure = NoFailure | Zero | Nonzero | Negative
  type error = {number : int, native : Word32.word, message : string}
  type result = {bytes : string, pointer : resource option, error : error}
  exception Error of error
  val primitive = _prim "foreign" : int * Word64.word * Word64.word * string * string ->
    bool * Word64.word * string * string * int * Word32.word
  val callbackPrimitive = _prim "foreign_callback" : string * string * (string -> string) ->
    bool * Word64.word * string * int * Word32.word
  val activations : exn option ref list ref = ref []
  fun activation body =
    let val pending : exn option ref = ref NONE
        val previous = !activations
        val ()=activations:=pending::previous
    in let val result=body() val ()=activations:=previous in (result,!pending) end
      handle error => (activations:=previous;case !pending of NONE=>raise error | SOME saved=>raise saved) end
  fun pendingException () = case !activations of pending::_=> !pending | []=>NONE
  fun saveException error = case !activations of []=>() | pending::_=>
    (case !pending of NONE=>pending:=SOME error | SOME _=>())
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
  fun abiFacts () =
    let val (_,bytes,_)=request(17,0w0,0w0,"","")
        fun byte i=Char.ord(String.sub(bytes,i))
        val ()=if size bytes=24 andalso byte 0=1 then () else failure "unsupported foreign ABI facts version"
        val architecture=case byte 1 of 1=>"x86_64" | 2=>"x86" | 3=>"aarch64" | 4=>"powerpc64" | _=>"other"
        val names=["char","short","int","long","longLong","pointer","wchar","float","double","bool"]
        fun facts([],_,acc)=List.rev acc
          | facts(name::rest,i,acc)=facts(rest,i+2,{name=name,size=byte i,alignment=byte(i+1)}::acc)
    in {architecture=architecture,charBits=byte 2,charSigned=byte 3<>0,scalars=facts(names,4,[])} end
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
  fun encodeArguments (Resource {kind, ...}, arguments) =
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
    in String.concat (ListPair.map encode (types, arguments)) end
  fun callback {abi,result,arguments,function,failure=policy} =
    let val ()=if abi<0 orelse abi>255 then failure "invalid callback ABI" else ()
        fun encode value = case result of Void=>str(Char.chr 0)^wordBytes 0w0
          | _=>encodeArguments(Resource{id=0w0,live=ref true,kind=Prepared[result]},[value])
        val default=case policy of Default value=>value | ByArgument{default,...}=>default
        val defaultBytes=encode default
        val cases=case policy of Default _=>"" | ByArgument{index,cases,...}=>
          if index<0 orelse index>=List.length arguments then failure "callback failure argument is out of range"
          else String.concat(List.map(fn(key,value)=>wordBytes(Word64.fromInt index)^wordBytes key^encode value)cases)
        fun word bytes = PackWord64Little.subVec(Byte.stringToBytes bytes,0)
        fun decode (ty,bytes) = case ty of
            SInt8=>Signed(Int64.fromLarge(Word64.toLargeIntX(word bytes)))
          | SInt16=>Signed(Int64.fromLarge(Word64.toLargeIntX(word bytes)))
          | SInt32=>Signed(Int64.fromLarge(Word64.toLargeIntX(word bytes)))
          | SInt64=>Signed(Int64.fromLarge(Word64.toLargeIntX(word bytes)))
          | UInt8=>Unsigned(word bytes) | UInt16=>Unsigned(word bytes)
          | UInt32=>Unsigned(word bytes) | UInt64=>Unsigned(word bytes)
          | Float32=>Real(PackReal64Little.fromBytes(Byte.stringToBytes bytes))
          | Float64=>Real(PackReal64Little.fromBytes(Byte.stringToBytes bytes))
          | Pointer=>let val id=word bytes in Address(if id=0w0 then NONE else SOME(resource DataPointer id)) end
          | Void=>failure "void callback parameter"
        fun enter bytes =
          let fun get([],_,values)=List.rev values
                | get(ty::rest,i,values)=get(rest,i+9,decode(ty,String.substring(bytes,i+1,8))::values)
              val values=get(arguments,0,[])
              val fallback=case policy of Default _=>defaultBytes | ByArgument{index,cases,...}=>
                let val key=word(String.substring(bytes,index*9+1,8))
                in case List.find(fn(k,_)=>k=key)cases of NONE=>defaultBytes | SOME(_,value)=>encode value end
          in case pendingException() of SOME _=>fallback ^ "\001"
            | NONE=>(encode(function values) ^ "\000" handle error => (saveException error;fallback ^ "\001")) end
          handle error => (saveException error;defaultBytes ^ "\001")
        val metadata=String.implode(Char.chr abi::Char.chr(code result)::List.map(Char.chr o code)arguments)
        val (ok,id,message,number,native)=callbackPrimitive(metadata,defaultBytes^cases,enter)
    in if ok then resource Callback id else raise Error{message=message,number=number,native=native} end
  fun invokeDeferred (call, arguments) =
    let val data=encodeArguments(call,arguments)
        val ((pointer,bytes,error),saved)=activation(fn()=>request(9,identity call,0w0,"",data))
        val result={bytes=bytes,pointer=if pointer=0w0 then NONE else SOME(resource DataPointer pointer),error=error}
    in {result=result,callbackException=saved} end
  fun invoke requestValue =
    let val {result,callbackException}=invokeDeferred requestValue
    in case callbackException of NONE=>result | SOME error=>
      ((case #pointer result of NONE=>() | SOME(value as Resource{live,...})=>
          (ignore(request(7,identity value,0w0,"",""));live:=false));raise error) end
  fun disposeWith operation {resource=value as Resource{live,...},call,arguments,failure} =
    let val data=encodeArguments(call,arguments)
        val predicate=case failure of NoFailure=>0 | Zero=>1 | Nonzero=>2 | Negative=>3
        val ((disposed,bytes,error),saved)=activation(fn()=>request(operation,identity call,identity value,str(Char.chr predicate),data))
        val disposed=disposed<>0w0
        val ()=if disposed then live:=false else ()
        val ()=case saved of NONE=>() | SOME error=>raise error
    in {disposed=disposed,result={bytes=bytes,pointer=NONE,error=error}} end
  val dispose=disposeWith 12
  val consumeHandle=disposeWith 16
  val handles : resource list ref = ref []
  fun aliasHandle pointer =
    let val(id,_,_)=request(15,identity pointer,0w0,"","")
        val current=List.filter(fn Resource{live,...}=> !live)(!handles)
    in case List.find(fn Resource{id=other,...}=>id=other)current of SOME handleValue=>handleValue
      | NONE=>let val value=resource Handle id in handles:=value::current;value end end
  fun sameAddress(left,right)=
    let val (same,_,_)=request(13,identity left,identity right,"","") in same<>0w0 end
  fun isLive(Resource{id,live,...})=if not(!live) then false else
    let val (present,_,_)=request(14,id,0w0,"","") val found=present<>0w0
    in if found then true else (live:=false;false) end
  fun release (value as Resource {live, ...}) = (ignore (request (7, identity value, 0w0, "", "")); live := false)
  fun live () = let val (count, _, _) = request (10, 0w0, 0w0, "", "") in count end
end
