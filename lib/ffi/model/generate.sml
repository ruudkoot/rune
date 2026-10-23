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
      fun functionName (CParse.Declaration {name=SOME other, ctype, storage, ...}) =
            if List.exists (fn word => word="typedef") storage then NONE
            else (case strip ctype of CParse.Function _ => SOME (other, ctype) | _ => NONE)
        | functionName _ = NONE
      val originals = List.mapPartial functionName declarations
      fun original foreign position = case List.find (fn (other, _) => other=foreign) originals of
          SOME (_, ty) => ty | NONE => fail position ("missing original C function: " ^ foreign)
      fun resolve ty = CAnalysis.resolve analysis ty
      fun integer ty = CAnalysis.integer analysis ty
      fun scalar position ty =
        case resolve ty of
          CParse.Pointer _ => "Pointer" | CParse.Array _ => "Pointer" | CParse.Function _ => "Pointer"
        | CParse.Builtin "void" => "Void"
        | CParse.Builtin "_Bool" => "UInt8"
        | CParse.Builtin "float" => "Float32" | CParse.Builtin "double" => "Float64"
        | other => (case integer ty of SOME {width, signed, ...} =>
            if List.exists (fn n => n=width) [8,16,32,64] then
              (if signed then "SInt" else "UInt") ^ Int.toString width
            else fail position "selected integer width requires a C adapter"
          | NONE => fail position "selected by-value C object requires a C adapter")
      fun convention ty =
        let fun attributes (CParse.Attributed (base, attrs)) =
                  List.concat (List.map (fn tokens => String.tokens (fn c => not (Char.isAlphaNum c orelse c= #"_"))
                    (CLex.spelling tokens)) attrs) @ attributes base
              | attributes _ = []
        in if #abi profile="win32" andalso List.exists (fn a => a="__stdcall" orelse a="WINAPI" orelse a="CALLBACK")
          (attributes ty) then 1 else 0 end
      fun describe (b:ForeignValidate.binding) =
        let val f= #policy b val ty=original (#foreign f) (#source f)
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
      fun unique what values=
        let fun loop []=() | loop(value::rest)=if List.exists(fn other=>other=value)rest
              then fail source ("duplicate generated " ^ what ^ ": " ^ value) else loop rest
        in loop values end
      val ()=unique "raw member" (["openSession","closeSession","prepare","call"] @ List.map #raw functions)
      val ()=unique "public member" (["openSession","closeSession"] @ List.map (fn f=> #name (#policy f))functions)
      fun descriptor (foreign, symbol, abi, result, arguments) =
        "{name=" ^ quote foreign ^ ", symbol=" ^ quote symbol ^ ", abi=" ^ Int.toString abi ^
        ", result=RuneForeign." ^ result ^ ", arguments=" ^ list (List.map (fn a=>"RuneForeign." ^ a) arguments) ^ "}"
      fun fieldAdapter ({aggregate,path,writable}:field) =
        let val ty=CParse.Named aggregate
            val layout=CAnalysis.layout analysis {ty=ty,source=source}
            val _=CLayout.member (layout,path)
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
        String.concat (List.map rawSpec functions) ^ "end\n"
      val facts="{pointerBytes=" ^ Int.toString (#size (#pointer target)) ^ ", littleEndian=" ^
        Bool.toString (#byteOrder profile=ForeignModel.Little) ^ ", stdcall=" ^ Bool.toString (#abi profile="win32") ^ "}"
      val rawStructure=prefix ^ "(* Implements: " ^ signatureName ^ "_RAW *)\nstructure " ^ name ^ "Raw :> " ^
        signatureName ^ "_RAW =\nstruct\n  type session = ForeignGenerated.session\n" ^
        "  val descriptors = " ^ list allDescriptors ^ "\n" ^
        "  fun openSession {libraries} = ForeignGenerated.create {libraries=if null libraries then " ^
        list (List.map quote (#libraries p)) ^ " else libraries, descriptors=descriptors, target=" ^ facts ^ "}\n" ^
        "  val closeSession = ForeignGenerated.close\n  val prepare = ForeignGenerated.prepare\n  val call = ForeignGenerated.invoke\n" ^
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
      fun automatic ({policy=f,...}:binding) = not (isSome (#adapter f))
      val safe=List.filter automatic functions
      val adapters=List.filter (not o automatic) functions
      fun typeScalar s = case s of "Void"=>ForeignPolicy.Scalar "unit" | "Float32"=>ForeignPolicy.Scalar "real" | "Float64"=>ForeignPolicy.Scalar "real"
        | "Pointer"=>fail source "safe pointer projection requires an explicit generator adapter"
        | _=>if String.isPrefix "SInt" s then ForeignPolicy.Scalar ("int" ^ String.extract(s,4,NONE))
          else ForeignPolicy.Scalar ("word" ^ String.extract(s,4,NONE))
      fun parameterNames parameters = ListPair.map (fn (i,CParse.Parameter {name,...})=>getOpt(name,"arg" ^ Int.toString i))
        (List.tabulate (length parameters,fn i=>i),parameters)
      fun public (f:binding) =
        let val p= #policy f val native= #native f
            val names=parameterNames (#parameters native)
            val values=ListPair.zip(names,List.map typeScalar (#arguments f))
            val types=ForeignProjection.callType {policy=p,inputs=values,result=typeScalar (#result f)}
        in (f,names,values,types) end
      val publicFunctions=List.map public safe
      fun memberSpec (f:binding,names,values,{input,output}) =
        "  (* `" ^ #name (#policy f) ^ " session input` projects " ^ #foreign f ^ " from its original C declaration. *)\n" ^
        "  val " ^ #name (#policy f) ^ " : session -> " ^ ForeignProjection.renderType input ^ " -> " ^ ForeignProjection.renderType output ^ "\n"
      fun inputTree (p:ForeignPolicy.functionPolicy) names = getOpt (#input p,case names of []=>ForeignPolicy.Unit | [name]=>ForeignPolicy.Value name
        | names=>ForeignPolicy.Product (List.map ForeignPolicy.Value names))
      fun tree render ForeignPolicy.Unit="()"
        | tree render (ForeignPolicy.Value value)=render value
        | tree render (ForeignPolicy.Product values)="(" ^ join (List.map (tree render) values) ^ ")"
        | tree render (ForeignPolicy.Fields fields)="{" ^ join (List.map(fn(label,value)=>label ^ "=" ^ tree render value) fields) ^ "}"
      fun annotation (p:ForeignPolicy.functionPolicy) n=List.find(fn a:ForeignPolicy.valuePolicy=> #name a=SOME n)(#parameters p)
      fun projection p n base = case annotation p n of SOME a=>getOpt(#projection a,base) | NONE=>base
      fun encode scalar ty expression =
        let fun number (ForeignPolicy.Scalar "bool")="(if " ^ expression ^ " then 1 else 0)"
              | number (ForeignPolicy.Scalar "int")="IntInf.fromInt " ^ expression
              | number (ForeignPolicy.Scalar n)=
                  if String.isPrefix "int" n then "Int" ^ String.extract(n,3,NONE) ^ ".toLarge " ^ expression
                  else if String.isPrefix "word" n then "Word" ^ String.extract(n,4,NONE) ^ ".toLargeInt " ^ expression
                  else fail source "unsupported safe scalar input projection"
              | number _=fail source "non-scalar projection requires an explicit generator adapter"
        in if scalar="Float32" orelse scalar="Float64" then
            if ty=ForeignPolicy.Scalar "real" then "RuneForeign.Real " ^ expression else fail source "floating projection must be real"
          else if String.isPrefix "SInt" scalar then "RuneForeign.Signed (Int64.fromLarge (" ^ number ty ^ "))"
          else "RuneForeign.Unsigned (Word64.fromLargeInt (" ^ number ty ^ "))" end
      fun decode scalar ty =
        let val signed=String.isPrefix "SInt" scalar
            val value="ForeignBytes.value {signed=" ^ Bool.toString signed ^ ", littleEndian=true, bytes= #bytes result}"
        in case ty of
          ForeignPolicy.Scalar "unit"=>"()"
        | ForeignPolicy.Scalar "real"=>if scalar="Float32" orelse scalar="Float64" then
              "ForeignBytes.real64Value {littleEndian=true, bytes= #bytes result}" else fail source "real projection on non-floating result"
        | ForeignPolicy.Scalar "bool"=>"(" ^ value ^ " <> 0)"
        | ForeignPolicy.Scalar "int"=>"IntInf.toInt (" ^ value ^ ")"
        | ForeignPolicy.Scalar n=>if String.isPrefix "int" n then "Int" ^ String.extract(n,3,NONE) ^ ".fromLarge (" ^ value ^ ")"
            else if String.isPrefix "word" n then "Word" ^ String.extract(n,4,NONE) ^ ".fromLargeInt (" ^ value ^ ")"
            else fail source "unsupported safe scalar output projection"
        | _=>fail source "structured result requires an explicit generator adapter" end
      fun publicBody (f:binding,names,values,{input,output}) =
        let val p= #policy f
            val ()=if List.exists(fn a:ForeignPolicy.valuePolicy=> #direction a=SOME ForeignPolicy.Out orelse #direction a=SOME ForeignPolicy.InOut)(#parameters p)
              then fail (#source p) "output pointer projection requires an explicit generator adapter" else ()
            val ()=if #predicate (#errors p)="none" then () else fail (#source p) "error projection requires an explicit generator adapter"
            fun variable n="value_" ^ ForeignPolicy.rawName n
            val args=ListPair.map(fn((n,ty),scalar)=>encode scalar (projection p n ty) (variable n))(values,#arguments f)
            val resultTy=getOpt(#projection (#result p),typeScalar (#result f))
            val result=decode (#result f) resultTy
            val returned=case #returns p of NONE=>result | SOME t=>tree (fn n=>if n="$result" then result else fail (#source p) "unknown scalar output") t
        in "  fun " ^ #name p ^ " session " ^ tree variable (inputTree p names) ^ " =\n    let val result = " ^
          name ^ "Raw." ^ #raw f ^ " session " ^ list args ^ "\n    in " ^ returned ^ " end\n" end
      val publicSignature=prefix ^ "(* Projected native scalar bindings.\n\n   Area: Foreign interfaces *)\nsignature " ^ signatureName ^ " =\nsig\n" ^
        "  (* Explicit native session. *)\n  type session\n" ^
        "  (* `openSession {libraries}` chooses native library paths without loading them. *)\n  val openSession : {libraries : string list} -> session\n" ^
        "  (* `closeSession session` releases native descriptors and libraries. *)\n  val closeSession : session -> unit\n" ^
        String.concat(List.map memberSpec publicFunctions) ^ "end\n"
      val publicStructure=prefix ^ "(* Implements: " ^ signatureName ^ " *)\nstructure " ^ name ^ " :> " ^ signatureName ^ " =\nstruct\n" ^
        "  type session = " ^ name ^ "Raw.session\n  val openSession = " ^ name ^ "Raw.openSession\n  val closeSession = " ^ name ^ "Raw.closeSession\n" ^
        String.concat (List.map publicBody publicFunctions) ^ "end\n"
      fun sourceJson ({file,line,column}:ForeignModel.source)=Json.Object[("file",Json.String (sourceName file)),("line",Json.int line),("column",Json.int column)]
      val manifest=Json.Object[("schema",Json.int 1),("generator",Json.String "runeffi-1"),("structure",Json.String name),
        ("target",Json.String (#name profile)),("functions",Json.Array(List.map(fn f=>Json.Object[
          ("foreign",Json.String (#foreign f)),("raw",Json.String (#raw f)),("source",sourceJson (#source f)),
          ("mechanism",Json.String "libffi-fixed"),("public",case #adapter (#policy f) of NONE=>Json.String "generated"
            | SOME adapter=>Json.Object[("adapter",Json.String adapter)]),
          ("result",Json.String (#result f)),("arguments",Json.Array(List.map Json.String (#arguments f)))])functions)),
        ("fieldAdapters",Json.Array(List.map (fn f=>Json.String (#foreign f)) fieldAdapters)),
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
