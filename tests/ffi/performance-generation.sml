(* Fresh-VM first use and repeated pipeline/stage costs. OS caches are unmanaged. *)
structure GenerationPerformance =
struct
  val sourceRoot=case CommandLine.arguments() of [path]=>path | _=>raise Fail "expected production source root"
  val options=RuneffiMain.parse["generate","--config",sourceRoot ^ "/tests/ffi/generator/scalars.ffi",
    "--target",sourceRoot ^ "/ffi/targets/linux-x86_64.json","--layout","gen_record"]
  fun number value=Json.Number(String.translate(fn #"~"=>"-" | c=>str c)(Real.toString value))
  fun measure phase iterations body=
    let val first=Runtime.stats() val resources=RuneForeign.live()
        val timer=Timer.startCPUTimer() val started=Runtime.clock()
        fun loop 0 checksum=checksum
          | loop count checksum=let val result=body()
            in if checksum=0 orelse result=checksum then loop(count-1)result else raise Fail "changed generation size" end
        val checksum=loop iterations 0
        val elapsed=Time.toReal(Time.-(Runtime.clock(),started))
        val {usr,sys}=Timer.checkCPUTimer timer val cpu=Time.toReal(Time.+(usr,sys))
        val last=Runtime.stats() val afterResources=RuneForeign.live()
        val ()=if resources=0w0 andalso afterResources=0w0 then () else raise Fail "generator has native resources"
        val ()=print(Json.encode(Json.Object[("implementation",Json.String "rune"),("phase",Json.String phase),
          ("iterations",Json.int iterations),("cpuSeconds",number cpu),("wallSeconds",number elapsed),
          ("checksum",Json.String(Int.toString checksum)),("smlAllocatedBytes",Json.int(#bytes last- #bytes first)),
          ("smlAllocatedObjects",Json.int(#objects last- #objects first)),("collections",Json.int(#collections last- #collections first)),
          ("foreignResourcesBefore",Json.String "0"),("foreignResourcesAfter",Json.String "0"),
          ("bufferPayloadAllocatedBytes",Json.int 0),("peakBufferPayloadBytes",Json.int 0),("nativeMetadataBytes",Json.Null)]) ^ "\n")
    in () end
  fun bytes artifacts=List.foldl(fn({text,...}:ForeignGenerate.artifact,total)=>String.size text+total)0 artifacts
  fun whole()=bytes(#files(RuneffiMain.package(RuneffiMain.inputs options)))
  val ()=measure "generation-first" 1 whole
  val ()=measure "generation-warm" 10 whole
  val policy=ForeignPolicy.decode{file= #config options,text=RuneffiMain.read(#config options)}
  val profile=ForeignTarget.decode{file= #target options,text=RuneffiMain.read(#target options)}
  val roots=[OS.FileSys.fullPath(OS.Path.dir(#config options))]
  val source={file="<performance>",text=String.concat(List.map(fn header=>"#include <" ^ header ^ ">\n") (#headers policy))}
  fun preprocess()=CPreprocess.run{source=source,predefined= #predefined profile,resolve=CFiles.resolver roots,
    width=64,maxDepth=256,maxExpansions=10000000}
  val ()=measure "preprocess" 10(fn()=>length(#tokens(preprocess())))
  val preprocessed=preprocess()
  fun parse()= #declarations(CParse.translationUnit{tokens= #tokens preprocessed,predefinedTypes=[]})
  val ()=measure "parse" 10(fn()=>length(parse()))
  val declarations=parse()
  fun emit()=ForeignGenerate.emit{policy=policy,profile=profile,declarations=declarations,macros= #macros preprocessed,
    layouts=["gen_record"],fields=[],constants=[],sourceName=OS.Path.file}
  val ()=measure "projection-generation" 10(fn()=>bytes(emit()))
  val artifacts=emit()
  val ()=measure "packaging" 10(fn()=>bytes(#files(RuneffiMain.package{artifacts=artifacts,name= #structureName policy})))
end
