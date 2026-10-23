(* libraries: test/unit *)
structure CAnalysisTests =
struct
  val integers={char=8,short=16,int=32,long=64,longLong=64}
  fun scalar(size,alignment):CLayout.scalar={size=size,alignment=alignment,signed=NONE}
  val objects={name="LP64-test",pointer=scalar(8,8),enumeration=scalar(4,4),maximumObject=valOf(IntInf.fromString "9223372036854775807"),
    scalars=[("char",scalar(1,1)),("signed char",scalar(1,1)),("unsigned char",scalar(1,1)),
      ("short",scalar(2,2)),("unsigned short",scalar(2,2)),("int",scalar(4,4)),("unsigned int",scalar(4,4)),
      ("long",scalar(8,8)),("unsigned long",scalar(8,8)),("long long",scalar(8,8)),("unsigned long long",scalar(8,8)),
      ("float",scalar(4,4)),("double",scalar(8,8)),("_Bool",scalar(1,1))]}
  fun target rule={integers=integers,objects=objects,charSigned=true,sizeType=CInteger.integerType integers CInteger.Long false,enumRule=rule}
  fun scan text=CLex.scan{file="analysis.h",text=text}
  fun parse text= #declarations(CParse.translationUnit{tokens=scan text,predefinedTypes=[]})
  fun env rule text=CAnalysis.create{target=target rule,declarations=parse text}
  val declarations="typedef unsigned char BYTE; typedef long unsigned int ULONG; enum Scale {A=sizeof(long),B=A+1,C=(BYTE)257};\n" ^
    "struct Node {int value;struct Node *next;}; struct Array {BYTE bytes[B];}; int object; int *pointer;"
  val environment=env CAnalysis.UnsignedNonnegative declarations
  fun value e text= #integer(CAnalysis.expression e(scan text))
  val at={file="analysis.h",line=1,column=1}
  fun layout e text=CAnalysis.layout e {ty=CParse.typeName{tokens=scan text,predefinedTypes=["BYTE","ULONG","Bad","Vector"]},source=at}
  fun test name body=Test.it name(fn()=>Expect.that(name,body()))
  fun rejects body=((body();false)handle CAnalysis.Error _=>true | CLayout.Error _=>true | CExpression.Error _=>true)
  fun adapter body=((body();false)handle CLayout.Shim _=>true)
  val tests=Test.describe "language/c/analysis"
    [test "typedef cast"(fn()=>value environment "(BYTE)257 + 1"=2),
     test "target sizeof alias"(fn()=>value environment "sizeof(ULONG)"=8),
     test "typed enumeration and successor"(fn()=> #integer(CAnalysis.enumerator environment "B")=9 andalso #integer(CAnalysis.enumerator environment "C")=1),
     test "enumerator constants retain int type"(fn()=>value environment "sizeof(A)"=4),
     test "GNU nonnegative enum representation"(fn()=>value environment "((enum Scale)-1) < 0"=0),
     test "explicit signed enum representation"(fn()=>value(env CAnalysis.SignedEnums declarations)"((enum Scale)-1) < 0"=1),
     test "negative enums are signed"(fn()=>value(env CAnalysis.UnsignedNonnegative "enum Negative {N=-1};")"((enum Negative)-1) < 0"=1),
     test "macro values need no artificial enum conversion"(fn()=>value environment "0xffffffffU"=4294967295),
     test "object sizeof is unevaluated"(fn()=>value environment "sizeof(object)"=4),
     test "pointer object sizeof"(fn()=>value environment "sizeof pointer"=8 andalso value environment "sizeof *pointer"=4),
     test "objects are not integer constants"(fn()=>rejects(fn()=>ignore(value environment "object+1"))),
     test "tag resolution with recursive opaque pointer"(fn()=>CLayout.size(layout environment "struct Node")=16),
     test "typed enum array bound"(fn()=>CLayout.size(layout environment "struct Array")=9),
     test "member path"(fn()=> #offset(CLayout.member(layout environment "struct Node",["next"]))=8),
     test "equivalent scalar redeclarations"(fn()=>CLayout.size(layout(env CAnalysis.SignedEnums
       "typedef unsigned long int ULONG; typedef long unsigned ULONG;")"ULONG")=8),
     test "private ambiguity stays lazy"(fn()=>value(env CAnalysis.SignedEnums "typedef int Bad; typedef double Bad;")"42"=42),
     test "selected ambiguity diagnosed"(fn()=>rejects(fn()=>ignore(layout(env CAnalysis.SignedEnums "typedef int Bad; typedef double Bad;")"Bad"))),
     test "forward enum reference rejected"(fn()=>rejects(fn()=>ignore(CAnalysis.enumerator(env CAnalysis.SignedEnums "enum E {X=Y,Y=1};")"X"))),
     test "wide enum extension requires adapter"(fn()=>rejects(fn()=>ignore(CAnalysis.enumerator(env CAnalysis.SignedEnums "enum E {X=0xffffffffU};")"X"))),
     test "wide enum layout is not guessed"(fn()=>rejects(fn()=>ignore(layout(env CAnalysis.SignedEnums "enum E {X=0xffffffffU};")"enum E"))),
     test "cyclic value layout rejected"(fn()=>rejects(fn()=>ignore(layout(env CAnalysis.SignedEnums "struct Bad {struct Bad self;};")"struct Bad"))),
     test "alignment attributes survive tag indexing"(fn()=>adapter(fn()=>ignore(layout(env CAnalysis.SignedEnums
       "struct __attribute__((__aligned__(32))) Aligned {int value;};")"struct Aligned"))),
     test "integer vector mode is not a scalar"(fn()=>adapter(fn()=>ignore(CAnalysis.integer(env CAnalysis.SignedEnums
       "typedef int Vector __attribute__((vector_size(16)));")(CParse.Named "Vector")))),
     test "unknown selected attributes are visible"(fn()=>adapter(fn()=>ignore(layout(env CAnalysis.SignedEnums
       "struct __attribute__((future_representation)) Future {int value;};")"struct Future")))]
end
structure CAnalysisMain=Main(struct val name="language/c/analysis" val tests=CAnalysisTests.tests end)
val ()=CAnalysisMain.main()
