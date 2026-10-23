(* Top-level and one-directory-deep examples retain the existing oracle scope.
   Multi-file applications are compiled through their real .build entrypoint;
   generation-dependent providers have explicit focused host gates. *)
structure ExampleProjects =
struct
  open Sh
  datatype gate = Ordinary | Sdl | NativeWin32
  type project={build:string,libraries:string list,sources:string list,gate:gate}
  val projects : project list =
    [{build="examples/win32/mock.build",libraries=["ffi/win32/mock"],
      sources=["examples/win32/app.sml","examples/win32/mock-main.sml"],gate=Ordinary},
     {build="examples/win32/sdl.build",libraries=["ffi/win32/sdldriver","ffi/win32/model"],
      sources=["examples/win32/app.sml","examples/win32/sdl-main.sml"],gate=Sdl},
     {build="examples/win32/native.build",libraries=["ffi/win32/native"],
      sources=["examples/win32/app.sml","examples/win32/native-main.sml"],gate=NativeWin32},
     {build="examples/sdl/hello.build",libraries=["sdl"],sources=["examples/sdl/hello.sml"],gate=Sdl}]
  fun need(ok,message)=if ok then () else raise Fail("example inventory: " ^ message)
  fun member value values=List.exists(fn other=>other=value)values
  fun paths suffix=glob("examples",suffix) @ List.concat(List.map(fn directory=>glob("examples/" ^ directory,suffix))
    (List.filter(fn directory=>isDir("examples/" ^ directory))(sort(entries "examples"))))
  fun find build=List.find(fn p:project=> #build p=build)projects
  fun name path=OS.Path.concat(OS.Path.dir path,OS.Path.base(OS.Path.file path))
  fun arguments(p:project)=List.concat(List.map(fn library=>["--library",library])(#libraries p)) @ ["--build",#build p]
  fun inventory {sources,builds}=
    let val known=List.map #build projects
        val directories=List.map OS.Path.dir builds
        val fragments=List.concat(List.map #sources projects)
        val ()=List.app(fn build=>need(member build known,"unclassified build entrypoint " ^ build))builds
        val ()=List.app(fn p:project=>
          (need(member (#build p) builds,"missing build entrypoint " ^ #build p);
           List.app(fn source=>need(member source sources,"missing project source " ^ source)) (#sources p)))projects
        val ()=List.app(fn source=>if member(OS.Path.dir source)directories then
          need(member source fragments,"unclassified project fragment " ^ source) else ())sources
        val standalone=List.filter(fn source=>not(member(OS.Path.dir source)directories))sources
        val ordinary=List.map #build(List.filter(fn p:project=> #gate p=Ordinary)projects)
    in {standalone=standalone,ordinary=ordinary,fragments=fragments} end
  fun current()=inventory{sources=paths ".sml",builds=paths ".build"}
  fun programs()=let val {standalone,ordinary,...}=current() in standalone @ ordinary end
  fun audit()=
    let val input={sources=paths ".sml",builds=paths ".build"}
        val {standalone,ordinary,fragments}=inventory input
        fun refused message action=need((action();false)handle Fail _=>true,message)
        val ()=refused "accepted an unclassified fragment"(fn()=>ignore(inventory
          {sources="examples/win32/unclassified.sml":: #sources input,builds= #builds input}))
        val ()=refused "accepted an unclassified project"(fn()=>ignore(inventory
          {sources= #sources input,builds="examples/win32/unclassified.build":: #builds input}))
        val ()=refused "accepted a missing project member"(fn()=>ignore(inventory
          {sources=List.filter(fn path=>path<>"examples/win32/app.sml")(#sources input),builds= #builds input}))
        val ()=need(member "examples/hello.sml" standalone andalso not(member "examples/sdl/hello.sml" standalone),
          "root and SDL hello classification differs")
        val ()=need(member "examples/win32/mock.build" ordinary andalso
          List.all(fn path=>not(member path standalone))fragments,"project fragments are claimed standalone")
        fun description(p:project)= #build p ^ " -> " ^ (case #gate p of Ordinary=>"check-cross/check-positions"
          | Sdl=>"test-sdl-hosts" | NativeWin32=>"test-win32-hosts")
        val ()=List.app(fn project=>say("CLASSIFY " ^ description project ^ "\n"))projects
    in say("PASS example projects: " ^ Int.toString(length standalone) ^ " standalone, " ^
       Int.toString(length ordinary) ^ " ordinary project; fragments and generated-provider gates explicit\n") end
  val requiredHosts=["mlton","smlnj-legacy","smlnj32","smlnj-dev","polyml","mlkit"]
  val hosts=requiredHosts @ ["boot"]
  (* EXECUTE must require successful compilation; equality never accepts two
     missing files or artifacts left over from a preceding run. *)
  fun agreement execute directory (project:project) extra=
    let val base=directory ^ "/" ^ name(#build project)
        val label=OS.Path.file directory ^ "-" ^ String.translate(fn #"/"=>"_" | c=>str c)(name(#build project))
        val ()=mkdirs(OS.Path.dir base)
        fun code host=base ^ "." ^ host ^ ".rbc"
        val ()=List.app(fn host=>
          let val file=code host val ()=rmTree file
              val _=execute(label ^ "-" ^ host)
                (["bin/rune-" ^ host] @ arguments project @ extra @ ["-o",file])
          in need(exists file andalso OS.FileSys.fileSize file>0,"compiler omitted " ^ file) end)hosts
        val reference=code "mlton"
        val ()=List.app(fn host=>need(same(reference,code host),#build project ^ " bytecode differs on " ^ host))hosts
    in say("PASS example host bytecode: " ^ #build project ^ " (all seven compilers)\n") end
end
