(* Deterministic opaque variable rows preserve the source NOINLINE input list. *)
structure BoyerProfileInputs =
struct
 val _=if(OS.FileSys.isDir "data"handle OS.SysErr _=>false)then()else OS.FileSys.mkDir "data"
 fun write(name,count)=
  let val output=TextIO.openOut("data/"^name^".variables")
      val _=TextIO.output(output,"100\n")
      val row=String.concat(List.tabulate(count,fn i=>if i=0 then "X"else " X"))^"\n"
      fun loop 0=()|loop n=(TextIO.output(output,row);loop(n-1))
      val _=loop 100
  in TextIO.closeOut output end
 val _=List.app write[("smoke",2),("normal",15),("large",75)]
end
