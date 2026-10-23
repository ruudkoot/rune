(* libraries: test/unit *)
(* Source generation keeps implementation mechanisms and source identity explicit. *)
structure ForeignGenerateTests =
struct
  val location={file="original.h",line=1,column=1}
  val scalar={size=4,alignment=4,signed=SOME true}
  val profile : ForeignTarget.profile={name="fixture",triple="x86_64-linux-gnu",abi="sysv",byteOrder=ForeignModel.Little,
    predefined=[],analysis={integers={char=8,short=16,int=32,long=64,longLong=64},charSigned=true,
      sizeType={rank=CInteger.Long,width=64,signed=false},enumRule=CAnalysis.UnsignedNonnegative,
      objects={name="fixture",pointer={size=8,alignment=8,signed=NONE},enumeration=scalar,
        maximumObject=IntInf.<<(1,0w40),scalars=[("char",{size=1,alignment=1,signed=SOME true}),("short",{size=2,alignment=2,signed=SOME true}),("int",scalar),("long",{size=8,alignment=8,signed=SOME true}),("long long",{size=8,alignment=8,signed=SOME true}),("wchar_t",scalar),("float",scalar),("double",{size=8,alignment=8,signed=NONE}),("_Bool",{size=1,alignment=1,signed=SOME false})]}}}
  val source="typedef struct Pair { int first; int second; } Pair; int add(int first, int second); _Bool invert(_Bool value);"
  val declarations= #declarations(CParse.translationUnit{tokens=CLex.scan{file="original.h",text=source},predefinedTypes=[]})
  val policyText="{\"version\":1,\"family\":\"c\",\"structure\":\"Generated\",\"headers\":[\"original.h\"],\"libraries\":[\"subject\"],\"functions\":[" ^
    "{\"foreign\":\"add\",\"name\":\"sum\",\"parameters\":[{\"name\":\"first\",\"type\":\"int\"},{\"name\":\"second\",\"type\":\"int\"}],\"result\":{\"type\":\"int\"},\"errors\":{\"predicate\":\"none\",\"capture\":\"none\"},\"variadic\":\"reject\",\"unsafeRaw\":false,\"input\":{\"record\":{\"first\":\"first\",\"second\":\"second\"}}}," ^
    "{\"foreign\":\"invert\",\"name\":\"invert\",\"parameters\":[{\"name\":\"value\",\"type\":\"bool\"}],\"result\":{\"type\":\"bool\"},\"errors\":{\"predicate\":\"none\",\"capture\":\"none\"},\"variadic\":\"reject\",\"unsafeRaw\":false}],\"resources\":[],\"callbacks\":[]}"
  val policy=ForeignPolicy.decode{file="policy.ffi",text=policyText}
  fun emit declarations fields=ForeignGenerate.emit{policy=policy,profile=profile,declarations=declarations,macros=[],
    layouts=["Pair"],fields=fields,constants=[("HIGH",IntInf.<<(1,0w31)),("NEGATIVE",~7)],sourceName=fn _=>"mapped-original.h"}
  val generated=emit declarations [{aggregate="Pair",path=["first"],writable=true}]
  fun text path=case List.find(fn a:ForeignGenerate.artifact=> #path a=path)generated of SOME a=> #text a | NONE=>raise Fail "artifact absent"
  val macroInput=CPreprocess.run{source={file="macros.h",text="#define MACRO(value) ((value)+1)\nint variadic(int count, ...);\n"},
    predefined=[],resolve=fn _=>NONE,width=64,maxDepth=16,maxExpansions=1000}
  val macroDeclarations= #declarations(CParse.translationUnit{tokens= #tokens macroInput,predefinedTypes=[]})
  fun adapterPolicy namespace foreign shim=
    let val fields=[("foreign",Json.String foreign),("namespace",Json.String namespace),("name",Json.String "selected"),
          ("parameters",Json.Array[Json.Object[("name",Json.String "value"),("type",Json.String "int")]]),
          ("result",Json.Object[("type",Json.String "int")]),("errors",Json.Object[("predicate",Json.String "none"),("capture",Json.String "none")]),
          ("variadic",Json.String "reject"),("unsafeRaw",Json.Bool false)] @ (case shim of NONE=>[] | SOME text=>[("shim",Json.String text)])
        val document=Json.Object[("version",Json.int 1),("family",Json.String "c"),("structure",Json.String "Fixed"),
          ("headers",Json.Array[Json.String "macros.h"]),("libraries",Json.Array[Json.String "subject"]),
          ("functions",Json.Array[Json.Object fields]),("resources",Json.Array[]),("callbacks",Json.Array[])]
    in ForeignPolicy.decode{file="fixed.ffi",text=Json.encode document} end
  fun fixed namespace foreign shim=ForeignGenerate.emit{policy=adapterPolicy namespace foreign shim,profile=profile,
    declarations=macroDeclarations,macros= #macros macroInput,layouts=[],fields=[],constants=[],sourceName=fn name=>name}
  fun fixedText path=case List.find(fn a:ForeignGenerate.artifact=> #path a=path)(fixed "macro" "MACRO" (SOME "int MACRO(int value)")) of
      SOME a=> #text a | NONE=>raise Fail "fixed artifact absent"
  fun rejectsFixed namespace foreign text=((ignore(fixed namespace foreign text);false)handle ForeignModel.Error _=>true)
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
     test "macro fixed typed shim emitted"(fn()=>String.isSubstring "rf_call_MACRO"(fixedText "shims.c")),
     test "macro namespace and shimmed provenance retained"(fn()=>String.isSubstring "\"namespace\": \"macro\""(fixedText "ffi-manifest.json") andalso String.isSubstring "shimmed"(fixedText "ffi-manifest.json")),
     test "macro prototype required"(fn()=>rejectsFixed "macro" "MACRO" NONE),
     test "unknown macro rejected"(fn()=>rejectsFixed "macro" "MISSING"(SOME "int MISSING(int value)")),
     test "prototype name checked"(fn()=>rejectsFixed "macro" "MACRO"(SOME "int OTHER(int value)")),
     test "macro argument count checked"(fn()=>rejectsFixed "macro" "MACRO"(SOME "int MACRO(int value, int other)")),
     test "prototype body rejected"(fn()=>rejectsFixed "macro" "MACRO"(SOME "int MACRO(int value) { return value; }")),
     test "multiple prototypes rejected"(fn()=>rejectsFixed "macro" "MACRO"(SOME "int MACRO(int value); int OTHER(void)")),
     test "array expressions rejected in prototype"(fn()=>rejectsFixed "macro" "MACRO"(SOME "int MACRO(int value[8])")),
     test "behavioral attributes rejected in prototype"(fn()=>rejectsFixed "macro" "MACRO"(SOME "__attribute__((constructor)) int MACRO(int value)")),
     test "fixed variadic tail resolves"(fn()=>not(null(fixed "function" "variadic"(SOME "int variadic(int count, short value)")))),
     test "variadic prefix type checked"(fn()=>rejectsFixed "function" "variadic"(SOME "int variadic(long count, int value)")),
     test "variadic result type checked"(fn()=>rejectsFixed "function" "variadic"(SOME "long variadic(int count, int value)")),
     test "shim itself cannot be variadic"(fn()=>rejectsFixed "function" "variadic"(SOME "int variadic(int value, ...)")),
     test "missing field rejected at generation"(fn()=>((ignore(emit declarations [{aggregate="Pair",path=["absent"],writable=false}]);false)
       handle CLayout.Error _=>true | ForeignGenerate.Error _=>true))]
end
structure ForeignGenerateMain=Main(struct val name="ffi/model/generate" val tests=ForeignGenerateTests.tests end)
val ()=ForeignGenerateMain.main()
