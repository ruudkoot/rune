(* Implements: FOREIGN_GENERATE *)
structure ForeignGenerate : FOREIGN_GENERATE =
struct
  type artifact = {path : string, text : string}
  type field = {aggregate : string, path : string list, writable : bool}
  type binding = {foreign : string, raw : string, symbol : string, abi : int,
    result : string, arguments : string list, policy : ForeignPolicy.functionPolicy,
    native : {result : CParse.ctype, parameters : CParse.parameter list,
      variadic : bool, prototype : bool}, source : ForeignModel.source}
  exception Error = ForeignModel.Error
  fun quote text = "\"" ^ String.toString text ^ "\""
  fun join values = String.concatWith ", " values
  fun list values = "[" ^ join values ^ "]"
  fun upper text = String.map Char.toUpper text
  fun natural value = if value < 0 then "~" ^ IntInf.toString (IntInf.~ value) else IntInf.toString value
  fun emit {policy=p:ForeignPolicy.policy, profile:ForeignTarget.profile, declarations, layouts, fields, constants, sourceName} =
    let
      val name = #structureName p
      val signatureName = upper name
      val source = #source p
      fun fail position message = raise Error (position, message)
      val model = ForeignModel.fromC declarations
      val bindings = ForeignValidate.resolve {declarations=model, policy=p}
      val analysis = CAnalysis.create {target= #analysis profile, declarations=declarations}
      val target = #objects (#analysis profile)
      fun strip (CParse.Attributed (base, _)) = strip base | strip ty = ty
      fun functionName (CParse.Declaration {name=SOME other, ctype, storage, location, ...}) =
            if List.exists (fn word => word="typedef") storage then NONE
            else (case strip ctype of CParse.Function _ => SOME (other, ctype, location) | _ => NONE)
        | functionName _ = NONE
      val originals = List.mapPartial functionName declarations
      fun original foreign position = case List.find (fn (other, _, location) => other=foreign andalso location=position) originals of
          SOME (_, ty, _) => ty | NONE => fail position ("missing original C function: " ^ foreign)
      fun resolve ty = CAnalysis.resolve analysis ty
      fun integer ty = CAnalysis.integer analysis ty
      fun scalar position ty =
        let val resolved=resolve ty
            val ()=case resolved of CParse.Builtin "void"=>() | CParse.Function _=>()
              | _=>ignore(CAnalysis.layout analysis {ty=ty,source=position})
        in case resolved of
          CParse.Pointer _ => "Pointer" | CParse.Array _ => "Pointer" | CParse.Function _ => "Pointer"
        | CParse.Builtin "void" => "Void"
        | CParse.Builtin "_Bool" => "UInt8"
        | CParse.Builtin "float" => "Float32" | CParse.Builtin "double" => "Float64"
        | other => (case integer ty of SOME {width, signed, ...} =>
            if List.exists (fn n => n=width) [8,16,32,64] then
              (if signed then "SInt" else "UInt") ^ Int.toString width
            else fail position "selected integer width requires a C adapter"
          | NONE => fail position "selected by-value C object requires a C adapter") end
      fun convention ty =
        let fun attributes (CParse.Attributed (base, attrs)) =
                  List.concat (List.map (fn tokens => String.tokens (fn c => not (Char.isAlphaNum c orelse c= #"_"))
                    (CLex.spelling tokens)) attrs) @ attributes base
              | attributes _ = []
            val words=attributes ty
            val ()=if List.exists(fn word=>List.exists(fn unsupported=>word=unsupported)
              ["__fastcall","fastcall","__vectorcall","vectorcall","__thiscall","thiscall","__regcall","regcall",
               "ms_abi","sysv_abi","regparm","__regparm__","pcs","__pcs__","aarch64_vector_pcs","preserve_most","preserve_all"])words
              then fail source "selected calling convention requires a typed C adapter" else ()
        in if #abi profile="win32" andalso List.exists (fn a => a="__stdcall" orelse a="stdcall" orelse a="WINAPI" orelse a="CALLBACK")
          words then 1 else 0 end
      fun describe (b:ForeignValidate.binding) =
        let val f= #policy b val ty=original (#foreign f) (#source (#declaration b))
            val native=case resolve ty of CParse.Function native=>native
              | _=>fail (#source f) "selected declaration is not a C function"
            val ()=if #prototype native andalso not (#variadic native) then ()
              else fail (#source f) "dynamic variadic or unprototyped selection requires a fixed typed C adapter"
            val result=scalar (#source f) (#result native)
            val arguments=List.map (fn CParse.Parameter {ctype,...}=>scalar (#source f) ctype) (#parameters native)
        in {foreign= #foreign f, raw=getOpt (#raw f, ForeignPolicy.rawName (#foreign f)),
          symbol= #foreign f, abi=convention ty, result=result, arguments=arguments, policy=f,
          native=native, source= #source (#declaration b)} end
      val functions=List.map describe bindings
      val modelIndex=ForeignModel.index model
      val helperNames=List.foldl(fn(name,known)=>if List.exists(fn other=>other=name)known then known else known @ [name]) []
        (List.concat(List.map(fn f=>
          (case #ownership(#result(#policy f)) of SOME(ForeignPolicy.Owned release)=>[release] | _=>[]) @
          (case #getter(#errors(#policy f)) of SOME getter=>[getter] | NONE=>[]))functions))
      val helperNames=List.filter(fn helper=>not(List.exists(fn f=> #foreign f=helper)functions))helperNames
      fun helper name=
        let val declaration=case ForeignModel.lookup(modelIndex,{family="c",namespace="function",name=name}) of SOME d=>d
              | NONE=>fail source("missing native policy helper: " ^ name)
            val ty=original name (#source declaration)
            val f=case resolve ty of CParse.Function f=>f | _=>fail source "native policy helper is not a function"
        in {foreign=name,symbol=name,abi=convention ty,result=scalar (#source declaration)(#result f),
          arguments=List.map(fn CParse.Parameter{ctype,...}=>scalar (#source declaration)ctype)(#parameters f),source= #source declaration} end
      val helpers=List.map helper helperNames
      fun unique what values=
        let fun loop []=() | loop(value::rest)=if List.exists(fn other=>other=value)rest
              then fail source ("duplicate generated " ^ what ^ ": " ^ value) else loop rest
        in loop values end
      val ()=unique "raw member" (["openSession","closeSession","prepare","call","callDeferred"] @ List.map #raw functions)
      val publicReserved=["openSession","closeSession","ForeignFailure","Session","nativeSession","rawHandle","closeHandle","retired",
        "retainHandle","borrowHandle","makeHandle","scopedBuffer","inputText","readText","enterCall"] @
        List.concat(List.map(fn resource=>["release_" ^ resource,"raw_" ^ resource,"unpack_" ^ resource,"Handle_" ^ resource])(#resources p))
      val ()=unique "public member" (publicReserved @ List.map (fn f=> #name (#policy f))functions)
      val ()=List.app(fn resource=>if List.exists(fn reserved=>resource=reserved)
        ["session","handleState","native_pointer","unit","int","word","real","char","string","bool","list","option","vector","array","exn","order"]
        then fail source("reserved generated resource type: " ^ resource) else ())(#resources p)
      fun descriptor (foreign, symbol, abi, result, arguments) =
        "{name=" ^ quote foreign ^ ", symbol=" ^ quote symbol ^ ", abi=" ^ Int.toString abi ^
        ", result=RuneForeign." ^ result ^ ", arguments=" ^ list (List.map (fn a=>"RuneForeign." ^ a) arguments) ^ "}"
      fun fieldAdapter ({aggregate,path,writable}:field) =
        let val ty=CParse.Named aggregate
            fun object ty=case resolve ty of
                  CParse.Record {kind,tag=SOME tag,fields=NONE,...} =>
                    (case CAnalysis.lookup analysis {namespace=case kind of CParse.Struct=>"struct" | CParse.Union=>"union",name=tag} of
                       SOME ty=>resolve ty | NONE=>fail source ("incomplete field adapter aggregate: " ^ tag))
                | ty=>ty
            fun member ty []=ty
              | member ty (part::rest) = case object ty of
                  CParse.Record {fields=SOME members,...} =>
                    (case List.find (fn CParse.Field {name,...}=>name=SOME part) members of
                       SOME (CParse.Field {ctype,...})=>member ctype rest
                     | NONE=>fail source ("unknown selected C field: " ^ aggregate ^ "." ^ String.concatWith "." path))
                | _=>fail source "field adapter path enters a non-aggregate"
            val fieldType=member ty path
            val getter="rf_field_" ^ aggregate ^ "_" ^ String.concatWith "_" path
            val _=if ForeignPolicy.rawName getter=getter then () else fail source "invalid field adapter identifier"
            val result=scalar source fieldType
            val code=ForeignShim.field {name=getter,aggregate=ty,path=path,ty=fieldType,writable=writable}
        in {foreign=getter ^ "_get",symbol=getter ^ "_get",abi=0,result=result,arguments=["Pointer"],code=code} ::
          (if writable then [{foreign=getter ^ "_set",symbol=getter ^ "_set",abi=0,result="Void",arguments=["Pointer",result],code=""}] else []) end
      val fieldAdapters=List.concat (List.map fieldAdapter fields)
      val ()=unique "native descriptor" (List.map #foreign functions @ List.map #foreign fieldAdapters)
      val allDescriptors=List.map (fn f=>descriptor (#foreign f,#symbol f,#abi f,#result f,#arguments f)) functions @
        List.map (fn f=>descriptor (#foreign f,#symbol f,#abi f,#result f,#arguments f)) helpers @
        List.map (fn f=>descriptor (#foreign f,#symbol f,#abi f,#result f,#arguments f)) fieldAdapters
      val prefix="(* Generated by runeffi schema 1 from original headers and declarative policy. *)\n"
      fun rawSpec ({raw,foreign,...}:binding) =
        "  (* `" ^ raw ^ " session arguments` invokes " ^ foreign ^ "; native status and captured errors are retained. *)\n" ^
        "  val " ^ raw ^ " : session -> RuneForeign.argument list -> RuneForeign.result\n"
      val rawSignature=prefix ^ "(* Raw native bindings for " ^ name ^ ".\n\n   Area: Foreign interfaces *)\n" ^
        "signature " ^ signatureName ^ "_RAW =\nsig\n" ^
        "  (* An explicit lazy native session. *)\n  type session\n" ^
        "  (* `openSession {libraries}` selects ordered native library paths. Empty paths use sidecar defaults. *)\n" ^
        "  val openSession : {libraries : string list} -> session\n" ^
        "  (* `closeSession session` releases prepared descriptors before unloading their libraries. *)\n" ^
        "  val closeSession : session -> unit\n" ^
        "  (* `prepare session name` returns a session-owned prepared call for a declared native symbol. *)\n" ^
        "  val prepare : session -> string -> RuneForeign.resource\n" ^
        "  (* `call session name arguments` invokes a declared function or generated field adapter. *)\n" ^
        "  val call : session -> string -> RuneForeign.argument list -> RuneForeign.result\n" ^
        "  (* `callDeferred session name arguments` returns owned output before a saved callback exception propagates. *)\n" ^
        "  val callDeferred : session -> string -> RuneForeign.argument list -> {result:RuneForeign.result,callbackException:exn option}\n" ^
        String.concat (List.map rawSpec functions) ^ "end\n"
      val facts="{pointerBytes=" ^ Int.toString (#size (#pointer target)) ^ ", littleEndian=" ^
        Bool.toString (#byteOrder profile=ForeignModel.Little) ^ ", stdcall=" ^ Bool.toString (#abi profile="win32") ^ "}"
      val architecture=let val triple= #triple profile
        in if String.isPrefix "x86_64" triple orelse String.isPrefix "amd64" triple then "x86_64"
          else if List.exists(fn prefix=>String.isPrefix prefix triple)["i386","i486","i586","i686","x86-"] then "x86"
          else if String.isPrefix "aarch64" triple orelse String.isPrefix "arm64" triple then "aarch64"
          else if String.isPrefix "powerpc64" triple orelse String.isPrefix "ppc64" triple then "powerpc64" else "other" end
      fun scalarFact(name,spelling)=
        let val value=if name="pointer" then #pointer target else case List.find(fn(n,_)=>n=spelling)(#scalars target) of
              SOME(_,value)=>value | NONE=>fail source("target profile is missing scalar ABI facts: " ^ name)
        in "{name=" ^ quote name ^ ",size=" ^ Int.toString(#size value) ^ ",alignment=" ^ Int.toString(#alignment value) ^ "}" end
      val abiFacts="{architecture=" ^ quote architecture ^ ",charBits=8,charSigned=" ^ Bool.toString(#charSigned(#analysis profile)) ^ ",scalars=" ^
        list(List.map scalarFact [("char","char"),("short","short"),("int","int"),("long","long"),("longLong","long long"),
          ("pointer","pointer"),("wchar","wchar_t"),("float","float"),("double","double"),("bool","_Bool")]) ^ "}"
      val rawStructure=prefix ^ "(* Implements: " ^ signatureName ^ "_RAW *)\nstructure " ^ name ^ "Raw :> " ^
        signatureName ^ "_RAW =\nstruct\n  type session = ForeignGenerated.session\n" ^
        "  val descriptors = " ^ list allDescriptors ^ "\n" ^
        "  fun openSession {libraries} = ForeignGenerated.createChecked {libraries=if null libraries then " ^
        list (List.map quote (#libraries p)) ^ " else libraries, descriptors=descriptors, target=" ^ facts ^ ",abiFacts=" ^ abiFacts ^ "}\n" ^
        "  val closeSession = ForeignGenerated.close\n  val prepare = ForeignGenerated.prepare\n  val call = ForeignGenerated.invoke\n  val callDeferred = ForeignGenerated.invokeDeferred\n" ^
        String.concat (List.map (fn {raw,foreign,...}=>"  fun " ^ raw ^ " session arguments = call session " ^ quote foreign ^ " arguments\n") functions) ^ "end\n"
      fun layoutName original = ForeignPolicy.rawName original
      fun layoutArtifact original =
        let val value=CAnalysis.layout analysis {ty=CParse.Named original,source=source}
            fun fields prefix base (CLayout.Aggregate {fields=members,...}) = List.concat (List.map
                  (fn CLayout.FieldLayout {name,offset,layout,...} =>
                    let val parts=case name of NONE=>prefix | SOME n=>prefix @ [n]
                        val own=case name of NONE=>[] | SOME _=>[(String.concatWith "_" parts,base+offset)]
                    in own @ fields parts (base+offset) layout end) members)
              | fields _ _ _ = []
            val constants=("sizeof_" ^ layoutName original,CLayout.size value) ::
              ("alignment_" ^ layoutName original,IntInf.fromInt (CLayout.alignment value)) ::
              List.map (fn (path,offset)=>("offset_" ^ layoutName original ^ "_" ^ path,offset)) (fields [] 0 value)
        in constants end
      val layoutValues=List.concat (List.map layoutArtifact layouts)
      val ()=unique "layout member" (List.map #1 layoutValues)
      val ()=unique "constant" (List.map #1 constants)
      val layoutSignature=prefix ^ "(* Target C object measurements.\n\n   Area: Foreign interfaces *)\nsignature " ^
        signatureName ^ "_LAYOUT =\nsig\n" ^ String.concat (List.map (fn (n,_)=>"  (* Target byte measurement from the original declaration. *)\n  val " ^ n ^ " : int\n") layoutValues) ^ "end\n"
      val queries="  (* Target native pointer width in bytes. *)\n  val pointerBytes : int\n" ^
        "  (* Target native byte order. *)\n  val littleEndian : bool\n" ^
        "  (* Whether the target ABI represents nonnegative ordinary C enums as signed int. *)\n  val enumSigned : bool\n" ^
        "  (* `sizeOf name` returns a selected original C type's target byte size. *)\n  val sizeOf : string -> int\n" ^
        "  (* `offset (name, path)` returns a selected named field's target byte offset. *)\n  val offset : string * string list -> int\n" ^
        "  (* `constant name` returns a selected target-evaluated C integer constant. *)\n  val constant : string -> IntInf.int\n"
      val layoutSignature=String.substring(layoutSignature,0,size layoutSignature-4) ^ queries ^ "end\n"
      val layoutStructure=prefix ^ "(* Implements: " ^ signatureName ^ "_LAYOUT *)\nstructure " ^ name ^ "Layout : " ^
        signatureName ^ "_LAYOUT =\nstruct\n  val pointerBytes = " ^ Int.toString (#size (#pointer target)) ^
        "\n  val littleEndian = " ^ Bool.toString (#byteOrder profile=ForeignModel.Little) ^ "\n" ^
        "  val enumSigned = " ^ Bool.toString (#enumRule (#analysis profile)=CAnalysis.SignedEnums) ^ "\n" ^
        String.concat (List.map (fn(n,v)=>"  val " ^ n ^ " = " ^ natural v ^ "\n") layoutValues) ^
        "  fun lookup values name = case List.find (fn (other, _) => other = name) values of SOME (_, value) => value | NONE => raise Fail (\"unselected C layout or constant: \" ^ name)\n" ^
        "  val measurements = " ^ list(List.map(fn(n,v)=>"(" ^ quote n ^ ", " ^ natural v ^ ")")layoutValues) ^ "\n" ^
        "  fun sizeOf name = lookup measurements (\"sizeof_\" ^ name)\n" ^
        "  fun offset (name, path) = lookup measurements (\"offset_\" ^ name ^ \"_\" ^ String.concatWith \"_\" path)\n" ^
        "  val constants : (string * IntInf.int) list = " ^ list(List.map(fn(n,v)=>"(" ^ quote n ^ ", " ^ natural v ^ ")")constants) ^ "\n" ^
        "  fun constant name = lookup constants name\nend\n"
      val projected=ForeignPublic.emit {policy=p,profile=profile,declarations=declarations}
      val publicSignature=prefix ^ #signatureText projected
      val publicStructure=prefix ^ #structureText projected
      val adapters=List.filter(fn f=>isSome(#adapter(#policy f)))functions
      fun sourceJson ({file,line,column}:ForeignModel.source)=Json.Object[("file",Json.String (sourceName file)),("line",Json.int line),("column",Json.int column)]
      val identities=List.map(fn f=>{family="c",namespace="function",name= #foreign f})functions @
        List.map(fn f=>{family="c",namespace="function",name= #foreign f})helpers
      val coverage=ForeignCoverage.report {declarations=model,selected=identities,generated=identities,shimmed=[],unsupported=[]}
      val coverage=List.map(fn {identity,source={file,line,column},state}:ForeignCoverage.entry=>
        {identity=identity,source={file=sourceName file,line=line,column=column},state=state})coverage
      val manifest=Json.Object[("schema",Json.int 1),("generator",Json.String "runeffi-1"),("structure",Json.String name),
        ("target",Json.String (#name profile)),("functions",Json.Array(List.map(fn f=>Json.Object[
          ("foreign",Json.String (#foreign f)),("raw",Json.String (#raw f)),("source",sourceJson (#source f)),
          ("mechanism",Json.String "libffi-fixed"),("public",case #adapter (#policy f) of NONE=>Json.String "generated"
            | SOME adapter=>Json.Object[("adapter",Json.String adapter)]),
          ("result",Json.String (#result f)),("arguments",Json.Array(List.map Json.String (#arguments f)))])functions)),
        ("fieldAdapters",Json.Array(List.map (fn f=>Json.String (#foreign f)) fieldAdapters)),
        ("helpers",Json.Array(List.map(fn f=>Json.Object[("foreign",Json.String(#foreign f)),("source",sourceJson(#source f))])helpers)),
        ("coverage",ForeignCoverage.json coverage),
        ("layouts",Json.Array(List.map Json.String layouts)),
        ("measurements",Json.Object(List.map(fn(n,v)=>(n,Json.Number(IntInf.toString v)))layoutValues)),
        ("constants",Json.Object(List.map(fn(n,v)=>(n,Json.Number(if v<0 then "-" ^ IntInf.toString(IntInf.~ v) else IntInf.toString v)))constants))]
      val files=[{path="raw_sig.sml",text=rawSignature},{path="raw.sml",text=rawStructure},
        {path="layout_sig.sml",text=layoutSignature},{path="layout.sml",text=layoutStructure},
        {path="public_sig.sml",text=publicSignature},{path="public.sml",text=publicStructure},
        {path="ffi-manifest.json",text=Json.encodeIndented 2 manifest ^ "\n"},
        {path="library.build",text="libraries ffi/runtime end\nannotate \"demand\" in\n  raw_sig.sml\n  raw.sml\n  layout_sig.sml\n  layout.sml\n  public_sig.sml\n  public.sml\nend\n"},
        {path="README.md",text="# " ^ name ^ " generated bindings\n\nGenerated from original C declarations and version-one sidecar policy.\n\n" ^
          "Raw calls return the native status and captured error unchanged. Sessions open libraries lazily.\n" ^
          "Target: `" ^ #name profile ^ "`. Public adapters: " ^ String.concatWith ", " (List.map(fn f=> #name (#policy f)) adapters) ^ ".\n"}]
    in files @ (if null fieldAdapters then [] else [{path="shims.c",text=ForeignShim.preamble (#headers p) ^
      String.concat (List.map #code fieldAdapters)}]) end
end
