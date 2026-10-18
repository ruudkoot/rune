from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'total-diagnostics/packing-control';d.mkdir(exist_ok=True)
text=r'''fun hex v=String.concat(List.tabulate(Word8Vector.length v,fn i=>
 let val s=Word8.fmt StringCvt.HEX(Word8Vector.sub(v,i))in if size s=1 then"0"^s else s end))
val big=Word8Vector.fromList[0w63,0w240,0w0,0w0,0w0,0w0,0w0,0w0]
val _=print("BIG-FLAG\t"^Bool.toString PackReal64Big.isBigEndian^"\n")
val _=print("BIG-BYTES-ONE\t"^hex(PackReal64Big.toBytes 1.0)^"\n")
val _=print("LITTLE-BYTES-ONE\t"^hex(PackReal64Little.toBytes 1.0)^"\n")
val _=print("BIG-FROM-BIG-IS-ONE\t"^Bool.toString(Real.==(PackReal64Big.fromBytes big,1.0))^"\n")
val _=print("BIG-SUB-BIG-IS-ONE\t"^Bool.toString(Real.==(PackReal64Big.subVec(big,0),1.0))^"\n")
'''
(d/'probe.sml').write_text(text);records=[]
for host in ['smlnj32','smlnj-dev','smlnj-legacy']:
 driver=d/(host+'.sml')
 driver.write_text('val _=((use '+json.dumps(str(d/'probe.sml'))+'; OS.Process.exit OS.Process.success) handle e=>OS.Process.exit OS.Process.failure);\n')
 r=subprocess.run(['/home/ruud/.local/rune-hosts/'+host+'/bin/sml',str(driver)],capture_output=True,timeout=30)
 (d/(host+'.stdout')).write_bytes(r.stdout);(d/(host+'.stderr')).write_bytes(r.stderr)
 r.check_returncode()
 rows=[line for line in r.stdout.decode().splitlines()if line.startswith(('BIG-','LITTLE-'))]
 assert len(rows)==5
 records.append(dict(host=host,exit=r.returncode,observations=rows))
 print(records[-1],flush=True)
(d/'observations.json').write_text(json.dumps(records,indent=2)+'\n')
