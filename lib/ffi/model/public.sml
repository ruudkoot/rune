(* Implements: FOREIGN_PUBLIC *)
structure ForeignPublic : FOREIGN_PUBLIC =
struct
  type output={signatureText:string,structureText:string}
  exception Error=ForeignModel.Error
  fun q text="\"" ^ String.toString text ^ "\""
  fun join values=String.concatWith ", " values
  fun list values="[" ^ join values ^ "]"
  fun emit {policy:ForeignPolicy.policy,profile:ForeignTarget.profile,declarations} =
    let
      val module= #structureName policy val raw=module ^ "Raw" val signatureName=String.map Char.toUpper module
      val source= #source policy
      fun fail at message=raise Error(at,message)
      val analysis=CAnalysis.create{target= #analysis profile,declarations=declarations}
      val model=ForeignModel.index(ForeignModel.fromC declarations)
      val callWords=["cdecl","__cdecl","stdcall","__stdcall","WINAPI","CALLBACK","__fastcall","fastcall",
        "__vectorcall","vectorcall","__thiscall","thiscall","__regcall","regcall","ms_abi","sysv_abi",
        "regparm","__regparm__","pcs","__pcs__","aarch64_vector_pcs","preserve_most","preserve_all"]
      fun stripCallAttributes(CParse.Attributed(ty,attributes))=
            let fun calling (tokens:CLex.token list)=let val words=List.filter(fn token=> #kind token=CLex.Identifier)tokens
                  in List.exists(fn token=>List.exists(fn word=>word= #text token)callWords)words andalso
                    List.all(fn token=>List.exists(fn word=>word= #text token)(callWords @ ["__attribute__","__attribute","__declspec"]))words end
                val retained=List.filter(fn tokens=>not(calling tokens))attributes
                val base=stripCallAttributes ty
            in if null retained then base else CParse.Attributed(base,retained) end
        | stripCallAttributes ty=ty
      fun callFunction {result,parameters,variadic,prototype}=
        {result=stripCallAttributes result,parameters=List.map(fn CParse.Parameter{name,ctype}=>
          CParse.Parameter{name=name,ctype=stripCallAttributes ctype})parameters,variadic=variadic,prototype=prototype}
      fun resolve ty=CAnalysis.resolve analysis ty
      fun integer ty=CAnalysis.integer analysis ty
      fun native foreign =
        let val selected=case ForeignModel.lookup(model,{family="c",namespace="function",name=foreign}) of
                  SOME declaration=> #source declaration | NONE=>fail source("missing public C function: " ^ foreign)
            fun matches(CParse.Declaration{name,ctype,storage,location,...})=name=SOME foreign andalso location=selected andalso
                  not(List.exists(fn word=>word="typedef")storage) andalso
                  (case resolve ctype of CParse.Function _=>true | _=>false)
              | matches _=false
        in case List.find matches declarations of
          SOME(CParse.Declaration{ctype,...})=>(case resolve ctype of CParse.Function f=>callFunction f | _=>fail source "expected C function")
        | _=>fail source("missing public C function: " ^ foreign) end
      fun scalar ty=case resolve ty of
          CParse.Builtin "void"=>"Void" | CParse.Builtin "_Bool"=>"UInt8"
        | CParse.Builtin "float"=>"Float32" | CParse.Builtin "double"=>"Float64"
        | CParse.Pointer _=>"Pointer" | CParse.Array _=>"Pointer" | CParse.Record _=>"Aggregate"
        | _=>(case integer ty of SOME{width,signed,...}=>(if signed then "SInt" else "UInt") ^ Int.toString width
          | NONE=>fail source "public aggregate value requires a typed adapter")
      fun scalarType scalar=case scalar of "Void"=>ForeignPolicy.Scalar "unit" | "Float32"=>ForeignPolicy.Scalar "real"
        | "Float64"=>ForeignPolicy.Scalar "real" | "Pointer"=>fail source "public pointer requires an explicit projected type"
        | _=>ForeignPolicy.Scalar((if String.isPrefix "SInt" scalar then "int" else "word") ^ String.extract(scalar,4,NONE))
      fun callbackInfo name=
        let val cbPolicy=case List.find(fn p:ForeignPolicy.callbackPolicy=> #foreign p=name)(#callbacks policy) of
                  SOME p=>p | NONE=>fail source("unknown callback policy: " ^ name)
            val original=case CAnalysis.lookup analysis{namespace="typedef",name=name} of SOME ty=>ty
              | NONE=>fail (#source cbPolicy)("missing callback typedef: " ^ name)
            val function=case resolve original of CParse.Pointer{target,...}=>(case resolve target of CParse.Function f=>f
                  | _=>fail (#source cbPolicy) "callback target is not a function")
              | _=>fail (#source cbPolicy) "callback typedef is not a pointer"
            val ()=if scalar(#result function)="Aggregate" orelse
              List.exists(fn CParse.Parameter{ctype,...}=>scalar ctype="Aggregate")(#parameters function) then
              fail (#source cbPolicy) "aggregate callback values require a typed adapter" else ()
            val ()=if scalar(#result function)="Pointer" then
              fail (#source cbPolicy) "callback pointer results require an explicit lifetime adapter" else ()
            fun callbackType c=case resolve c of CParse.Builtin "_Bool"=>ForeignPolicy.Scalar "bool"
              | _=>if scalar c="Pointer" then ForeignPolicy.Resource "native_pointer" else scalarType(scalar c)
            val arguments=List.map(fn CParse.Parameter{ctype,...}=>callbackType ctype)(#parameters function)
            val input=case arguments of []=>ForeignPolicy.Scalar "unit" | [ty]=>ty | tys=>ForeignPolicy.Tuple tys
            fun attrs(CParse.Attributed(ty,attributes))=String.concat(List.map CLex.spelling attributes) ^ attrs ty
              | attrs(CParse.Pointer{target,...})=attrs target | attrs _=""
            val attributes=attrs original
            val ()=if List.exists(fn name=>String.isSubstring name attributes)
              ["fastcall","vectorcall","thiscall","regcall","ms_abi","sysv_abi","regparm","aarch64_vector_pcs","preserve_most","preserve_all"]
              then fail (#source cbPolicy) "callback calling convention requires a typed adapter" else ()
        in {policy=cbPolicy,function=function,input=input,output=callbackType(#result function),
          abi=if #abi profile="win32" andalso String.isSubstring "stdcall" attributes then 1 else 0,
          name="callback_" ^ ForeignPolicy.rawName name} end
      fun annotation (p:ForeignPolicy.functionPolicy) name=List.find(fn a:ForeignPolicy.valuePolicy=> #name a=SOME name)(#parameters p)
      fun pointee ty=case resolve ty of CParse.Pointer{target,...}=>target | CParse.Array{element,...}=>element
        | _=>fail source "output projection requires a native pointer"
      fun objectType ty=case resolve ty of
          CParse.Record {kind,tag=SOME tag,fields=NONE,...}=>
            (case CAnalysis.lookup analysis{namespace=case kind of CParse.Struct=>"struct" | CParse.Union=>"union",name=tag} of
              SOME ty=>objectType ty | NONE=>fail source "incomplete public aggregate")
        | ty=>ty
      fun defaultObject ty=case objectType ty of
          CParse.Record {kind=CParse.Struct,fields=SOME fields,...}=>ForeignPolicy.Record(List.map(fn CParse.Field{name,ctype,...}=>
            (case name of SOME name=>(name,defaultObject ctype) | NONE=>fail source "anonymous aggregate projection requires an adapter"))fields)
        | CParse.Record _=>fail source "public union projection requires an explicit active-member adapter"
        | CParse.Array{element,...}=>ForeignPolicy.Vector(defaultObject element)
        | CParse.Builtin "_Bool"=>ForeignPolicy.Scalar "bool"
        | ty=>scalarType(scalar ty)
      fun defaultType ty=case resolve ty of CParse.Record _=>defaultObject ty
        | CParse.Builtin "_Bool"=>ForeignPolicy.Scalar "bool" | _=>scalarType(scalar ty)
      fun baseType ty annotation=case annotation of SOME(a:ForeignPolicy.valuePolicy)=>
            (case #projection a of SOME t=>t | NONE=>(case #callback a of SOME name=>
                let val base=ForeignPolicy.Resource(#name(callbackInfo name))
                in if #nullable a=SOME true then ForeignPolicy.Option base else base end
              | NONE=>defaultType(if #direction a=SOME ForeignPolicy.Out orelse #direction a=SOME ForeignPolicy.InOut then pointee ty else ty)))
        | NONE=>defaultType ty
      fun render ty=case ty of ForeignPolicy.Array(ForeignPolicy.Scalar "word8")=>"Word8Array.array"
        | ForeignPolicy.Vector(ForeignPolicy.Scalar "word8")=>"Word8Vector.vector"
        | ForeignPolicy.Option t=>"(" ^ render t ^ ") option"
        | ForeignPolicy.Tuple []=>"unit" | ForeignPolicy.Tuple[t]=>render t
        | ForeignPolicy.Tuple ts=>"(" ^ String.concatWith " * " (List.map render ts) ^ ")"
        | ForeignPolicy.Record fs=>"{" ^ join(List.map(fn(n,t)=>n ^ " : " ^ render t)fs) ^ "}"
        | _=>ForeignProjection.renderType ty
      fun names parameters=ListPair.map(fn(i,CParse.Parameter{name,...})=>getOpt(name,"arg" ^ Int.toString i))
        (List.tabulate(length parameters,fn i=>i),parameters)
      fun variable name="value_" ^ ForeignPolicy.rawName name
      fun tree f ForeignPolicy.Unit="()" | tree f (ForeignPolicy.Value name)=f name
        | tree f (ForeignPolicy.Product values)="(" ^ join(List.map(tree f)values) ^ ")"
        | tree f (ForeignPolicy.Fields fields)="{" ^ join(List.map(fn(n,v)=>n ^ "=" ^ tree f v)fields) ^ "}"
      fun inputTree (p:ForeignPolicy.functionPolicy) values=getOpt(#input p,case values of []=>ForeignPolicy.Unit
        | [value]=>ForeignPolicy.Value value | values=>ForeignPolicy.Product(List.map ForeignPolicy.Value values))
      val functions=List.filter(fn p:ForeignPolicy.functionPolicy=>not(isSome(#adapter p)))(#functions policy)
      fun number ty expression=case ty of
          ForeignPolicy.Scalar "bool"=>"(if " ^ expression ^ " then 1 else 0)"
        | ForeignPolicy.Scalar "int"=>"IntInf.fromInt (" ^ expression ^ ")"
        | ForeignPolicy.Scalar n=>if String.isPrefix "int" n then "Int" ^ String.extract(n,3,NONE) ^ ".toLarge (" ^ expression ^ ")"
            else if String.isPrefix "word" n then "Word" ^ String.extract(n,4,NONE) ^ ".toLargeInt (" ^ expression ^ ")"
            else fail source "expected scalar integer projection"
        | _=>fail source "expected scalar integer projection"
      fun argument native ty expression=case native of "Float32"=>
            if ty=ForeignPolicy.Scalar "real" then "RuneForeign.Real (" ^ expression ^ ")" else fail source "floating argument requires a real projection"
        | "Float64"=>if ty=ForeignPolicy.Scalar "real" then "RuneForeign.Real (" ^ expression ^ ")" else fail source "floating argument requires a real projection"
        | _=>
            let val signed=String.isPrefix "SInt" native
                val width=case Int.fromString(String.extract(native,4,NONE)) of SOME n=>n div 8 | NONE=>fail source "invalid scalar argument"
            in "(let val integer=" ^ number ty expression ^ " val _=ForeignBytes.integer{width=" ^ Int.toString width ^
              ",signed=" ^ Bool.toString signed ^ ",littleEndian=true,value=integer} in " ^
              (if signed then "RuneForeign.Signed(Int64.fromLarge integer)" else "RuneForeign.Unsigned(Word64.fromLargeInt integer)") ^ " end)" end
      fun convert ty value=case ty of
          ForeignPolicy.Scalar "unit"=>"()" | ForeignPolicy.Scalar "bool"=>"(" ^ value ^ " <> 0)"
        | ForeignPolicy.Scalar "int"=>"IntInf.toInt (" ^ value ^ ")"
        | ForeignPolicy.Scalar n=>if String.isPrefix "int" n then "Int" ^ String.extract(n,3,NONE) ^ ".fromLarge (" ^ value ^ ")"
            else if String.isPrefix "word" n then
              let val width=valOf(Int.fromString(String.extract(n,4,NONE))) div 8
              in "(let val integer=" ^ value ^ " val _=ForeignBytes.integer{width=" ^ Int.toString width ^
                ",signed=false,littleEndian=true,value=integer} in Word" ^ String.extract(n,4,NONE) ^ ".fromLargeInt integer end)" end
            else fail source "expected scalar integer projection"
        | _=>fail source "expected scalar integer projection"
      fun resultValue native ty bytes little wire=case ty of ForeignPolicy.Scalar "unit"=>"()"
        | ForeignPolicy.Scalar "real"=>if native="Float32" orelse native="Float64" then
            "ForeignBytes.real" ^ (if native="Float32" andalso not wire then "32" else "64") ^
            "Value {littleEndian=" ^ little ^ ", bytes=" ^ bytes ^ "}"
          else fail source "real result projection requires a native floating result"
        | _=>convert ty ("ForeignBytes.value {signed=" ^ Bool.toString(String.isPrefix "SInt" native) ^ ", littleEndian=" ^ little ^ ", bytes=" ^ bytes ^ "}")
      val little=Bool.toString(#byteOrder profile=ForeignModel.Little)
      fun encoding NONE="ForeignText.Bytes" | encoding(SOME ForeignPolicy.Bytes)="ForeignText.Bytes"
        | encoding(SOME ForeignPolicy.Utf8)="ForeignText.Utf8" | encoding(SOME ForeignPolicy.Wtf8)="ForeignText.Wtf8"
        | encoding(SOME ForeignPolicy.Utf16)="ForeignText.Utf16"
      fun countExpr values (SOME(ForeignPolicy.FixedLength n))="IntInf.toInt(" ^ IntInf.toString n ^ ")"
        | countExpr values (SOME(ForeignPolicy.ParameterLength name))=
            (case List.find(fn(n,_)=>n=name)values of SOME(_,ty)=>"IntInf.toInt (" ^ number ty (variable name) ^ ")"
              | NONE=>fail source "unknown projected buffer extent")
        | countExpr _ NONE=fail source "buffer requires a checked explicit extent"
      fun resourceType (ForeignPolicy.Resource name)=SOME(name,false)
        | resourceType(ForeignPolicy.Option(ForeignPolicy.Resource name))=SOME(name,true) | resourceType _=NONE
      fun stringType(ForeignPolicy.Scalar "string")=SOME false
        | stringType(ForeignPolicy.Option(ForeignPolicy.Scalar "string"))=SOME true | stringType _=NONE
      fun destructor release=
        let val f=native release
            val ()=if length(#parameters f)=1 andalso scalar(#result f)="Void" andalso
              (case hd(#parameters f) of CParse.Parameter{ctype,...}=>scalar ctype="Pointer") then ()
              else fail source "automatic owned-pointer destructor requires one pointer argument and void result"
        in "{call=" ^ raw ^ ".prepare native " ^ q release ^ ", arguments=fn pointer=>[RuneForeign.Address(SOME pointer)], failure=RuneForeign.NoFailure}" end
      fun objectLayout ty=CAnalysis.layout analysis{ty=ty,source=source}
      fun objectSize ty=IntInf.toString(CLayout.size(objectLayout ty))
      fun recordMembers ty projected=
        let val fields=case objectType ty of CParse.Record{kind=CParse.Struct,fields=SOME fields,...}=>fields
              | _=>fail source "public union or incomplete aggregate requires an adapter"
            val layout=objectLayout ty
            val selected=case projected of ForeignPolicy.Record fields=>fields
              | _=>fail source "native struct requires a record projection"
            fun member(label,projection)=case List.find(fn CParse.Field{name,...}=>name=SOME label)fields of
                SOME(CParse.Field{ctype,...})=>(label,ctype,projection,IntInf.toString(#offset(CLayout.member(layout,[label]))))
              | NONE=>fail source("record projection names no native member: " ^ label)
            val names=List.map(fn CParse.Field{name,...}=>case name of SOME name=>name
              | NONE=>fail source "anonymous aggregate projection requires an adapter")fields
            val ()=if length names=length selected andalso List.all(fn name=>List.exists(fn(label,_)=>label=name)selected)names
              then () else fail source "record projection must cover every named native field"
        in List.map member selected end
      fun arrayParts ty projected=case (objectType ty,projected,objectLayout ty) of
          (CParse.Array{element,...},ForeignPolicy.Vector item,CLayout.Sequence{count,...})=>(element,item,IntInf.toString count)
        | _=>fail source "native array member requires a fixed-length vector projection"
      fun objectWrite ty projected buffer offset value depth=
        case objectType ty of CParse.Record _=>
          let val members=recordMembers ty projected
              val writes=List.map(fn(label,ctype,projection,fieldOffset)=>objectWrite ctype projection buffer
                ("(" ^ offset ^ "+" ^ fieldOffset ^ ")")("(#" ^ label ^ " (" ^ value ^ " : " ^ render projected ^ "))")(depth+1))members
          in "(" ^ String.concatWith ";" (writes @ ["()"]) ^ ")" end
        | CParse.Array _=>
          let val(element,item,count)=arrayParts ty projected
              val suffix=Int.toString depth val index="aggregateIndex" ^ suffix val entry="aggregateItem" ^ suffix
              val offset="(" ^ offset ^ "+" ^ index ^ "*" ^ objectSize element ^ ")"
          in "(if Vector.length(" ^ value ^ ")<>" ^ count ^ " then raise ForeignMemory.Bounds else " ^
            "Vector.appi(fn(" ^ index ^ "," ^ entry ^ ")=>" ^ objectWrite element item buffer offset entry(depth+1) ^ ") (" ^ value ^ "))" end
        | _=>let val c=scalar ty val ()=if c="Pointer" then fail source "aggregate pointer fields require a typed lifetime adapter" else ()
                 val bytes=if c="Float32" orelse c="Float64" then
                    if projected=ForeignPolicy.Scalar "real" then "ForeignBytes.real" ^ (if c="Float32" then "32" else "64") ^
                      "{littleEndian=" ^ little ^ ",value=" ^ value ^ "}" else fail source "floating field requires real projection"
                   else "ForeignBytes.integer{width=" ^ objectSize ty ^ ",signed=" ^ Bool.toString(String.isPrefix "SInt" c) ^
                     ",littleEndian=" ^ little ^ ",value=" ^ number projected value ^ "}"
             in "ForeignMemory.write(" ^ buffer ^ "," ^ offset ^ "," ^ bytes ^ ")" end
      fun objectRead ty projected buffer offset depth=if projected=ForeignPolicy.Scalar "unit" then "()" else
        case objectType ty of CParse.Record _=>
          "{" ^ join(List.map(fn(label,ctype,projection,fieldOffset)=>label ^ "=" ^ objectRead ctype projection buffer
            ("(" ^ offset ^ "+" ^ fieldOffset ^ ")")(depth+1))(recordMembers ty projected)) ^ "}"
        | CParse.Array _=>
          let val(element,item,count)=arrayParts ty projected val index="aggregateIndex" ^ Int.toString depth
          in "Vector.tabulate(" ^ count ^ ",fn " ^ index ^ "=>" ^ objectRead element item buffer
            ("(" ^ offset ^ "+" ^ index ^ "*" ^ objectSize element ^ ")")(depth+1) ^ ")" end
        | _=>let val c=scalar ty val ()=if c="Pointer" then fail source "aggregate pointer fields require a typed lifetime adapter" else ()
             in resultValue c projected ("ForeignMemory.read(" ^ buffer ^ "," ^ offset ^ "," ^ objectSize ty ^ ")")little false end
      fun one (p:ForeignPolicy.functionPolicy)=
        let val f=native(#foreign p) val ns=names(#parameters f)
            val ()=if String.isSubstring "."(#name p) then fail (#source p) "nested public SML members require an explicit adapter" else ()
            val ()=List.app(fn n=>if length(List.filter(fn other=>ForeignPolicy.rawName n=ForeignPolicy.rawName other)ns)>1
              then fail (#source p)("colliding generated parameter name: " ^ n) else ())ns
            val nativeTypes=List.map(fn CParse.Parameter{ctype,...}=>ctype)(#parameters f)
            val values=ListPair.map(fn(n,t)=>(n,baseType t (annotation p n)))(ns,nativeTypes)
            val resultType=baseType (#result f) (SOME(#result p))
            val ()=if scalar(#result f)="Void" andalso resultType<>ForeignPolicy.Scalar "unit" then
              fail (#source p) "void result projects only to unit" else ()
            val ()=ListPair.app(fn(n,ctype)=>case resolve ctype of CParse.Builtin "_Bool"=>
                if baseType ctype(annotation p n)=ForeignPolicy.Scalar "bool" then () else
                  fail (#source p) "native bool arguments require bool projections" | _=>())(ns,nativeTypes)
            val types=ForeignProjection.callType{policy=p,inputs=values,result=resultType}
            val inputNames=List.filter(fn n=>case annotation p n of SOME a=> #direction a<>SOME ForeignPolicy.Out | NONE=>true)ns
            val outputs=List.filter(fn n=>case annotation p n of SOME a=> #direction a=SOME ForeignPolicy.Out orelse #direction a=SOME ForeignPolicy.InOut | NONE=>false)ns
            fun valueType n= #2(valOf(List.find(fn(other,_)=>other=n)values))
            fun nativeType n= #2(valOf(List.find(fn(other,_)=>other=n)(ListPair.zip(ns,nativeTypes))))
            fun policyFor n=case annotation p n of SOME a=>a | NONE=>fail (#source p)("missing pointer policy: " ^ n)
            fun elementBytes n=case resolve(pointee(nativeType n)) of CParse.Builtin "void"=>IntInf.fromInt 1
              | ty=>CLayout.size(CAnalysis.layout analysis{ty=ty,source= #source(policyFor n)})
            fun byteCount n=let val count=countExpr values (#extent(policyFor n)) val factor=elementBytes n
              in if factor=1 then count else "IntInf.toInt(IntInf.*(IntInf.fromInt(" ^ count ^ ")," ^ IntInf.toString factor ^ "))" end
            val projectedInput=inputTree p inputNames
            fun leaves ForeignPolicy.Unit=[] | leaves(ForeignPolicy.Value n)=[n]
              | leaves(ForeignPolicy.Product values)=List.concat(List.map leaves values)
              | leaves(ForeignPolicy.Fields fields)=List.concat(List.map(leaves o #2)fields)
            val supplied=leaves projectedInput
            fun derived n=if List.exists(fn other=>other=n)supplied then "" else
              let val candidates=List.filter(fn a:ForeignPolicy.valuePolicy=> #extent a=SOME(ForeignPolicy.ParameterLength n) andalso #direction a<>SOME ForeignPolicy.Out)(#parameters p)
                  fun count (a:ForeignPolicy.valuePolicy)=
                    let val buffer=case #name a of SOME name=>name | NONE=>fail (#source a) "extent source has no name"
                        val bytes=case valueType buffer of ForeignPolicy.Array(ForeignPolicy.Scalar "word8")=>"Word8Array.length " ^ variable buffer
                      | ForeignPolicy.Vector(ForeignPolicy.Scalar "word8")=>"Word8Vector.length " ^ variable buffer
                      | _=>fail (#source a) "omitted length requires an input byte buffer"
                    in "IntInf.div(IntInf.fromInt(" ^ bytes ^ ")," ^ IntInf.toString(elementBytes buffer) ^ ")" end
                  fun complete (a:ForeignPolicy.valuePolicy)=
                    let val buffer=valOf(#name a) val factor=elementBytes buffer
                        val bytes=case valueType buffer of ForeignPolicy.Array _=>"Word8Array.length " ^ variable buffer
                          | _=>"Word8Vector.length " ^ variable buffer
                    in if factor=1 then "" else "        val ()=if IntInf.mod(IntInf.fromInt(" ^ bytes ^ ")," ^
                      IntInf.toString factor ^ ")=0 then () else raise ForeignMemory.Bounds\n" end
              in case candidates of []=>fail (#source p)("omitted native argument has no derivable extent: " ^ n)
                | first::rest=>String.concat(List.map complete candidates) ^ "        val " ^ variable n ^ " = " ^ convert(valueType n)(count first) ^ "\n" ^
                    String.concat(List.map(fn a=>"        val ()=if " ^ count a ^ " = " ^ count first ^ " then () else raise ForeignMemory.Bounds\n")rest) end
            val derivedInputs=String.concat(List.map derived inputNames)
            val dependencies=(case #ownership(#result p) of SOME(ForeignPolicy.Owned release)=>[release] | _=>[]) @
              (case #getter(#errors p) of SOME getter=>[getter] | NONE=>[])
            val dependencyChecks=String.concat(List.map(fn helper=>"        val _=" ^ raw ^ ".prepare native " ^ q helper ^ "\n")dependencies)
            val prefix="  fun " ^ #name p ^ " session " ^ tree variable(inputTree p inputNames) ^ " =\n    let val native = nativeSession session\n" ^
              "    in ForeignScope.withScope (fn scope =>\n      let val _=enterCall session scope\n" ^ derivedInputs ^ dependencyChecks
            val arrayNames=List.filter(fn n=>valueType n=ForeignPolicy.Array(ForeignPolicy.Scalar "word8"))ns
            val arrays=List.map(fn n=>
              let val a=policyFor n val direction=case #direction a of SOME ForeignPolicy.Out=>"Output" | SOME ForeignPolicy.InOut=>"InputOutput" | _=>"Input"
              in "{array=" ^ variable n ^ ", offset=0, length=" ^ byteCount n ^ ", direction=ForeignMemory." ^ direction ^ "}" end)arrayNames
            fun outArray n=case #direction(policyFor n) of SOME ForeignPolicy.Out=>
                  "        val " ^ variable n ^ " = Word8Array.array(" ^ byteCount n ^ ", 0w0)\n" | _=>""
            val outArrays=String.concat(List.map outArray arrayNames)
            fun arrayIndex n=
              let fun find(i,[])=fail source "missing array argument" | find(i,x::xs)=if x=n then i else find(i+1,xs)
              in find(0,arrayNames) end
            fun callback (a:ForeignPolicy.valuePolicy) id=
              let val info=callbackInfo(valOf(#callback a)) val cb= #policy info val function= #function info
                  val ()=if #lifetime cb="call" then () else fail (#source cb) "registered callback projection requires an explicit unregistering adapter"
                  val cs=List.map(fn CParse.Parameter{ctype,...}=>scalar ctype)(#parameters function)
                  val callbackTypes=List.map(fn CParse.Parameter{ctype,...}=>ctype)(#parameters function)
                  val cn=names(#parameters function)
                  val variables=List.tabulate(length cs,fn i=>"callbackValue" ^ Int.toString i)
                  fun decode(ctype,v)=let val c=scalar ctype val projected=case resolve ctype of
                        CParse.Builtin "_Bool"=>ForeignPolicy.Scalar "bool" | _=>if c="Pointer" then ForeignPolicy.Resource "native_pointer" else scalarType c
                    in case c of "Pointer"=>"(case " ^ v ^ " of RuneForeign.Address pointer=>pointer | _=>raise Fail \"callback pointer argument\")"
                    | "Float32"=>"(case " ^ v ^ " of RuneForeign.Real value=>value | _=>raise Fail \"callback real argument\")"
                    | "Float64"=>"(case " ^ v ^ " of RuneForeign.Real value=>value | _=>raise Fail \"callback real argument\")"
                    | _=>if String.isPrefix "SInt" c then "(case " ^ v ^ " of RuneForeign.Signed value=>" ^ convert projected "Int64.toLarge value" ^ " | _=>raise Fail \"callback signed argument\")"
                      else "(case " ^ v ^ " of RuneForeign.Unsigned value=>" ^ convert projected "Word64.toLargeInt value" ^ " | _=>raise Fail \"callback unsigned argument\")" end
                  val decoded=ListPair.map decode(callbackTypes,variables)
                  val input=case decoded of []=>"()" | [v]=>v | vs=>"(" ^ join vs ^ ")"
                  val result=scalar(#result function)
                  val answer=if result="Void" then "(function " ^ input ^ "; RuneForeign.Signed 0)"
                    else if result="Pointer" then "RuneForeign.Address(function " ^ input ^ ")"
                    else argument result (#output info)("function " ^ input)
                  fun failure value=if result="Void" then "RuneForeign.Signed 0" else if result="Pointer" then
                      if value=0 then "RuneForeign.Address NONE" else fail (#source cb) "non-null callback failure pointer is unsupported"
                    else case integer(#result function) of NONE=>fail (#source cb) "floating callback failure policy is unsupported"
                      | SOME ty=>let val(minimum,maximum)=CInteger.limits ty
                        in if value<minimum orelse value>maximum then fail (#source cb) "callback failure value exceeds its native result range"
                           else if #signed ty then "RuneForeign.Signed(Int64.fromLarge " ^ IntInf.toString value ^ ")"
                           else "RuneForeign.Unsigned(Word64.fromLargeInt " ^ IntInf.toString value ^ ")" end
                  val fallback=case #failure cb of ForeignPolicy.ConstantFailure value=>"RuneForeign.Default(" ^ failure value ^ ")"
                    | ForeignPolicy.ArgumentFailure{parameter,cases,otherwise}=>
                        let fun index(i,[])=fail (#source cb) "callback failure selector is not an argument"
                              | index(i,n::ns)=if n=parameter then i else index(i+1,ns)
                            fun value expression= #integer(CAnalysis.expression analysis(CLex.scan{file= #file(#source cb),text=expression}))
                        in "RuneForeign.ByArgument{index=" ^ Int.toString(index(0,cn)) ^ ",cases=" ^
                          list(List.map(fn(expression,v)=>"(Word64.fromLargeInt " ^ IntInf.toString(value expression) ^ "," ^ failure v ^ ")")cases) ^
                          ",default=" ^ failure otherwise ^ "}" end
                  val build="(fn function=>let val callback=RuneForeign.callback{abi=" ^ Int.toString(#abi info) ^ ",result=RuneForeign." ^ result ^
                    ",arguments=" ^ list(List.map(fn c=>"RuneForeign." ^ c)cs) ^ ",function=fn arguments=>case arguments of " ^
                    list variables ^ "=>" ^ answer ^ " | _=>raise Fail \"callback argument count\",failure=" ^ fallback ^ "} " ^
                    "val _=ForeignScope.defer(scope,fn()=>RuneForeign.release callback) in callback end)"
              in if #nullable a=SOME true then "Option.map " ^ build ^ " " ^ id else "SOME(" ^ build ^ " " ^ id ^ ")" end
            fun prepare n=
              let val a=annotation p n val ty=valueType n val ctype=nativeType n
                  val id=variable n val key=ForeignPolicy.rawName n
                  val ()=if scalar ctype="Pointer" then case a of SOME a=>if isSome(#callback a) then () else
                        (case #ownership a of SOME(ForeignPolicy.Borrowed "call")=>()
                         | _=>fail (#source a) "retained input pointers require an explicit lifetime adapter")
                    | NONE=>() else ()
              in if scalar ctype="Aggregate" then
                  "        val aggregate_" ^ key ^ " = scopedBuffer scope " ^ objectSize ctype ^ "\n" ^
                  "        val ()=" ^ objectWrite ctype ty ("aggregate_" ^ key) "0" id 0 ^ "\n"
                else if scalar ctype<>"Pointer" then "" else
                if List.exists(fn other=>other=n)arrayNames then "        val pointer_" ^ key ^ " = SOME(ForeignMemory.raw(List.nth(arrayBuffers," ^ Int.toString(arrayIndex n) ^ ")))\n"
                else case a of NONE=>fail (#source p)("pointer policy missing: " ^ n) | SOME a=>
                  if isSome(#callback a) then "        val pointer_" ^ key ^ " = " ^ callback a id ^ "\n" else
                  let val ()=case #ownership a of SOME(ForeignPolicy.Borrowed "call")=>()
                        | _=>fail (#source a) "retained input pointers require an explicit lifetime adapter"
                  in case resourceType ty of SOME(resource,optional)=>
                    "        val pointer_" ^ key ^ " = " ^ (if optional then "Option.map (fn value=>borrowHandle scope (unpack_" ^ resource ^ " value)) " ^ id
                      else "SOME(borrowHandle scope (unpack_" ^ resource ^ " " ^ id ^ "))") ^ "\n"
                  | NONE=>(case stringType ty of SOME optional=>
                      let val unitBytes=case #encoding a of SOME ForeignPolicy.Utf16=>2 | _=>1
                          val ()=if elementBytes n=IntInf.fromInt unitBytes then () else
                            fail (#source a) "string encoding disagrees with native element width"
                          val extent=case #extent a of NONE=>"NONE" | value=>"SOME(" ^ countExpr values value ^ ")"
                      in "        val pointer_" ^ key ^ " = inputText scope " ^ encoding(#encoding a) ^ " " ^ Bool.toString(getOpt(#terminator a,false)) ^ " (" ^ extent ^ ") " ^
                        (if optional then id else "(SOME " ^ id ^ ")") ^ "\n" end
                    | NONE=>if #direction a=SOME ForeignPolicy.Out orelse #direction a=SOME ForeignPolicy.InOut then
                        let val ()=case #extent a of NONE=>() | SOME(ForeignPolicy.FixedLength 1)=>()
                              | _=>fail (#source a) "single output value requires a one-element extent"
                            val c=pointee ctype val size=IntInf.toString(CLayout.size(CAnalysis.layout analysis {ty=c,source= #source a}))
                            val init=if #direction a=SOME ForeignPolicy.InOut then
                              "        val ()=" ^ objectWrite c ty ("buffer_" ^ key) "0" id 0 ^ "\n" else ""
                        in "        val buffer_" ^ key ^ " = scopedBuffer scope " ^ size ^ "\n" ^ init ^
                          "        val pointer_" ^ key ^ " = SOME(ForeignMemory.raw buffer_" ^ key ^ ")\n" end
                      else fail (#source a) "unsupported automatic pointer input projection") end
              end
            val preparations=String.concat(List.map prepare ns)
            fun nativeArgument n=let val c=nativeType n in if scalar c="Pointer" then "RuneForeign.Address pointer_" ^ ForeignPolicy.rawName n
              else if scalar c="Aggregate" then "RuneForeign.Address(SOME(ForeignMemory.raw aggregate_" ^ ForeignPolicy.rawName n ^ "))"
              else argument(scalar c)(valueType n)(variable n) end
            val resultScalar=scalar(#result f)
            val resultBuffer=if resultScalar="Aggregate" then "        val aggregateResult = scopedBuffer scope " ^ objectSize(#result f) ^ "\n" else ""
            val args=list((if resultScalar="Aggregate" then ["RuneForeign.Address(SOME(ForeignMemory.raw aggregateResult))"] else []) @ List.map nativeArgument ns)
            val consumed=List.filter(fn n=>case annotation p n of SOME a=> #consumes a | NONE=>false)ns
            val consumedBody=case consumed of []=>NONE | [n]=>
                  if resultType=ForeignPolicy.Scalar "unit" andalso length ns=1 then SOME
                    ("        val ()=" ^ (case resourceType(valueType n) of SOME(resource,true)=>"Option.app (closeHandle o unpack_" ^ resource ^ ") " ^ variable n
                      | SOME(resource,false)=>"closeHandle(unpack_" ^ resource ^ " " ^ variable n ^ ")"
                      | NONE=>fail (#source p) "consumed parameter requires a typed resource") ^ "\n")
                  else fail (#source p) "consumed resource projection requires a one-argument void destructor"
              | _=>fail (#source p) "multiple consumed resources require an explicit adapter"
            val ()=if resultScalar="Aggregate" andalso #predicate(#errors p)<>"none" then
              fail (#source p) "aggregate results require an explicit failure-status adapter" else ()
            val ()=if resultScalar="Pointer" andalso not(List.exists(fn predicate=>predicate= #predicate(#errors p))["none","null"])
              then fail (#source p) "pointer results require null or no failure predicate" else ()
            val ()=if (resultScalar="Float32" orelse resultScalar="Float64") andalso
                resultType<>ForeignPolicy.Scalar "unit" andalso resultType<>ForeignPolicy.Scalar "real"
              then fail (#source p) "floating result requires a real or unit projection" else ()
            val invocation="        val deferred = RuneForeign.invokeDeferred (" ^ raw ^ ".prepare native " ^ q(#foreign p) ^ ", " ^ args ^ ")\n" ^
              "        val result = #result deferred\n"
            val owner=case #ownership(#result p) of SOME(ForeignPolicy.Owned release)=>
                  "        val owner = Option.map (fn pointer=>ForeignOwner.adopt{pointer=pointer, destructor=" ^ destructor release ^ "})(#pointer result)\n" ^
                  "        val ownerTicket = Option.map (fn value=>ForeignOwner.inScope(scope,value)) owner\n"
              | _=>"        val owner : ForeignOwner.owner option = NONE\n        val ownerTicket : ForeignScope.ticket option = NONE\n"
            val pointerCleanup="        val pointerTicket = Option.map (fn pointer=>ForeignScope.defer(scope,fn()=>if RuneForeign.isLive pointer then RuneForeign.release pointer else ())) (#pointer result)\n"
            val integerResult="ForeignBytes.value {signed=" ^ Bool.toString(String.isPrefix "SInt" resultScalar) ^ ",littleEndian=true,bytes= #bytes result}"
            val realResult="ForeignBytes.real64Value{littleEndian=true,bytes= #bytes result}"
            val failed=if resultScalar="Float32" orelse resultScalar="Float64" then
                (case #predicate(#errors p) of "none"=>"false" | "false"=>"Real.==(" ^ realResult ^ ",0.0)"
                  | "zero"=>"Real.==(" ^ realResult ^ ",0.0)" | "nonzero"=>"Real.!=(" ^ realResult ^ ",0.0)"
                  | "minus-one"=>"Real.==(" ^ realResult ^ ",~1.0)" | "negative"=>realResult ^ "<0.0"
                  | _=>fail (#source p) "invalid floating failure predicate")
              else case #predicate(#errors p) of "none"=>"false" | "null"=>"not(isSome(#pointer result))"
              | "false"=>integerResult ^ "=0" | "zero"=>integerResult ^ "=0" | "nonzero"=>integerResult ^ "<>0"
              | "minus-one"=>integerResult ^ "= ~1" | "negative"=>integerResult ^ "<0"
              | _=>fail (#source p) "unknown automatic native failure predicate"
            val errorText=case #getter(#errors p) of NONE=>"NONE" | SOME getter=>
              "ForeignScope.withScope(fn cleanup=>let val captured=" ^ raw ^ ".call native " ^ q getter ^ " [] " ^
                "val _=Option.map(fn pointer=>ForeignScope.defer(cleanup,fn()=>RuneForeign.release pointer))(#pointer captured) " ^
                "in Option.map (fn pointer=>readText ForeignText.Utf8 true pointer NONE) (#pointer captured) end)"
            val errorCheck="        val failed = " ^ failed ^ "\n" ^
              "        val ()=case #callbackException deferred of SOME error=>raise error | NONE=>()\n" ^
              "        val nativeText = if failed then " ^ errorText ^ " else NONE\n" ^
              "        val ()=if failed then raise ForeignFailure {foreign=" ^ q(#foreign p) ^ ",result=result,text=nativeText} else ()\n"
            fun output n=if List.exists(fn other=>other=n)arrayNames then variable n else
              let val a=policyFor n val c=pointee(nativeType n) val size=IntInf.toString(CLayout.size(CAnalysis.layout analysis{ty=c,source= #source a}))
              in objectRead c (valueType n)("buffer_" ^ ForeignPolicy.rawName n) "0" 0 end
            val outputBindings=String.concat(List.map(fn n=>"        val output_" ^ ForeignPolicy.rawName n ^ " = " ^ output n ^ "\n")outputs)
            val projectedResult=if resultScalar="Aggregate" then objectRead (#result f) resultType "aggregateResult" "0" 0
              else if resultScalar<>"Pointer" then resultValue resultScalar resultType "(#bytes result)" "true" true else
              case resourceType resultType of SOME(resource,optional)=>
                let val parent=case #ownership(#result p) of SOME(ForeignPolicy.Borrowed lifetime)=>
                          if String.isPrefix "parameter:" lifetime then
                            let val n=String.extract(lifetime,10,NONE)
                            in case resourceType(valueType n) of SOME(parent,false)=>"SOME(retainHandle(unpack_" ^ parent ^ " " ^ variable n ^ "))"
                              | _=>fail (#source p) "borrowed result parent requires a non-null typed resource" end
                          else "NONE"
                        | _=>"NONE"
                    val build="(fn pointer=>Handle_" ^ resource ^ " (makeHandle session pointer owner (" ^ parent ^ ")))"
                in if optional then "Option.map " ^ build ^ " (#pointer result)" else
                  build ^ " (case #pointer result of SOME pointer=>pointer | NONE=>raise Fail \"unexpected native null\")" end
              | NONE=>(case stringType resultType of SOME optional=>
                  let val a= #result p
                      val unitBytes=case #encoding a of SOME ForeignPolicy.Utf16=>2 | _=>1
                      val element=CLayout.size(CAnalysis.layout analysis{ty=pointee(#result f),source= #source a})
                      val ()=if element=IntInf.fromInt unitBytes then () else fail (#source a) "string encoding disagrees with native element width"
                      val limit=case #extent a of NONE=>"NONE" | extent=>"SOME(" ^ countExpr values extent ^ ")"
                      val build="(fn pointer=>readText " ^ encoding(#encoding a) ^ " " ^ Bool.toString(getOpt(#terminator a,false)) ^ " pointer (" ^ limit ^ "))"
                  in if optional then "Option.map " ^ build ^ " (#pointer result)" else
                    build ^ " (case #pointer result of SOME pointer=>pointer | NONE=>raise Fail \"unexpected native null\")" end
                | NONE=>fail (#source p) "unsupported automatic pointer result projection")
            val resultBinding="        val projectedResult = " ^ projectedResult ^ "\n"
            val transfer=if isSome(resourceType resultType) then "        val ()=Option.app ForeignScope.cancel ownerTicket\n        val ()=Option.app ForeignScope.cancel pointerTicket\n" else ""
            fun outputValue "$result"="projectedResult" | outputValue n="output_" ^ ForeignPolicy.rawName n
            val returned=case #returns p of SOME projection=>tree outputValue projection
              | NONE=>if null outputs then "projectedResult" else
                  "{" ^ join((if resultType=ForeignPolicy.Scalar "unit" then [] else ["result=projectedResult"]) @
                    List.map(fn n=>getOpt(#output(policyFor n),ForeignPolicy.rawName n) ^ "=" ^ outputValue n)outputs) ^ "}"
            val arraysOpen="      in ForeignMemory.withArrays " ^ list arrays ^ " (fn arrayBuffers =>\n        let\n"
            val ordinary=prefix ^ outArrays ^ arraysOpen ^ preparations ^ resultBuffer ^ invocation ^ pointerCleanup ^ owner ^ errorCheck ^ outputBindings ^ resultBinding ^ transfer ^
              "        in " ^ returned ^ " end)\n      end)\n    end\n"
            val body=case consumedBody of NONE=>ordinary | SOME destroy=>
              "  fun " ^ #name p ^ " session " ^ tree variable(inputTree p inputNames) ^ " =\n    ForeignScope.withScope(fn scope=>let val _=enterCall session scope\n" ^ destroy ^ "    in () end)\n"
            val specification="  (* `" ^ #name p ^ " session input` calls " ^ #foreign p ^ " with checked projection and deterministic cleanup. *)\n" ^
              "  val " ^ #name p ^ " : session -> " ^ render(#input types) ^ " -> " ^ render(#output types) ^ "\n"
        in {body=body,specification=specification} end
      val emitted=List.map one functions
      val callbackNames=List.mapPartial(fn a:ForeignPolicy.valuePolicy=> #callback a)(List.concat(List.map #parameters functions))
      val selectedCallbacks=List.filter(fn cb:ForeignPolicy.callbackPolicy=>List.exists(fn name=>name= #foreign cb)callbackNames)(#callbacks policy)
      val callbackSpecs=if null selectedCallbacks then "" else
        "  (* A callback-borrowed native identity, valid until that callback returns. *)\n  type native_pointer = RuneForeign.resource option\n" ^
        String.concat(List.map(fn p:ForeignPolicy.callbackPolicy=>let val info=callbackInfo(#foreign p)
          in "  (* The projected function type of " ^ #foreign p ^ ". *)\n  type " ^ #name info ^ " = " ^ render(#input info) ^ " -> " ^ render(#output info) ^ "\n" end)selectedCallbacks)
      val callbackBodies=if null selectedCallbacks then "" else
        "  type native_pointer = RuneForeign.resource option\n" ^
        String.concat(List.map(fn p:ForeignPolicy.callbackPolicy=>let val info=callbackInfo(#foreign p)
          in "  type " ^ #name info ^ " = " ^ render(#input info) ^ " -> " ^ render(#output info) ^ "\n" end)selectedCallbacks)
      val resourceSpecs=String.concat(List.map(fn resource=>"  (* An abstract native " ^ resource ^ " handle with shared closed state. *)\n  type " ^ resource ^ "\n" ^
        "  (* `release_" ^ resource ^ " value` closes an owned or borrowed handle explicitly. *)\n  val release_" ^ resource ^ " : " ^ resource ^ " -> unit\n" ^
        "  (* `raw_" ^ resource ^ " value` exposes its checked identity for explicit raw access. *)\n  val raw_" ^ resource ^ " : " ^ resource ^ " -> RuneForeign.resource\n") (#resources policy))
      val resourceBodies=String.concat(List.map(fn resource=>"  datatype " ^ resource ^ " = Handle_" ^ resource ^ " of handleState\n" ^
        "  fun unpack_" ^ resource ^ " (Handle_" ^ resource ^ " value)=value\n" ^
        "  fun release_" ^ resource ^ " value=closeHandle(unpack_" ^ resource ^ " value)\n" ^
        "  fun raw_" ^ resource ^ " value=rawHandle(unpack_" ^ resource ^ " value)\n") (#resources policy))
      val common="  type handleState={pointer:RuneForeign.resource,owner:ForeignOwner.owner option,closed:bool ref,borrows:int ref,retained:(unit->unit) option,active:int ref}\n" ^
        "  datatype session=Session of {native:" ^ raw ^ ".session,borrowed:handleState list ref,owned:handleState list ref,active:int ref}\n" ^
        "  exception ForeignFailure of {foreign:string,result:RuneForeign.result,text:string option}\n" ^
        "  fun nativeSession(Session{native,...})=native\n" ^
        "  fun openSession {libraries}=Session{native=" ^ raw ^ ".openSession{libraries=libraries},borrowed=ref [],owned=ref [],active=ref 0}\n" ^
        "  fun enterCall(Session{active,...}) scope=(active:= !active+1;ForeignScope.defer(scope,fn()=>active:= !active-1))\n" ^
        "  fun retired({pointer,owner,closed,retained,...}:handleState)=\n" ^
        "    if !closed then true else if RuneForeign.isLive pointer then false else (closed:=true;Option.app(fn release=>release())retained;true)\n" ^
        "  fun rawHandle(value as {pointer,...}:handleState)=if retired value then raise ForeignOwner.Closed else pointer\n" ^
        "  fun closeHandle(value as {pointer,owner,closed,borrows,retained,active}:handleState)=\n" ^
        "    if retired value then raise ForeignOwner.Closed else if !borrows>0 then raise ForeignOwner.Busy else\n" ^
        "    let val ()=active:= !active+1\n" ^
        "    in ((case owner of SOME value=>ForeignOwner.close value | NONE=>RuneForeign.release pointer;closed:=true;Option.app(fn release=>release())retained;active:= !active-1)\n" ^
        "        handle error=>(active:= !active-1;ignore(retired value);raise error)) end\n" ^
        "  fun retainHandle(value as {owner,borrows,...}:handleState)=\n" ^
        "    let val pointer=rawHandle value val releaseOwner=case owner of NONE=>(fn()=>()) | SOME owner=>ForeignOwner.retain owner\n" ^
        "        val ()=borrows:= !borrows+1 val released=ref false\n" ^
        "    in fn()=>if !released then () else (released:=true;borrows:= !borrows-1;releaseOwner()) end\n" ^
        "  fun borrowHandle scope value=let val release=retainHandle value val _=ForeignScope.defer(scope,release) in rawHandle value end\n" ^
        "  fun makeHandle(Session{borrowed,owned,active,...}) pointer owner retained=\n" ^
        "    let val ()=borrowed:=List.filter(fn value=>not(retired value))(!borrowed)\n" ^
        "        val ()=owned:=List.filter(fn value=>not(retired value))(!owned)\n" ^
        "        val value={pointer=pointer,owner=owner,closed=ref false,borrows=ref 0,retained=retained,active=active}\n" ^
        "    in (case owner of NONE=>borrowed:=value:: !borrowed | SOME _=>owned:=value:: !owned);value end\n" ^
        "  fun closeSession(Session{native,borrowed,owned,active})=\n" ^
        "    let val ()=if !active>0 orelse List.exists(fn value=>not(retired value))(!owned) then raise ForeignOwner.Busy else ()\n" ^
        "        fun close []=borrowed:=[] | close(value::rest)=(if retired value then () else closeHandle value;borrowed:=rest;close rest)\n" ^
        "    in close(!borrowed);" ^ raw ^ ".closeSession native;owned:=[];borrowed:=[] end\n" ^
        "  fun scopedBuffer scope length=let val buffer=ForeignMemory.allocate length val _=ForeignScope.defer(scope,fn()=>ForeignMemory.release buffer) in buffer end\n" ^
        "  fun inputText scope encoding terminated extent NONE=NONE\n" ^
        "    | inputText scope encoding terminated extent(SOME text)=\n" ^
        "      let val bytes=ForeignText.encode{encoding=encoding,littleEndian=" ^ little ^ ",terminated=terminated,text=text}\n" ^
        "          val unitBytes=case encoding of ForeignText.Utf16=>2 | _=>1\n" ^
        "          val capacity=case extent of NONE=>size bytes | SOME count=>IntInf.toInt(IntInf.*(IntInf.fromInt count,IntInf.fromInt unitBytes))\n" ^
        "          val ()=if capacity<size bytes then raise ForeignMemory.Bounds else ()\n" ^
        "          val padded=bytes ^ CharVector.tabulate(capacity-size bytes,fn _=>Char.chr 0)\n" ^
        "          val buffer=ForeignMemory.fromBytes padded val _=ForeignScope.defer(scope,fn()=>ForeignMemory.release buffer)\n" ^
        "      in SOME(ForeignMemory.raw buffer) end\n" ^
        "  fun readText encoding terminated pointer extent=\n" ^
        "    let val unitBytes=case encoding of ForeignText.Utf16=>2 | _=>1\n" ^
        "        val limit=case extent of NONE=>16777216 | SOME count=>IntInf.toInt(IntInf.*(IntInf.fromInt count,IntInf.fromInt unitBytes))\n" ^
        "        fun loop(offset,parts)=if offset>limit-unitBytes then raise ForeignMemory.Bounds else\n" ^
        "          let val bytes=RuneForeign.read(pointer,Word64.fromInt offset,unitBytes)\n" ^
        "          in if CharVector.all(fn c=>c=Char.chr 0)bytes then String.concat(List.rev(bytes::parts)) else loop(offset+unitBytes,bytes::parts) end\n" ^
        "        val bytes=if terminated then loop(0,[]) else case extent of SOME _=>RuneForeign.read(pointer,0w0,limit) | NONE=>raise ForeignMemory.Bounds\n" ^
        "    in ForeignText.decode{encoding=encoding,littleEndian=" ^ little ^ ",terminated=terminated,bytes=bytes} end\n"
      val signatureText="(* Generated checked public foreign projection.\n\n   Area: Foreign interfaces *)\nsignature " ^ signatureName ^ " =\nsig\n" ^
        "  (* An explicit native session. *)\n  type session\n" ^ resourceSpecs ^ callbackSpecs ^
        "  (* A native failure retains its raw status, captured error and optional immediate text. *)\n" ^
        "  exception ForeignFailure of {foreign:string,result:RuneForeign.result,text:string option}\n" ^
        "  (* `openSession {libraries}` creates a lazy session with explicit library paths. *)\n  val openSession : {libraries:string list} -> session\n" ^
        "  (* `closeSession session` releases borrowed identities and closes native descriptors. *)\n  val closeSession : session -> unit\n" ^
        String.concat(List.map #specification emitted) ^ "end\n"
      val structureText="(* Implements: " ^ signatureName ^ " *)\nstructure " ^ module ^ " :> " ^ signatureName ^ " =\nstruct\n" ^
        common ^ resourceBodies ^ callbackBodies ^ String.concat(List.map #body emitted) ^ "end\n"
    in {signatureText=signatureText,structureText=structureText} end
end
