(* Development inspection of original headers and declarative policy.
   No external C compiler participates in these operations. *)
structure ForeignModelMain =
struct
  fun read path = #text(CFiles.read path)
  fun field name value = case Json.member(name,value) of SOME v=>v | NONE=>raise Fail("missing " ^ name)
  fun string(Json.String s)=s | string _=raise Fail "expected JSON string"
  fun array(Json.Array values)=values | array _=raise Fail "expected JSON array"
  fun optional name value = getOpt(Option.map array(Json.member(name,value)),[])
  fun profile path = List.map(fn pair=>case array pair of [name,value]=>(string name,string value)
    | _=>raise Fail "expected macro pair")(array(field "predefined" (Json.decode(read path))))
  fun identity namespace name : ForeignModel.identity = {family="c",namespace=namespace,name=name}
  fun write(path,value) = let val out=TextIO.openOut path
    in TextIO.output(out,Json.encodeIndented 2 value ^ "\n");TextIO.closeOut out end
  fun parse target headers constants roots =
    let fun probe i="runeffi_inventory_constant_" ^ Int.toString i
        val source={file="<runeffi-inspection>",text=String.concat(List.map(fn h=>"#include <" ^ h ^ ">\n")headers) ^
          (if null constants then "" else "enum runeffi_inventory_probe {\n" ^ String.concatWith ",\n"
            (ListPair.map(fn (i,name)=>probe i ^ " = " ^ name)(List.tabulate(length constants,fn i=>i),constants)) ^ "\n};\n")}
        val preprocessed=CPreprocess.run{source=source,predefined=profile target,resolve=CFiles.resolver roots,
          width=64,maxDepth=256,maxExpansions=10000000}
        val parsed= #declarations(CParse.translationUnit{tokens= #tokens preprocessed,predefinedTypes=[]})
        val model=ForeignModel.canonical(ForeignModel.fromC parsed @ ForeignModel.fromCMacros(#macros preprocessed))
        val environment=CEnumConst.collect parsed
        val values=ListPair.map(fn (i,name)=>(name, #integer(CEnumConst.evaluate{environment=environment,width=64,name=probe i})))
          (List.tabulate(length constants,fn i=>i),constants)
    in {declarations=model,constants=values,dependencies=List.filter(fn path=>path<> #file source)(#dependencies preprocessed)} end
  fun inventory target input output roots =
    let val inventory=Json.decode(read input)
        val functions=List.map(string o field "foreign")(array(field "entries" inventory))
        val constants=List.map(string o field "foreign")(optional "constants" inventory)
        val helpers=List.map(string o field "foreign")(optional "helpers" inventory)
        val types=List.map string (optional "requiredTypes" inventory)
        val headers=List.map string(array(field "headers" inventory))
        val parsed=parse target headers constants roots
        val selected=List.map(identity "function")functions @ List.map(identity "macro")helpers @ List.map(identity "typedef")types
        val _=ForeignModel.reachable(#declarations parsed,selected)
        val report=ForeignCoverage.report{declarations= #declarations parsed,selected=selected,generated=[],shimmed=[],
          unsupported=List.map(fn id=>(id,"binding annotations and executable lowering require later delivery evidence"))selected}
        val ()=write(output,Json.Object[("target",Json.String target),("coverage",ForeignCoverage.json report),
          ("constants",Json.Object(List.map(fn(name,value)=>(name,Json.String(IntInf.toString value)))(#constants parsed))),
          ("dependencies",Json.Array(List.map Json.String(#dependencies parsed)))])
    in print("PASS foreign inventory: " ^ Int.toString(length functions) ^ " functions, " ^
      Int.toString(length constants) ^ " constants, " ^ Int.toString(length helpers) ^ " helpers, " ^
      Int.toString(length types) ^ " types uniquely resolved\n") end
  fun policy target input output roots =
    let val policy=ForeignPolicy.decode{file=input,text=read input}
        val parsed=parse target (#headers policy) [] roots
        val bindings=ForeignValidate.resolve{declarations= #declarations parsed,policy=policy}
        val selected=List.map(fn binding:ForeignValidate.binding=> #identity(#declaration binding))bindings
        val report=ForeignCoverage.report{declarations= #declarations parsed,selected=selected,generated=[],shimmed=[],unsupported=[]}
        val ()=write(output,Json.Object[("coverage",ForeignCoverage.json report),
          ("dependencies",Json.Array(List.map Json.String(#dependencies parsed)))])
    in print("PASS foreign policy: " ^ Int.toString(length bindings) ^ " selected declarations validated\n") end
  fun diagnostic({file,line,column}:ForeignModel.source,message)=file ^ ":" ^ Int.toString line ^ ":" ^ Int.toString column ^ ": " ^ message
  fun failure e=case e of ForeignModel.Error p=>diagnostic p | ForeignPolicy.Error p=>diagnostic p
    | CLex.Error p=>diagnostic p | CPreprocess.Error p=>diagnostic p | CParse.Error p=>diagnostic p
    | CEnumConst.Error p=>diagnostic p | _=>General.exnMessage e
  fun main("inventory"::target::input::output::roots)=inventory target input output roots
    | main("policy"::target::input::output::roots)=policy target input output roots
    | main _=raise Fail "expected inventory|policy PROFILE INPUT OUTPUT INCLUDE..."
end
val ()=ForeignModelMain.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"foreign model: " ^ ForeignModelMain.failure e ^ "\n");OS.Process.exit OS.Process.failure)
