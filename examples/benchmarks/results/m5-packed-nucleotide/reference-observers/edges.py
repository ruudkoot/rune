from pathlib import Path
import subprocess,json,shutil
p=Path(__file__).resolve().parent;old=p.parent/'knucleotide-originals';work=p/'edge-work';work.mkdir(exist_ok=True)
for i in range(8):
 raw=(old/(f'edge-{i}.fasta')).read_bytes();(work/'input25000000.txt').write_bytes(raw);shutil.copy(old/(f'edge-{i}.fasta'),p/(f'edge-{i}.fasta'))
 outputs=[]
 for name in ['knucleotide3','knucleotide3_32']:
  result=subprocess.run([str(p/name)],cwd=work,capture_output=True,timeout=15);assert result.returncode==0,(i,name,result.stderr);outputs.append(result.stdout)
 assert outputs[0]==outputs[1],i
 (p/(f'edge-{i}.output')).write_bytes(outputs[0]);print('PASS full original/threshold edge',i,flush=True)
source=(p/'knucleotide3.ml').read_text();stop=source.rindex('let () =')
observer=source[:stop]+'''let () =
  let t = H15.create 4 in
  for i = 0 to 511 do H15.add t (i * 1048576) {count=1} done;
  let keys = H15.fold (fun key _ xs -> key::xs) t [] in
  print_endline(String.concat " " (List.map string_of_int keys));
  List.iter (fun k -> count k;
    Printf.printf "%d %d %d %d %d\\n" k (H15.length h15) (H16.length h16)
      (H15.fold (fun _ n total -> n.count+total) h15 0)
      (H16.fold (fun _ n total -> n.count+total) h16 0)) [1;2;3;4;6;12;18]
'''
(p/'packed_observer.ml').write_text(observer)
with(p/'packed-observer-build.log').open('w')as log:subprocess.run(['ocamlopt','-O2','-o','packed-observer','packed_observer.ml'],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
shutil.copy(p.parent/'revcomp2-originals/smoke.fasta',work/'input25000000.txt')
raw=subprocess.check_output([str(p/'packed-observer')],cwd=work,timeout=30);(p/'packed-observer.output').write_bytes(raw)
print('Recorded collision/resize traversal and complete pass statistics',flush=True)
