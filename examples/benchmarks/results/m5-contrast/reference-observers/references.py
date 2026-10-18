from pathlib import Path
import subprocess,hashlib,json
p=Path(__file__).resolve().parent
results=[]
def ppm(path):
 data=path.read_bytes();pos=0
 def token():
  nonlocal pos
  while True:
   while pos<len(data)and data[pos]in b' \t\r\n':pos+=1
   if data[pos:pos+1]==b'#':
    pos=data.index(b'\n',pos)+1;continue
   end=pos
   while end<len(data)and data[end]not in b' \t\r\n#':end+=1
   value=data[pos:end];pos=end;return value
 assert token()==b'P6';w=int(token());h=int(token());assert token()==b'255'
 assert data[pos]in b' \t\r\n';pos+=1
 raster=data[pos:];assert len(raster)==w*h*3
 assert set(raster)<=set([0,255])
 return w,h,raster
for profile in ['smoke','normal','large']:
 dest=p/'outputs'/profile;dest.mkdir(parents=True,exist_ok=True)
 with(dest/'stdout').open('w')as out,(dest/'stderr').open('w')as err:
  subprocess.run([str((p/'source/original').resolve()),str((p/(profile+'.ppm')).resolve()),str((dest/'result').resolve())],stdout=out,stderr=err,timeout=300,check=True)
 files=sorted(dest.glob('result__*.ppm'));assert len(files)==8
 rows=[]
 for file in files:
  w,h,pixels=ppm(file);name=file.name[len('result__'):-4]
  row=dict(name=name,width=w,height=h,sha256=hashlib.sha256(pixels).hexdigest(),ones=sum(c==255 for c in pixels))
  rows.append(row)
  (dest/(name+'.bits')).write_text(''.join('1'if c else'0'for c in pixels)+'\n')
 if profile=='large':
  original=p/'original-output'
  for file in files:
   other=original/('full'+file.name[len('result'):])
   assert ppm(file)==ppm(other),(file,other)
 results.append(dict(profile=profile,outputs=rows))
 print('PASS',profile,'eight full original binary rasters;',('P3/P6 pixel-identical'if profile=='large'else'fixed crop'),flush=True)
(p/'reference-results.json').write_text(json.dumps(results,indent=2)+'\n')
