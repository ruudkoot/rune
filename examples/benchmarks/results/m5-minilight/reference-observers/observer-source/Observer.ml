let run profile=
 let path=Sys.argv.(1)^"/"^profile^".model"in
 let input=Scanf.Scanning.from_file path in
 assert(Scanf.bscanf input "%s"((=)"#MiniLight"));
 let frames=Scanf.bscanf input " %u"(max 1)in
 let image=new Image.obj input in
 let camera=new Camera.obj input in
 let scene=new Scene.obj input camera#eyePoint in
 let random=Random.State.make[|1|]in
 for frame=1 to frames do
  ignore(camera#frame scene image random);
  if frame=1 then begin
   let out=open_out(path^".first.linear")in
   Array.iteri(fun i pixel->Printf.fprintf out "pixel %d %.17g %.17g %.17g\n"i pixel.(0)pixel.(1)pixel.(2))image#benchmarkPixels;close_out out;
   let out=open_out_bin(path^".first.ppm")in ignore(image#formatted out 0);close_out out
  end
 done;
 let out=open_out_bin(path^".observer.ppm")in ignore(image#formatted out(frames-1));close_out out;
 Printf.printf "profile %s\nsize %d %d\n" profile image#width image#height;
 Array.iteri(fun i pixel->Printf.printf "pixel %d %.17g %.17g %.17g\n"i pixel.(0)pixel.(1)pixel.(2))image#benchmarkPixels;
 let raw=Obj.repr random in let words:int array=Obj.obj(Obj.field raw 0)in let index:int=Obj.obj(Obj.field raw 1)in
 Printf.printf "state %d %s\n"index(String.concat " "(Array.to_list(Array.map string_of_int words)))
let ()=List.iter run["smoke";"normal";"large"]
