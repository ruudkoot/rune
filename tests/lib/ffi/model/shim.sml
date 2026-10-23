(* libraries: test/unit *)
structure ForeignShimTests =
struct
  fun test name predicate=Test.it name(fn()=>Expect.that(name,predicate()))
  fun tokens text=CLex.scan{file="type.h",text=text}
  fun ty text=CParse.typeName{tokens=tokens text,predefinedTypes=["T"]}
  fun normalize(CParse.Builtin name)=CParse.Builtin(CType.canonical name)
    | normalize(CParse.Pointer{target,qualifiers})=CParse.Pointer{target=normalize target,qualifiers=qualifiers}
    | normalize(CParse.Array{element,bound})=CParse.Array{element=normalize element,bound=tokens(String.concatWith " "(List.map #text bound))}
    | normalize(CParse.Function{result,parameters,variadic,prototype})=CParse.Function{result=normalize result,
        parameters=List.map(fn CParse.Parameter{ctype,name}=>CParse.Parameter{ctype=normalize ctype,name=name})parameters,
        variadic=variadic,prototype=prototype}
    | normalize ty=ty
  fun roundTrip spelling=
    let val original=ty spelling
        val output=CDeclarator.declaration(original,"item") ^ ";"
    in case #declarations(CParse.translationUnit{tokens=tokens output,predefinedTypes=["T"]}) of
      [CParse.Declaration{ctype,name=SOME "item",...}]=>normalize ctype=normalize original | _=>false end
  val declarations=List.map(fn spelling=>test("C declarator " ^ spelling)(fn()=>roundTrip spelling))
    ["int","unsigned long int","int *","char **","T *[3]","int (*)[3]","int (*)(void *, int)",
     "int (**)(int)","int (int, double)","int (*(int))(double)","void (int, ...)","struct original *","union original *","enum original"]
  val scalar=CParse.Builtin "int"
  fun wrapper name args=ForeignShim.call{name=name,foreign="original",result=scalar,
    parameters=[scalar],indirectResult=false,indirectArguments=args}
  fun rejects action=((action();false)handle ForeignShim.Error _=>true | CDeclarator.Error _=>true)
  val tests=Test.describe "ffi/model/shim"(declarations @
    [test "adapter macro calls original declaration"(fn()=>String.isSubstring "return original(runeffi_argument_0);"(wrapper "adapter" [false])),
     test "aggregate adapter dereferences native copy"(fn()=>String.isSubstring "return original(*runeffi_argument_0);"(wrapper "adapter" [true])),
     test "indirect result uses a target C object copy"(fn()=>String.isSubstring "sizeof runeffi_result"
       (ForeignShim.call{name="adapter",foreign="original",result=CParse.Named "T",parameters=[],indirectResult=true,indirectArguments=[]})),
     test "function-pointer member getter has complete declarator"(fn()=>String.isSubstring "(*adapter_get("
       (ForeignShim.field{name="adapter",aggregate=CParse.Named "T",path=["callback"],ty=ty "int (*)(int)",writable=false})),
     test "mismatched arguments rejected"(fn()=>rejects(fn()=>ignore(wrapper "adapter" []))),
     test "source injection in wrapper name rejected"(fn()=>rejects(fn()=>ignore(wrapper "adapter;bad" [false]))),
     test "source injection in include rejected"(fn()=>rejects(fn()=>ignore(ForeignShim.preamble["bad.h>\n#error injected"]))),
     test "parent include path rejected"(fn()=>rejects(fn()=>ignore(ForeignShim.preamble["../other.h"]))),
     test "anonymous aggregate requires a named alias"(fn()=>rejects(fn()=>ignore(CDeclarator.declaration(ty "struct {int value;}","item"))))])
end
structure ForeignShimMain=Main(struct val name="ffi/model/shim" val tests=ForeignShimTests.tests end)
val ()=ForeignShimMain.main()
