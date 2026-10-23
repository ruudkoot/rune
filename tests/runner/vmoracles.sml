(* Machine-independent count and saved-image oracles shared by portability
   and Windows. Endpoints describe staging; verdict logic has one owner. *)
structure VMOracles =
struct
  open Sh
  exception Failed of string
  type endpoint={name:string,program:string,directory:string,windows:bool,options:string list,environment:string list -> string list}
  fun need (ok,why)=if ok then () else raise Failed why
  fun safe name=String.translate (fn #"/" => "_" | ch => str ch) name
  fun normalized (endpoint : endpoint) text=if #windows endpoint then String.translate (fn #"\r" => "" | ch => str ch) text else text
  fun private tag (endpoint:endpoint) : endpoint =
    let val base= #directory endpoint
        val ()=mkdirs base
        val stem=base ^ "/" ^ tag ^ "-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
        fun reserve n=if n=100 then raise Failed "cannot reserve VM oracle staging" else
          let val path=stem ^ "-" ^ Int.toString n
          in (OS.FileSys.mkDir path;path) handle e as OS.SysErr (_,SOME code) =>
            if code=Posix.Error.exist then reserve (n+1) else raise e end
    in {name= #name endpoint,program= #program endpoint,directory=reserve 0,windows= #windows endpoint,
      options= #options endpoint,environment= #environment endpoint} end
  fun execute logs label (endpoint : endpoint) args =
    let val ()=(mkdirs logs;mkdirs (#directory endpoint))
        val stdout=logs ^ "/" ^ safe label ^ ".out"
        val stderr=logs ^ "/" ^ safe label ^ ".err"
        val status=Children.exec {addressSpace=NONE,cpuTime=NONE,fileSize=SOME (64*1024*1024),core=SOME 0}
             (#environment endpoint o setEnv ("RUNEVM_INTINF","sml") o unsetEnv ["FORCE_COLOR","CLICOLOR_FORCE"])
             {cmd= #program endpoint :: #options endpoint @ args,dir=SOME (#directory endpoint),stdin="",stdout=stdout,stderr=stderr,timeout=900}
    in need (status=0,"VM oracle command failed: " ^ label ^ ": " ^ read stderr);
       (normalized endpoint (read stdout),normalized endpoint (read stderr)) end
  fun countWith staging logs bytecode options endpoints =
    let val endpoints=List.map staging endpoints
        fun one (endpoint : endpoint) =
          let val ()=MatrixLoad.copy (bytecode,#directory endpoint ^ "/prog.rbc")
              val (_,errors)=execute logs ("count-" ^ #name endpoint) endpoint (["--count"] @ options @ ["prog.rbc"])
              val lines=List.filter (String.isPrefix "runevm: count:") (lines errors)
          in need (length lines=1,"missing/duplicate VM counter: " ^ #name endpoint);(#name endpoint,hd lines) end
        val counts=List.map one endpoints
        val ()=need (not (null counts),"no endpoints for count oracle")
        val expected= #2 (hd counts)
    in List.app (fn (name,value) => need (value=expected,"VM counts differ: " ^ name ^ ": " ^ value ^ "; expected " ^ expected)) counts end
  fun count logs bytecode options endpoints=countWith (private "count") logs bytecode options endpoints
  fun images logs bytecode imageName endpoints =
    let val endpoints=List.map (private "image") endpoints
        val ()=List.app (fn endpoint : endpoint =>
              (mkdirs (#directory endpoint ^ "/tests/out");MatrixLoad.copy (bytecode,#directory endpoint ^ "/prog.rbc"))) endpoints
        fun pair (writer : endpoint) (reader : endpoint) =
          if #name writer= #name reader then () else
          let val image= #directory writer ^ "/" ^ imageName
              val ()=rmTree image
              val (out,err)=execute logs ("save-" ^ #name writer ^ "-" ^ #name reader) writer ["prog.rbc"]
              val expected=out ^ err
              val ()=need (expected<>"" andalso exists image,"image writer produced no image/answer: " ^ #name writer)
              val target= #directory reader ^ "/" ^ imageName
              val ()=if OS.Path.mkCanonical image=OS.Path.mkCanonical target then () else MatrixLoad.copy (image,target)
              val (out,err)=execute logs ("restore-" ^ #name writer ^ "-" ^ #name reader) reader ["--restore",imageName]
          in need (out ^ err=expected,"image answer differs: " ^ #name writer ^ " -> " ^ #name reader) end
    in need (length endpoints>=2,"image oracle needs two machines");List.app (fn writer => List.app (pair writer) endpoints) endpoints end
end
