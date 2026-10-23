(* Source generation keeps implementation mechanisms and source identity explicit. *)
structure ForeignGenerateTests =
struct
  val location={file="original.h",line=1,column=1}
  val scalar={size=4,alignment=4,signed=SOME true}
  val profile : ForeignTarget.profile={name="fixture",triple="x86_64-linux-gnu",abi="sysv",byteOrder=ForeignModel.Little,
    predefined=[],analysis={integers={char=8,short=16,int=32,long=64,longLong=64},charSigned=true,
      sizeType={rank=CInteger.Long,width=64,signed=false},enumRule=CAnalysis.UnsignedNonnegative,
      objects={name="fixture",pointer={size=8,alignment=8,signed=NONE},enumeration=scalar,
        maximumObject=IntInf.<<(1,0w40),scalars=[("int",scalar),("_Bool",{size=1,alignment=1,signed=SOME false})]}}}
  val source="typedef struct Pair { int first; int second; } Pair; int add(int first, int second); _Bool invert(_Bool value);"
  val declarations= #declarations(CParse.translationUnit{tokens=CLex.scan{file="original.h",text=source},predefinedTypes=[]})
  val policyText="{\"version\":1,\"family\":\"c\",\"structure\":\"Generated\",\"headers\":[\"original.h\"],\"libraries\":[\"subject\"],\"functions\":[" ^
    "{\"foreign\":\"add\",\"name\":\"sum\",\"parameters\":[{\"name\":\"first\",\"type\":\"int\"},{\"name\":\"second\",\"type\":\"int\"}],\"result\":{\"type\":\"int\"},\"errors\":{\"predicate\":\"none\",\"capture\":\"none\"},\"variadic\":\"reject\",\"unsafeRaw\":false,\"input\":{\"record\":{\"first\":\"first\",\"second\":\"second\"}}}," ^
    "{\"foreign\":\"invert\",\"name\":\"invert\",\"parameters\":[{\"name\":\"value\",\"type\":\"bool\"}],\"result\":{\"type\":\"bool\"},\"errors\":{\"predicate\":\"none\",\"capture\":\"none\"},\"variadic\":\"reject\",\"unsafeRaw\":false}],\"resources\":[],\"callbacks\":[]}"
  val policy=ForeignPolicy.decode{file="policy.ffi",text=policyText}
  fun emit declarations fields=ForeignGenerate.emit{policy=policy,profile=profile,declarations=declarations,
    layouts=["Pair"],fields=fields,constants=[("HIGH",IntInf.<<(1,0w31)),("NEGATIVE",~7)],sourceName=fn _=>"mapped-original.h"}
  val generated=emit declarations [{aggregate="Pair",path=["first"],writable=true}]
  fun text path=case List.find(fn a:ForeignGenerate.artifact=> #path a=path)generated of SOME a=> #text a | NONE=>raise Fail "artifact absent"
  fun test name body=Test.it name(fn()=>Expect.that(name,body()))
  val tests=Test.describe "ffi/model/generate"
    [test "raw fixed scalar descriptor"(fn()=>String.isSubstring "result=RuneForeign.SInt32"(text "raw.sml")),
     test "C bool byte ABI"(fn()=>String.isSubstring "result=RuneForeign.UInt8"(text "raw.sml")),
     test "public record projection"(fn()=>String.isSubstring "{first : int, second : int}"(text "public_sig.sml")),
     test "public bool projection"(fn()=>String.isSubstring "bool -> bool"(text "public_sig.sml")),
     test "explicit raw session"(fn()=>String.isSubstring "type session"(text "raw_sig.sml")),
     test "lazy native acquisition"(fn()=>not(String.isSubstring "RuneForeign.openLibrary"(text "raw.sml"))),
     test "source mapping"(fn()=>String.isSubstring "mapped-original.h"(text "ffi-manifest.json")),
     test "native getter descriptor"(fn()=>String.isSubstring "rf_field_Pair_first_get"(text "raw.sml")),
     test "native setter descriptor"(fn()=>String.isSubstring "rf_field_Pair_first_set"(text "raw.sml")),
     test "typed original header shim"(fn()=>String.isSubstring "#include <original.h>"(text "shims.c")),
     test "target field offset"(fn()=>String.isSubstring "val offset_Pair_second = 4"(text "layout.sml")),
     test "integer constants retain sign and width"(fn()=>String.isSubstring "2147483648"(text "layout.sml") andalso String.isSubstring "~7"(text "layout.sml")),
     test "reordered traversal is identical"(fn()=>generated=emit(List.rev declarations)[{aggregate="Pair",path=["first"],writable=true}]),
     test "missing field rejected at generation"(fn()=>((ignore(emit declarations [{aggregate="Pair",path=["absent"],writable=false}]);false)
       handle CLayout.Error _=>true | ForeignGenerate.Error _=>true))]
end
structure ForeignGenerateMain=Main(struct val name="ffi/model/generate" val tests=ForeignGenerateTests.tests end)
val ()=ForeignGenerateMain.main()
