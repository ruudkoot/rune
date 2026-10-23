(* Runeffi's filesystem driver. Parsing, policy, layout and emission remain
   reusable SML libraries; this layer performs explicit input and publication. *)
structure RuneffiMain =
struct
  exception Usage of string
  type options={operation:string,config:string,target:string,output:string option,
    roots:string list,layouts:string list,fields:ForeignGenerate.field list,constants:string list}
  type publication={files:ForeignGenerate.artifact list,pointer:string,revision:string,api:string}
  fun fail message=raise Usage message
  fun read path= #text (CFiles.read path)
  fun hash text=Hex.fromBytes (Sha256.digest text)
  fun exists path=(OS.FileSys.access(path,[]) handle OS.SysErr _=>false)
  fun mkdirs path=if path="" orelse path="." orelse exists path then () else
    (mkdirs(OS.Path.dir path); OS.FileSys.mkDir path handle OS.SysErr e=>if exists path then () else raise OS.SysErr e)
  fun write (path,text)=
    let val ()=mkdirs(OS.Path.dir path) val output=TextIO.openOut path
    in (TextIO.output(output,text);TextIO.closeOut output)
      handle e=>(TextIO.closeOut output handle _=>();raise e) end
  fun removeTree path=if not(exists path) then () else
    if OS.FileSys.isDir path then
      let val directory=OS.FileSys.openDir path
          fun loop()=case OS.FileSys.readDir directory of NONE=>() | SOME name=>(removeTree(OS.Path.concat(path,name));loop())
      in (loop();OS.FileSys.closeDir directory;OS.FileSys.rmDir path)
        handle e=>(OS.FileSys.closeDir directory handle _=>();raise e) end
    else OS.FileSys.remove path
  fun unique path=
    let fun choose n=if n>10000 then fail "too many concurrent foreign generations" else
          let val candidate=path ^ "/.publish-" ^ Int.toString n
          in (OS.FileSys.mkDir candidate;candidate) handle OS.SysErr e=>
              if exists candidate then choose(n+1) else raise OS.SysErr e end
    in choose 0 end
  fun parse arguments=
    let val config=ref NONE val target=ref NONE val output=ref NONE
        val roots=ref [] val layouts=ref [] val fields=ref [] val constants=ref []
        fun once slot value flag=case !slot of NONE=>slot:=SOME value | SOME _=>fail("repeated option: " ^ flag)
        fun field writable text=case String.fields(fn c=>c= #":")text of
            [aggregate,path]=>if aggregate<>"" andalso path<>"" then
              {aggregate=aggregate,path=String.fields(fn c=>c= #".")path,writable=writable}
              else fail "field selection requires TYPE:path"
          | _=>fail "field selection requires TYPE:path"
        fun options []=()
          | options("--config"::path::rest)=(once config path "--config";options rest)
          | options("--target"::path::rest)=(once target path "--target";options rest)
          | options("--out"::path::rest)=(once output path "--out";options rest)
          | options("--include"::path::rest)=(roots:=path:: !roots;options rest)
          | options("--layout"::name::rest)=(layouts:=name:: !layouts;options rest)
          | options("--constant"::name::rest)=(constants:=name:: !constants;options rest)
          | options("--field-get"::name::rest)=(fields:=field false name:: !fields;options rest)
          | options("--field-set"::name::rest)=(fields:=field true name:: !fields;options rest)
          | options(option::_)=fail("unknown or incomplete option: " ^ option)
        val operation=case arguments of operation::rest=>(options rest;operation) | []=>fail "expected generate, check or inspect"
        val ()=if List.exists(fn name=>operation=name)["generate","check","inspect"] then () else fail("unknown operation: " ^ operation)
        fun required slot flag=case !slot of SOME value=>value | NONE=>fail("missing " ^ flag)
    in {operation=operation,config=required config "--config",target=required target "--target",output= !output,
      roots=List.rev(!roots),layouts=List.rev(!layouts),fields=List.rev(!fields),constants=List.rev(!constants)} end
  fun identifier text=size text>0 andalso (Char.isAlpha(String.sub(text,0)) orelse String.sub(text,0)= #"_") andalso
    CharVector.all(fn c=>Char.isAlphaNum c orelse c= #"_")text
  fun inputs ({config,target,roots,layouts,fields,constants,...}:options)=
    let val configText=read config val targetText=read target
        val policy=ForeignPolicy.decode {file=config,text=configText}
        val profile=ForeignTarget.decode {file=target,text=targetText}
        val roots=List.map OS.FileSys.fullPath (OS.Path.dir(OS.FileSys.fullPath config)::roots)
        fun sourceName path=
          let fun find []=if String.isPrefix "<" path then path else OS.Path.file path
                | find((root,index)::rest)=
                    if String.isPrefix(root ^ "/")path then "include" ^ Int.toString index ^ "/" ^ String.extract(path,size root+1,NONE)
                    else find rest
          in find(ListPair.zip(roots,List.tabulate(length roots,fn i=>i))) end
        val ()=List.app(fn name=>if identifier name then () else fail("invalid selected constant name: " ^ name))constants
        fun probe i="runeffi_constant_probe_" ^ Int.toString i
        val source={file="<runeffi-input>",text=String.concat(List.map(fn header=>
          if size header>0 andalso not(String.isSubstring "\n" header) andalso not(String.isSubstring ">" header)
          then "#include <" ^ header ^ ">\n" else fail "invalid selected header name")(#headers policy)) ^
          String.concat(ListPair.map(fn(i,name)=>"static const unsigned long long " ^ probe i ^ " = " ^ name ^ ";\n")
            (List.tabulate(length constants,fn i=>i),constants))}
        val preprocessed=CPreprocess.run {source=source,predefined= #predefined profile,resolve=CFiles.resolver roots,
          width=64,maxDepth=256,maxExpansions=10000000}
        val declarations= #declarations(CParse.translationUnit {tokens= #tokens preprocessed,predefinedTypes=[]})
        val analysis=CAnalysis.create {target= #analysis profile,declarations=declarations}
        fun constant(i,name)=
          let val initializer=case List.find(fn CParse.Declaration{name,...}=>name=SOME(probe i) | _=>false)declarations of
                SOME(CParse.Declaration{initializer,...})=>initializer | _=>fail("missing selected constant: " ^ name)
          in (name, #integer(CAnalysis.expression analysis initializer)) end
        val values=ListPair.map constant(List.tabulate(length constants,fn i=>i),constants)
        val artifacts=ForeignGenerate.emit {policy=policy,profile=profile,declarations=declarations,macros= #macros preprocessed,
          layouts=layouts,fields=fields,constants=values,sourceName=sourceName}
        val dependencies=List.filter(fn path=>path<> #file source)(#dependencies preprocessed)
        val dependencyJson=Json.Object[("schema",Json.int 1),("generator",Json.String "runeffi-1"),
          ("policy",Json.String(hash configText)),("target",Json.String(hash targetText)),
          ("headers",Json.Array(List.map(fn path=>Json.Object[("source",Json.String(sourceName path)),
            ("sha256",Json.String(hash(read path)))])dependencies))]
    in {artifacts=artifacts @ [{path="dependencies.json",text=Json.encodeIndented 2 dependencyJson ^ "\n"}],
      name= #structureName policy} end
  fun package {artifacts,name}=
    let fun artifact path=case List.find(fn a:ForeignGenerate.artifact=> #path a=path)artifacts of
          SOME a=> #text a | NONE=>fail("missing emitted artifact: " ^ path)
        val publicSig=artifact "public_sig.sml"
        val api=hash publicSig
        val apiRoot="api/" ^ api
        val apiFiles=[{path=apiRoot ^ "/public_sig.sml",text=publicSig},
          {path=apiRoot ^ "/virtual.sml",text="structure " ^ name ^ " = _virtual : " ^ String.map Char.toUpper name ^ "\n"}]
        val sourceArtifacts=artifacts
        val build="files raw_sig.sml raw.sml layout_sig.sml layout.sml end\n" ^
          "implements " ^ name ^ " =\n  files public.sml export.sml end\nend\n"
        val sourceArtifacts=sourceArtifacts @ [{path="native.build",text=build},
          {path="export.sml",text="_export structure " ^ name ^ " : " ^ String.map Char.toUpper name ^ " = " ^ name ^ "\n"}]
        val revision=hash(String.concat(List.map(fn a:ForeignGenerate.artifact=> #path a ^ ":" ^ hash(#text a) ^ "\n")sourceArtifacts))
        val files=apiFiles @ List.map(fn a:ForeignGenerate.artifact=>{path="sets/" ^ revision ^ "/" ^ #path a,text= #text a})sourceArtifacts
        val pointer="(* Generated by runeffi. Immutable generation: " ^ revision ^ " *)\n" ^
          apiRoot ^ "/public_sig.sml\nuse sets/" ^ revision ^ "/native.build\n" ^ apiRoot ^ "/virtual.sml\n"
    in {files=files,pointer=pointer,revision=revision,api=api} end
  fun checkFile root ({path,text}:ForeignGenerate.artifact)=
    let val file=OS.Path.concat(root,path)
    in if not(exists file) then fail("missing generated file: " ^ file)
       else if read file=text then () else fail("changed or stale generated file: " ^ file) end
  fun check root ({files,pointer,...}:publication)=
    (List.app(checkFile root)files;checkFile root {path="current.build",text=pointer})
  fun publish root {files,pointer,revision,api}=
    let val ()=mkdirs root
        val temporary=unique root
        fun installGroup prefix destination=
          let val selected=List.filter(fn a:ForeignGenerate.artifact=>String.isPrefix(prefix ^ "/")(#path a))files
              val final=OS.Path.concat(root,destination)
              val staged=temporary ^ "/" ^ destination
          in if exists final then List.app(checkFile root)selected else
            (List.app(fn a=>write(temporary ^ "/" ^ #path a,#text a))selected;
             mkdirs(OS.Path.dir final);
             OS.FileSys.rename {old=staged,new=final}
               handle OS.SysErr e=>if exists final then List.app(checkFile root)selected else raise OS.SysErr e) end
        fun work()=
          (installGroup ("api/" ^ api) ("api/" ^ api);
           installGroup ("sets/" ^ revision) ("sets/" ^ revision);
           write(temporary ^ "/current.build",pointer);
           OS.FileSys.rename {old=temporary ^ "/current.build",new=root ^ "/current.build"})
    in (work();removeTree temporary) handle e=>(removeTree temporary handle _=>();raise e) end
  fun diagnostic({file,line,column}:ForeignModel.source,message)=file ^ ":" ^ Int.toString line ^ ":" ^ Int.toString column ^ ": " ^ message
  fun message e=case e of Usage s=>s | ForeignModel.Error p=>diagnostic p | ForeignJson.Error p=>diagnostic p
    | IO.Io{name,function,cause}=>function ^ " " ^ name ^ ": " ^ message cause
    | OS.SysErr(text,_)=>text
    | CLex.Error p=>diagnostic p | CPreprocess.Error p=>diagnostic p | CParse.Error p=>diagnostic p
    | CInteger.Error p=>diagnostic p | CAnalysis.Error p=>diagnostic p | CLayout.Error p=>diagnostic p
    | CLayout.Shim(p,s)=>diagnostic(p,"native C adapter required: " ^ s) | _=>General.exnMessage e
  val usage="usage: runeffi generate|check|inspect --config FILE.ffi --target PROFILE [--out DIR]\n" ^
    "  --include ROOT       search an additional original-header directory\n" ^
    "  --layout TYPE        emit target sizeof, alignment and field offsets\n" ^
    "  --constant NAME      evaluate an original target integer expression\n" ^
    "  --field-get TYPE:PATH emit a typed native field getter\n" ^
    "  --field-set TYPE:PATH emit a typed native field getter and setter\n"
  fun main(_,["--help"])=(print usage;OS.Process.success)
    | main(_,["--version"])=(print "runeffi schema 1\n";OS.Process.success)
    | main(_,arguments)=
    ((let val options=parse arguments val result=inputs options val packaged=package result
          fun output()=case #output options of SOME path=>path | NONE=>fail "missing --out"
      in case #operation options of
          "inspect"=>
            let val manifest=case List.find(fn a:ForeignGenerate.artifact=> #path a="ffi-manifest.json")(#artifacts result) of
                  SOME a=>Json.decode(#text a) | NONE=>fail "missing generation inspection"
                val inspection=Json.Object[("revision",Json.String(#revision packaged)),
                  ("manifest",manifest),("artifacts",Json.Array(List.map(fn a:ForeignGenerate.artifact=>Json.String(#path a))(#files packaged)))]
            in print(Json.encodeIndented 2 inspection ^ "\n") end
        | "check"=>(check(output())packaged;print("PASS runeffi check " ^ #revision packaged ^ "\n"))
        | _=>(publish(output())packaged;print("PASS runeffi generate " ^ #revision packaged ^ "\n"))
      end;OS.Process.success)
      handle e=>(TextIO.output(TextIO.stdErr,"runeffi: " ^ message e ^ "\n");OS.Process.failure))
end
