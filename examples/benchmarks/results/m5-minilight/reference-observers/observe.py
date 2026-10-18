from pathlib import Path
import shutil,subprocess,json
p=Path(__file__).resolve().parent;d=p/'observer-source';d.mkdir(exist_ok=True)
for file in(p/'source').glob('*.ml'):
 if file.name=='minilight.ml':continue
 shutil.copy(file,d/file.name)
f=d/'image.ml';s=f.read_text();idx=s.rfind('\nend');assert idx>0
s=s[:idx]+'\n method benchmarkPixels = pixels_m\n'+s[idx:];f.write_text(s)
source='''let run profile=
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
   Array.iteri(fun i pixel->Printf.fprintf out "pixel %d %.17g %.17g %.17g\\n"i pixel.(0)pixel.(1)pixel.(2))image#benchmarkPixels;close_out out;
   let out=open_out_bin(path^".first.ppm")in ignore(image#formatted out 0);close_out out
  end
 done;
 let out=open_out_bin(path^".observer.ppm")in ignore(image#formatted out(frames-1));close_out out;
 Printf.printf "profile %s\\nsize %d %d\\n" profile image#width image#height;
 Array.iteri(fun i pixel->Printf.printf "pixel %d %.17g %.17g %.17g\\n"i pixel.(0)pixel.(1)pixel.(2))image#benchmarkPixels;
 let raw=Obj.repr random in let words:int array=Obj.obj(Obj.field raw 0)in let index:int=Obj.obj(Obj.field raw 1)in
 Printf.printf "state %d %s\\n"index(String.concat " "(Array.to_list(Array.map string_of_int words)))
let ()=List.iter run["smoke";"normal";"large"]
'''
(d/'Observer.ml').write_text(source)
files=['vector3f.ml','triangle.ml','spatialIndex.ml','scene.ml','surfacePoint.ml','rayTracer.ml','image.ml','camera.ml','Observer.ml']
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer']+files,cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer'),str(p)],cwd=d,timeout=600);(p/'observations.reference').write_bytes(out)
records=[]
for block in out.decode().split('profile ')[1:]:
 lines=block.splitlines();profile=lines[0];w,h=map(int,lines[1].split()[1:])
 pixels=[list(map(float,line.split()[2:]))for line in lines[2:-1]]
 assert len(pixels)==w*h
 state=list(map(int,lines[-1].split()[1:]));assert len(state)==56
 assert(p/(profile+'.model.observer.ppm')).read_bytes()==(p/(profile+'.model.ppm')).read_bytes()
 first=[list(map(float,line.split()[2:]))for line in(p/(profile+'.model.first.linear')).read_text().splitlines()]
 assert len(first)==w*h
 raw=(p/(profile+'.model.ppm')).read_bytes()
 first_raw=(p/(profile+'.model.first.ppm')).read_bytes()
 assert raw[:-w*h*3]==first_raw[:-w*h*3]
 records.append(dict(profile=profile,width=w,height=h,pixels=pixels,state=state,
  first_pixels=first,header=raw[:-w*h*3].decode(),first_rgb=list(first_raw[-w*h*3:]),final_rgb=list(raw[-w*h*3:])))
 print('PASS',profile,'all original linear RGB accumulations, final random state and unmodified P6 agreement',flush=True)
(p/'observations.json').write_text(json.dumps(records,indent=2)+'\n')
