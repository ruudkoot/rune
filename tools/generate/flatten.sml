structure GenerateFlatten =
struct
  open MeasureCommon
  fun structures text =
    let val stack=ref [] : bool list ref val hidden=ref 0 val want=ref false val last=ref "" val result=ref [] : string list ref
        val declarations=["structure","signature","functor","val","fun","type","datatype","exception","open","infix","infixr","nonfix"]
        fun token (t:SmlScan.token)=
          if #kind t<>SmlScan.Identifier then () else
          let val word= #text t
          in if !want then (if List.exists (fn old => old=word) (!result) then () else result:= !result @ [word];want:=false) else
             (if List.exists (fn s => s=word) ["struct","sig","let","abstype"] then (stack:=true:: !stack;hidden:= !hidden+1)
              else if word="local" then stack:=false:: !stack
              else if word="end" then (case !stack of [] => () | hid::rest => (stack:=rest;if hid then hidden:= !hidden-1 else ()))
              else if (word="structure" orelse word="and") andalso !hidden=0 then want:=(word="structure" orelse !last="structure") else ();
              if List.exists (fn s => s=word) declarations then last:=word else ()) end
    in List.app token (SmlScan.tokens text);!result end
  type frame={id:int,phase:bool ref,start:int,a:string list ref,b:string list ref}
  fun scopes items =
    let val clock=ref 0 val next=ref 0 val frames=ref [] : frame list ref
        val bound=ref [] : (string*int) list ref val result=ref [] : string list ref
        fun add target name=if List.exists (fn old => old=name) (!target) then () else target:=name:: !target
        fun process GenerateMLB.Local=(next:= !next+1;frames:={id= !next,phase=ref false,start= !clock,a=ref [],b=ref []}:: !frames)
          | process GenerateMLB.In=(case !frames of f::_ => #phase f:=true | _ => raise Failed "flat in without local")
          | process (GenerateMLB.File file)=
            (clock:= !clock+1;List.app (fn name =>
                (if List.exists (fn (old,_) => old=name) (!bound) then () else bound:=(name,!clock):: !bound;
                 case !frames of [] => () | f::_ => add (if !(#phase f) then #b f else #a f) name)) (structures (read file)))
          | process GenerateMLB.End=
             (case !frames of [] => raise Failed "flat end without local" | f::rest =>
                (List.app (fn name => let val time= #2 (valOf (List.find (fn (old,_) => old=name) (!bound)))
                    in if time> #start f then () else
                      (result:=("save " ^ Int.toString (#id f) ^ " " ^ name):: !result;
                       if List.exists (fn old => old=name) (!(#b f)) then () else result:=("restore " ^ Int.toString (#id f) ^ " " ^ name):: !result) end) (!(#a f));
                 (case rest of [] => () | parent::_ => List.app (add (if !(#phase parent) then #b parent else #a parent)) (!(#b f)));
                 frames:=rest))
        val ()=List.app process items val ()=need (null (!frames),"unclosed local in flat input")
    in sort (!result) end
  fun readFlat file =List.map (fn line => if String.isPrefix "file " line then GenerateMLB.File (String.extract (line,5,NONE)) else
       case line of "local" => GenerateMLB.Local | "in" => GenerateMLB.In | "end" => GenerateMLB.End | _ => raise Failed ("invalid flat row " ^ line)) (lines (read file))
  fun generate items out basis rewrite =
    let val scope=scopes items val ()=mkdirs out val ()=GenerateText.atomic (out ^ "/scopes") (String.concat (List.map (fn s => s ^ "\n") scope))
        val ()=(rmTree (out ^ "/src");mkdirs (out ^ "/src")) val files=ref [] : string list ref val next=ref 0 val stack=ref [] : int list ref val count=ref 0
        fun emit name text=(count:= !count+1;let val path=out ^ "/src/" ^ StringCvt.padLeft #"0" 4 (Int.toString (!count)) ^ "-" ^ name ^ ".sml"
                 in GenerateText.atomic path text;files:= !files @ [path] end)
        fun rows kind id=List.mapPartial (fn row => case String.tokens Char.isSpace row of [k,n,name] => if k=kind andalso integer n=id then SOME name else NONE | _ => NONE) scope
        fun process GenerateMLB.Local=
               (next:= !next+1;stack:= !next:: !stack;let val names=rows "save" (!next)
                 in if null names then () else emit ("xc2-save-" ^ Int.toString (!next)) (String.concat (List.map (fn name => "structure XC2Save" ^ Int.toString (!next) ^ "_" ^ name ^ " = " ^ name ^ "\n") names)) end)
          | process GenerateMLB.In=()
          | process GenerateMLB.End=(case !stack of [] => raise Failed "unbalanced flat end" | id::rest =>
               (stack:=rest;let val names=rows "restore" id in if null names then () else emit ("xc2-restore-" ^ Int.toString id) (String.concat (List.map (fn name => "structure " ^ name ^ " = XC2Save" ^ Int.toString id ^ "_" ^ name ^ "\n") names)) end))
          | process (GenerateMLB.File path)=
               let val relative=if String.isPrefix (basis ^ "/") path then String.extract (path,size basis+1,NONE) else path
               in emit (OS.Path.base (OS.Path.file path)) ("(* " ^ relative ^ " *) " ^ rewrite path) end
        val ()=List.app process items
    in GenerateText.atomic (out ^ "/files") (String.concat (List.map (fn f => f ^ "\n") (!files)));!files end
  fun top args=(List.app (fn file => List.app (fn name => say (name ^ "\n")) (structures (read file))) args;0)
  fun trimLib (out::files) =
    let val ()=rmTree (out ^ "/lib") val ()=mkdirs (out ^ "/lib/basis")
        val result=execute root (out ^ "/basis-deps") (tool "RUNE" (fromRoot "bin/rune") @ ["--lib","lib","--allow-prim","--basis-deps"] @ files)
        val listing=successful result val keep=lines listing val ()=GenerateText.atomic (out ^ "/lib.files") listing
        fun retained line=String.isPrefix "#" line orelse trim line="" orelse List.exists (fn name => name=trim (hd (fields #"|" line))) keep
        val manifest=String.fields (fn c => c = #"\n") (read (fromRoot "lib/basis/MANIFEST"))
        val manifest=if List.last manifest="" then List.take (manifest,length manifest-1) else manifest
        val ()=GenerateText.atomic (out ^ "/lib/basis/MANIFEST") (String.concat (List.map (fn line => line ^ "\n") (List.filter retained manifest)))
    in List.app (fn file => copy (fromRoot ("lib/basis/" ^ file)) (out ^ "/lib/basis/" ^ file)) keep;0 end
    | trimLib _=raise Usage "trim-lib OUTDIR FILE..."
end
