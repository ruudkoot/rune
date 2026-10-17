let () =
 let cases=["empty",[||];"boundary",[|(0,63,0.0);(64,127,0.5);(128,32767,-0.0);(32768,1048575,0.9999999999999999)|]] in
 List.iter(fun(name,edges)->GenerateSeq.to_file ~filename:("../"^name^".marshal")edges)cases
