structure ForeignPolicyTests =
struct
  val checks = ref 0
  fun check (label, b) = (checks := !checks + 1; if b then () else raise Fail label)
  val source = {file = "subject.h", text =
    "typedef int count_t; struct node { struct node *next; count_t value; }; int sum(count_t value); int old(); long double difficult(long double x); int variadic(unsigned count,...); void buffer(char *data,double size); void immutable(const char *data); int fetch(int *out); int getter(void); int echo(int value); char *copy(const char *text); void release(void *memory); typedef int (*callback_t)(void *context,int value);"}
  val declarations = ForeignModel.fromC (#declarations (CParse.translationUnit {tokens = CLex.scan source, predefinedTypes = []}))
  fun value members = Json.Object members
  val noErrors = value [("predicate",Json.String "none"),("capture",Json.String "none")]
  val parameter = value [("name",Json.String "text"),("direction",Json.String "in"),
    ("ownership",value [("borrowed",Json.String "call")]),("nullable",Json.Bool false),
    ("encoding",Json.String "utf8"),("terminator",Json.Bool true),("type",Json.String "string")]
  val result = value [("ownership",value [("owned",Json.String "release")]),("nullable",Json.Bool false),
    ("encoding",Json.String "utf8"),("terminator",Json.Bool true),("type",Json.String "string")]
  fun selection parameters result = value [("foreign",Json.String "copy"),("name",Json.String "copyString"),
    ("parameters",Json.Array parameters),("result",result),("errors",noErrors),
    ("variadic",Json.String "reject"),("unsafeRaw",Json.Bool false)]
  fun policy functions = value [("version",Json.int 1),("family",Json.String "c"),
    ("structure",Json.String "Fixture"),("headers",Json.Array [Json.String "subject.h"]),
    ("libraries",Json.Array [Json.String "fixture"]),("functions",Json.Array functions),("callbacks",Json.Array [])]
  fun decode v = ForeignPolicy.decode {file="subject.ffi",text=Json.encode v}
  fun resolve v = ForeignValidate.resolve {declarations=declarations,policy=decode v}
  val valid = policy [selection [parameter] result]
  val () = check ("explicit owned string policy", length (resolve valid) = 1)
  val () = check ("source identity namespace", isSome (ForeignModel.find (declarations,{family="c",namespace="function",name="copy"})))
  val () = check ("identity delimiters cannot collide", ForeignModel.key {family="c:a",namespace="b",name="x"} <>
    ForeignModel.key {family="c",namespace="a:b",name="x"})
  val () = check ("SML keyword escape", ForeignPolicy.rawName "type" = "c_type")
  val () = check ("underscore escape", ForeignPolicy.rawName "_private" = "c__private")
  fun rejects v = ((ignore (resolve v);false) handle ForeignPolicy.Error _ => true | ForeignValidate.Error _ => true)
  val () = check ("pointer annotation cannot be omitted", rejects (policy [selection [] result]))
  val () = check ("returned pointer ownership cannot be omitted", rejects (policy [selection [parameter] (value [])]))
  val () = check ("duplicate selection rejected", rejects (policy [selection [parameter] result,selection [parameter] result]))
  val duplicate = "{\n\"version\":1,\n\"version\":1,\n\"family\":\"c\"}"
  val () = check ("duplicate field points to second key", ((ignore (ForeignPolicy.decode {file="bad.ffi",text=duplicate});false)
    handle ForeignPolicy.Error ({file,line,...},message) => file="bad.ffi" andalso line=3 andalso String.isSubstring "duplicate" message))
  val () = check ("unknown executable key rejected", ((ignore (ForeignPolicy.decode {file="bad.ffi",text="{\"shell\":\"touch unsafe\"}"});false)
    handle ForeignPolicy.Error (_,message) => String.isSubstring "unknown field" message))
  val () = check ("projection cannot inject source", ((ignore (decode (policy [selection [parameter] (value [("type",Json.String "int; val x=1")]) ]));false)
    handle ForeignPolicy.Error _ => true))
  fun set name replacement object = case object of Json.Object fields =>
        Json.Object((name,replacement)::List.filter(fn(key,_)=>key<>name)fields)
    | _ => raise Fail "test object"
  fun remove name object = case object of Json.Object fields => Json.Object(List.filter(fn(key,_)=>key<>name)fields)
    | _ => raise Fail "test object"
  fun selected name parameters result = set "foreign" (Json.String name) (selection parameters result)
  val ()=check("unprototyped selected function rejected",rejects(policy[selected "old" [] (value[])]))
  val ()=check("unsupported long double rejected",rejects(policy[selected "difficult" [] (value[])]))
  val ()=check("variadic safe wrapper requires an adapter",rejects(policy[selected "variadic" [] (value[])]))
  val ()=check("explicit raw varargs selection",length(resolve(policy[set "variadic" (Json.String "raw")
    (set "unsafeRaw" (Json.Bool true)(selected "variadic" [] (value[])))]))=1)
  val ()=check("missing string termination rejected",rejects(policy[selection [remove "terminator" parameter] result]))
  val ()=check("stale parameter annotation rejected",rejects(policy[selection [set "name" (Json.String "stale")parameter]result]))
  val ()=check("duplicate parameter rejected",rejects(policy[selection [parameter,parameter]result]))
  val ()=check("nullable input requires option",rejects(policy[selection [set "nullable" (Json.Bool true)parameter]result]))
  val ()=check("non-null input contradicts option",rejects(policy[selection [set "type" (value[("option",Json.String "string")])parameter]result]))
  val ()=check("unknown resource rejected",rejects(policy[selection [set "type" (value[("resource",Json.String "missing")])parameter]result]))
  val ()=check("unknown borrowed scope rejected",rejects(policy[selection [set "ownership" (value[("borrowed",Json.String "forever-maybe")])parameter]result]))
  val ()=check("unknown deallocator rejected",rejects(policy[selection [parameter](set "ownership" (value[("owned",Json.String "stale")])result)]))
  val ()=check("zero-argument deallocator rejected",rejects(policy[selection [parameter](set "ownership" (value[("owned",Json.String "getter")])result)]))
  val ()=check("unknown length rejected",rejects(policy[selection [set "length" (Json.String "stale")parameter]result]))
  val bufferParameter=set "name" (Json.String "data") (set "length" (Json.String "size")parameter)
  val ()=check("non-integral length rejected",rejects(policy[selected "buffer" [bufferParameter](value[])]))
  val writable=set "direction" (Json.String "out") (set "length" (Json.int 8) (set "name" (Json.String "data")parameter))
  val ()=check("const output rejected",rejects(policy[selected "immutable" [writable](value[])]))
  val textErrors=value[("predicate",Json.String "null"),("capture",Json.String "text"),("getter",Json.String "getter")]
  val ()=check("non-string error getter rejected",rejects(policy[set "errors" textErrors(selection [parameter]result)]))
  val ()=check("unknown projected input rejected",rejects(policy[set "input" (Json.String "missing")(selection [parameter]result)]))
  val out=value[("name",Json.String "out"),("direction",Json.String "out"),("ownership",value[("borrowed",Json.String "call")]),
    ("nullable",Json.Bool false),("type",Json.String "int32"),("output",Json.String "answer")]
  val ()=check("returned scalar output accepted",length(resolve(policy[selected "fetch" [out](value[])]))=1)
  val ()=check("output cannot be an input leaf",rejects(policy[set "input" (Json.String "out")(selected "fetch" [out](value[]))]))
  val callback=value[("foreign",Json.String "callback_t"),("lifetime",Json.String "registered"),
    ("owner",Json.String "registration"),("thread",Json.String "owner-vm-thread"),("failure",Json.int ~1)]
  val ()=check("explicit retained callback policy accepted",length(resolve(set "callbacks" (Json.Array[callback])(policy[selection [parameter]result])))=1)
  val ()=check("retained callback needs owner",rejects(set "callbacks" (Json.Array[remove "owner" callback])(policy[])))
  val ()=check("foreign thread rejected",rejects(set "callbacks" (Json.Array[set "thread" (Json.String "attach")callback])(policy[])))
  val ()=check("selected aliases retained",List.exists(fn d:ForeignModel.declaration=> #name(#identity d)="count_t")
    (ForeignModel.reachable(declarations,[{family="c",namespace="function",name="sum"}])))
  val parsed= #declarations(CParse.translationUnit{tokens=CLex.scan source,predefinedTypes=[]})
  val ()=check("traversal order does not affect model",ForeignModel.fromC parsed=ForeignModel.fromC(rev parsed))
  val projection=ForeignPolicy.Fields[("count",ForeignPolicy.Value "count"),("bytes",ForeignPolicy.Value "bytes")]
  val projected=ForeignProjection.typeOf{source={file="golden.ffi",line=1,column=1},
    values=[("bytes",ForeignPolicy.Scalar "bytes"),("count",ForeignPolicy.Scalar "int32")],projection=projection}
  val ()=check("record projection golden",ForeignProjection.renderType projected="{count : Int32.int, bytes : Word8Vector.vector}")
  val ()=check("option projection golden",ForeignProjection.renderType(ForeignPolicy.Option(ForeignPolicy.Scalar "string"))="string option")
  val copyID={family="c",namespace="function",name="copy"}
  val report=ForeignCoverage.report{declarations=declarations,selected=[copyID],generated=[],shimmed=[],unsupported=[]}
  val ()=check("selection is not generation",List.exists(fn e:ForeignCoverage.entry=> #identity e=copyID andalso #state e=ForeignCoverage.Selected)report)
  val ()=check("coverage traversal deterministic",Json.encode(ForeignCoverage.json report)=Json.encode(ForeignCoverage.json
    (ForeignCoverage.report{declarations=rev declarations,selected=[copyID],generated=[],shimmed=[],unsupported=[]})))
  val ()=check("conflicting implementation claims rejected",((ignore(ForeignCoverage.report{declarations=declarations,
    selected=[copyID],generated=[copyID],shimmed=[copyID],unsupported=[]});false)handle ForeignCoverage.Error _=>true))
  val ()=check("ambiguous selected redeclaration rejected",let val more= #declarations(CParse.translationUnit{
    tokens=CLex.scan{file="other.h",text="double copy(int count);"},predefinedTypes=[]})
    in ((ignore(ForeignModel.find(ForeignModel.fromC(parsed @ more),copyID));false)handle ForeignModel.Error _=>true) end)
  val ()=check("input cannot omit native arguments",rejects(policy[set "input" (value[("unit",Json.Bool true)])(selection [parameter]result)]))
  val copyPolicy=hd(#functions(decode valid))
  val copyType=ForeignProjection.callType{policy=copyPolicy,inputs=[("text",ForeignPolicy.Scalar "string")],result=ForeignPolicy.Scalar "string"}
  val ()=check("idiomatic signature golden",ForeignProjection.renderType(#input copyType) ^ " -> " ^
    ForeignProjection.renderType(#output copyType)="string -> string")
  val fetchPolicy=hd(#functions(decode(policy[selected "fetch" [out](value[("type",Json.String "unit")])])))
  val fetchType=ForeignProjection.callType{policy=fetchPolicy,inputs=[("out",ForeignPolicy.Scalar "int32")],result=ForeignPolicy.Scalar "int32"}
  val ()=check("output parameter becomes returned record",ForeignProjection.renderType(#input fetchType) ^ " -> " ^
    ForeignProjection.renderType(#output fetchType)="unit -> {answer : Int32.int}")
  val conflicting= #declarations(CParse.translationUnit{tokens=CLex.scan{file="same.h",text="int conflict(int x); double conflict(double y); int conflict(int z);"},predefinedTypes=[]})
  val conflictID={family="c",namespace="function",name="conflict"}
  val ()=check("coalescing cannot erase incompatible declarations",List.all(fn input=>
    ((ignore(ForeignModel.find(ForeignModel.fromC input,conflictID));false)handle ForeignModel.Error _=>true))
    [conflicting,rev conflicting])
  val macros= #macros(CPreprocess.run{source={file="macro.h",text="#define RF_LOW(x) ((x)&255)\n"},predefined=[],
    resolve=fn _=>NONE,width=64,maxDepth=8,maxExpansions=1000})
  val ()=check("function-like macro has its own identity",isSome(ForeignModel.find(ForeignModel.fromCMacros macros,
    {family="c",namespace="macro",name="RF_LOW"})))
  val equivalent= #declarations(CParse.translationUnit{tokens=CLex.scan{file="equivalent.h",
    text="long unsigned int same(short int value); unsigned long same(short value);"},predefinedTypes=[]})
  val ()=check("equivalent C scalar spellings coalesce",isSome(ForeignModel.find(ForeignModel.fromC equivalent,
    {family="c",namespace="function",name="same"})))
  val () = print ("PASS foreign policy: " ^ Int.toString (!checks) ^ " checks\n")
end
