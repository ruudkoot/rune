let edges=[("match","Novum Site","Novum Site",0);("match","Novum Site","Wrong",0);("match","Novum Site","xNovum Site",1);("match","Novum Site","Novum",0);("partial","Novum Site","Novum",0);("partial","Novum Site","",0);("partial","Novum Site","Novum Site",0);("partial","Novum Site","Novem",0);("partial","Novum Site","xNovum",1);("search","Novum Site","xNovum Site",0);("search","Novum Site","absent",0);("search","Novum Site","Novum Novum Site",1);("search","Novum Site","Novum Site Novum Site",1);("replace","Novum Site","Novum Site / Novum Site",0);("replace","Novum Site","absent",0);("split","@","",0);("split","@","@",0);("split","@","@a",0);("split","@","a@",0);("split","@","a@@b",0);("split","@","@@a@@",0)]
let state()=try Printf.sprintf "%d:%d"(Str.match_beginning())(Str.match_end())with Not_found|Invalid_argument _->"none"
let ()=List.iter(fun(mode,pattern,text,start)->
 let regex=Str.regexp pattern in
 let result=match mode with
 |"match"->let value=Str.string_match regex text start in string_of_bool value^":"^state()
 |"partial"->let value=Str.string_partial_match regex text start in string_of_bool value^":"^state()
 |"search"->(try let _=Str.search_forward regex text start in state()with Not_found|Invalid_argument _->"none")
 |"replace"->Str.global_replace regex "." text
 |"split"->String.concat "|"(Str.split regex text)
 |_ ->failwith"mode"in print_endline result)edges
