(* libraries: test/unit *)
structure CTargetTests =
struct
  val lp64={char=8,short=16,int=32,long=64,longLong=64}
  val llp64={char=8,short=16,int=32,long=32,longLong=64}
  fun scan text=CLex.scan{file="target.h",text=text}
  fun scalar(size,alignment)={size=size,alignment=alignment,signed=NONE}
  fun facts (integers:CInteger.target) pointer doubleAlign : CLayout.target =
    {name="test-target",pointer=scalar(pointer,pointer),enumeration=scalar(4,4),
     maximumObject=valOf(IntInf.fromString "18446744073709551615"),
     scalars=[("char",scalar(1,1)),("signed char",scalar(1,1)),("unsigned char",scalar(1,1)),
       ("_Bool",scalar(1,1)),("short",scalar(2,2)),("unsigned short",scalar(2,2)),
       ("int",scalar(4,4)),("unsigned int",scalar(4,4)),
       ("long",scalar(#long integers div 8,#long integers div 8)),
       ("unsigned long",scalar(#long integers div 8,#long integers div 8)),
       ("long long",scalar(8,doubleAlign)),("unsigned long long",scalar(8,doubleAlign)),
       ("float",scalar(4,4)),("double",scalar(8,doubleAlign))]}
  fun lookup{namespace,name}=if namespace="typedef" andalso name="BYTE" then SOME(CParse.Builtin "unsigned char") else NONE
  fun integer integers ty=case ty of CParse.Named "BYTE"=>CType.integer{target=integers,charSigned=true,ty=CParse.Builtin "unsigned char"}
    | _=>CType.integer{target=integers,charSigned=true,ty=ty}
  fun evaluate integers pointer doubleAlign text =
    let val facts=facts integers pointer doubleAlign
        fun measure ty=let val layout=CLayout.compute{target=facts,source={file="target.h",line=1,column=1},ty=ty,
              lookup=lookup,constant=fn ts=> #integer(eval ts)}
          in {size=CLayout.size layout,alignment=CLayout.alignment layout} end
        and eval tokens=CExpression.evaluate{target=integers,
          sizeType=CInteger.integerType integers (if #long integers=pointer*8 then CInteger.Long else CInteger.LongLong) false,
          tokens=tokens,lookup=fn name=>if name="object" then SOME{ty=CParse.Pointer{target=CParse.Builtin "int",qualifiers=[]},value=NONE}
            else if name="badValue" then SOME{ty=CParse.Builtin "int",value=NONE} else NONE,
          resolveType=fn tokens=>CType.parse{tokens=tokens,typedefs=["BYTE"]},integerType=integer integers,measure=measure}
    in eval(scan text) end
  fun value text= #integer(evaluate lp64 8 8 text)
  fun result (text,expected)=Test.it text (fn()=>Expect.that(text,value text=expected))
  val expressions=List.map result
    [("(unsigned int)-1 + 1",0),("(unsigned char)257",1),("(signed char)255",~1),
     ("(BYTE)255 + 1",256),("(_Bool)2",1),("(_Bool)0",0),("(_Bool)-2",1),("(_Bool)256",1),("(_Bool)-256",1),
     ("(unsigned short)65535 + 1",65536),("-7 / 3",~2),("-7 % 3",~1),
     ("-1L < 1U",1),("0xffffffff + 1",0),("0 ? 1/0 : 7",7),
     ("1 ? 7 : 2147483647 + 1",7),("0 && 1/0",0),("1 || 1/0",1),
     ("(1 ? -1 : 1U) > 0",1),("(1 ? (unsigned char)255 : 1) + 1",256),
     ("sizeof(long)",8),("sizeof(unsigned short)",2),("sizeof(int[3][2])",24),
     ("sizeof(int *)",8),("sizeof(1 / 0)",4),("sizeof object",8),("sizeof *object",4),
     ("sizeof &badValue",8),("sizeof((int *)0)",8),("sizeof((unsigned char)1)",1),
     ("sizeof(1 ? 1L : 1U)",8),("_Alignof(double)",8),("__alignof__(object)",8)]
  val invalid=List.map(fn text=>Test.it ("reject " ^ text)(fn()=>Expect.that(text,
    ((ignore(value text);false)handle CExpression.Error _=>true | CLayout.Error _=>true))))
    ["1/0","2147483647+1","1 << 32","1 << -1","-1 << 1","(-2147483647-1)/-1",
     "0 && missing","1 ? 2 : missing","sizeof(void)","sizeof(unknown_t)","_Alignof(1)",
     "(int*)0","sizeof(struct incomplete)","sizeof &1","badValue","1 +","(int)()","sizeof(int[-1])",
     "L'a'","u'a'","U'a'","sizeof(extern int)","sizeof(int name)"]
  fun parse text=case #declarations(CParse.translationUnit{tokens=scan text,predefinedTypes=[]}) of
    CParse.Declaration{ctype,...}::_=>ctype | _=>raise Fail "declaration missing"
  fun layout facts text=CLayout.compute{target=facts,source={file="target.h",line=1,column=1},ty=parse text,
    lookup=lookup,constant=fn tokens=> #integer(CConst.evaluate{width=64,tokens=tokens,lookup=fn _=>NONE})}
  fun layoutTest name predicate=Test.it name(fn()=>Expect.that(name,predicate()))
  val layouts=List.map(fn (label,integers,pointer,doubleAlign)=>Test.describe label
    [layoutTest "pair" (fn()=>let val l=layout(facts integers pointer doubleAlign)"struct pair {int integer;double fraction;};"
      in CLayout.size l=IntInf.fromInt(if doubleAlign=4 then 12 else 16) andalso CLayout.alignment l=doubleAlign
        andalso #offset(CLayout.member(l,["fraction"]))=IntInf.fromInt doubleAlign end),
     layoutTest "anonymous fields" (fn()=>let val l=layout(facts integers pointer doubleAlign)
       "struct nested {char prefix;struct {int x;int y;};double tail;};"
       in #offset(CLayout.member(l,["y"]))=8 andalso #offset(CLayout.member(l,["tail"]))=IntInf.fromInt(if doubleAlign=4 then 12 else 16) end),
     layoutTest "union"(fn()=>let val l=layout(facts integers pointer doubleAlign)"union value {unsigned long long bits;double real;};"
       in CLayout.size l=8 andalso #offset(CLayout.member(l,["real"]))=0 end),
     layoutTest "nested arrays"(fn()=>CLayout.size(layout(facts integers pointer doubleAlign)"struct a {char c;int matrix[3][2];};")=28),
     layoutTest "flexible tail"(fn()=>CLayout.size(layout(facts integers pointer doubleAlign)"struct a {int count;char bytes[];};")=4),
     layoutTest "pragma packing"(fn()=>let val l=layout(facts integers pointer doubleAlign)
       "#pragma pack(push,1)\nstruct a {char c;int n;};\n#pragma pack(pop)\n"
       in CLayout.size l=5 andalso CLayout.alignment l=1 end)])
    [("LP64",lp64,8,8),("LLP64",llp64,8,8),("Win32",llp64,4,8),("i386",llp64,4,4)]
  val booleanConversions=List.map(fn(value,expected)=>layoutTest("boolean conversion " ^ IntInf.toString value)
    (fn()=> #integer(CInteger.convert {rank=CInteger.Char,width=1,signed=false}
      {integer=value,ty=CInteger.integerType lp64 CInteger.Int true})=expected))[(0,0),(1,1),(2,1),(~2,1),(256,1),(~256,1)]
  val tests=Test.describe "language/c/target" (expressions @ invalid @ layouts @ booleanConversions @
    [layoutTest "LLP64 long conversion"(fn()=> #integer(evaluate llp64 8 8 "-1L < 1U")=0),
     layoutTest "LLP64 decimal literal chooses long long"(fn()=> #rank(#ty(evaluate llp64 8 8 "2147483648"))=CInteger.LongLong),
     layoutTest "LP64 decimal literal chooses long"(fn()=> #rank(#ty(evaluate lp64 8 8 "2147483648"))=CInteger.Long),
     layoutTest "i386 double alignment"(fn()=> #integer(evaluate llp64 4 4 "_Alignof(double)")=4),
     layoutTest "bitfields require verified adapters"(fn()=>((ignore(layout(facts lp64 8 8)"struct a {unsigned x:3;};");false)handle CLayout.Shim _=>true)),
     layoutTest "builtin normalization"(fn()=>CType.canonical "long unsigned int"="unsigned long" andalso CType.canonical "unsigned __int64"="unsigned long long")])
end
structure CTargetMain=Main(struct val name="language/c/target" val tests=CTargetTests.tests end)
val ()=CTargetMain.main()
