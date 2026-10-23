(* Explicit target data must be checked before selecting foreign declarations. *)
structure ForeignTargetTests =
struct
  fun object fields=Json.Object fields
  fun set key value (Json.Object fields)=Json.Object((key,value)::List.filter(fn(k,_)=>k<>key)fields)
    | set _ _ _=raise Fail "fixture object"
  val widths=object(List.map(fn(k,n)=>(k,Json.int n))
    [("char",1),("short",2),("int",4),("long",8),("longLong",8),("pointer",8),("size",8),("wchar",4),("float",4),("double",8),("bool",1)])
  val aligns=case widths of Json.Object fields=>object(List.filter(fn(k,_)=>k<>"size")fields) | _=>raise Fail "fixture"
  val base=object[("schema",Json.int 1),("name",Json.String "fixture"),("triple",Json.String "x86_64-linux-gnu"),
    ("abi",Json.String "sysv"),("byteOrder",Json.String "little"),("charSigned",Json.Bool true),
    ("enumRule",Json.String "unsigned-nonnegative"),("sizeType",Json.String "unsigned long"),
    ("widths",widths),("alignments",aligns),("verifiedBy",Json.String "oracle.c"),("predefined",Json.Array [])]
  fun decode value=ForeignTarget.decode{file="fixture.json",text=Json.encode value}
  fun rejects value=((ignore(decode value);false)handle ForeignTarget.Error({file,...},_)=>file="fixture.json")
  val profile=decode base
  fun test name body=Test.it name(fn()=>Expect.that(name,body()))
  val tests=Test.describe "ffi/model/target"
    [test "explicit ABI"(fn()=> #abi profile="sysv"),
     test "integer rank widths"(fn()=> #long(#integers(#analysis profile))=64),
     test "unsigned size type"(fn()=>not(#signed(#sizeType(#analysis profile)))),
     test "neutral model facts"(fn()=> #name(ForeignTarget.model profile)="fixture"),
     test "schema rejected"(fn()=>rejects(set "schema"(Json.int 2)base)),
     test "unknown target key rejected"(fn()=>rejects(set "command"(Json.String "cc")base)),
     test "ABI rejected"(fn()=>rejects(set "abi"(Json.String "guess")base)),
     test "byte order rejected"(fn()=>rejects(set "byteOrder"(Json.String "native")base)),
     test "enum policy required"(fn()=>rejects(set "enumRule"(Json.String "native")base)),
     test "size signedness checked"(fn()=>rejects(set "sizeType"(Json.String "long")base)),
     test "size width checked"(fn()=>rejects(set "sizeType"(Json.String "unsigned int")base)),
     test "Windows pointer width checked"(fn()=>rejects(set "abi"(Json.String "win32")base)),
     test "scalar zero width rejected"(fn()=>rejects(set "widths"(set "int"(Json.int 0)widths)base)),
     test "alignment power checked"(fn()=>rejects(set "alignments"(set "int"(Json.int 3)aligns)base)),
     test "alignment cannot exceed scalar size"(fn()=>rejects(set "alignments"(set "int"(Json.int 8)aligns)base)),
     test "target bool width checked"(fn()=>rejects(set "widths"(set "bool"(Json.int 4)widths)base)),
     test "verified oracle type checked"(fn()=>rejects(set "verifiedBy"(Json.Bool false)base)),
     test "duplicate target macros rejected"(fn()=>rejects(set "predefined"(Json.Array[
       Json.Array[Json.String "X",Json.String "1"],Json.Array[Json.String "X",Json.String "2"]])base)),
     test "function-like target macros retained"(fn()=> #predefined(decode(set "predefined"(Json.Array[
       Json.Array[Json.String "__has_builtin(x)",Json.String "0"]])base))=[("__has_builtin(x)","0")])]
end
structure ForeignTargetMain=Main(struct val name="ffi/model/target" val tests=ForeignTargetTests.tests end)
val ()=ForeignTargetMain.main()
