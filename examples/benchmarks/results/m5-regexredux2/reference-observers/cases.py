from pathlib import Path
import subprocess,resource,json
p=Path(__file__).resolve().parent;d=p/'source';out=p/'cases';out.mkdir(exist_ok=True)
(d/'Observer.ml').write_text('''let read path = let ic=open_in_bin path in let s=really_input_string ic(in_channel_length ic)in close_in ic;s
let () =
 let mode=Sys.argv.(1) in let pattern=read Sys.argv.(2) in let input=read Sys.argv.(3) in
 if mode="replace" then print_string(Str.global_replace(Str.regexp pattern)(read Sys.argv.(4))input)
 else if mode="count" then begin
  let regex=Str.regexp_case_fold pattern in let i=ref 0 in let count=ref 0 in
  (try while true do i:=1+Str.search_forward regex input !i;incr count done with Not_found->());
  print_endline(string_of_int !count)
 end else begin
  try let start=Str.search_forward(Str.regexp pattern)input 0 in
    Printf.printf "%d %d\\n" start(Str.match_end())
  with Not_found->print_endline "none"
 end
''')
with(d/'observer-build.log').open('w')as f:subprocess.run(['ocamlopt','str.cmxa','Observer.ml','-o','observer'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
specs=[('overlap','count','aaa','aaaaa',''),('alternative-left','search','ab\\|a','ab',''),('alternative-right','search','a\\|ab','ab',''),('greedy','search','a.*b','axbyb\nab',''),('backtracking','search','a.*ab','aabab',''),('line-anchors','replace','^>.*$\\|\n','>one\nABC\n>two\r\nXY\n',''),('tags','replace','<[^>]*>','<a><b>p<x>','|'),('pipes','replace','|[^|][^|]*|','||a|xy|||x|','-'),('folded-class','count','[acg]t\\|aa','ATctGtAAaa',''),('class-exclusion','search','<[^>]*>','<a>b>',''),('no-match','search','abc','Abc',''),('finish-eof','search','^>.*$','>final','')]
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
records=[]
for name,mode,pattern,input,replacement in specs:
 for suffix,text in [('pattern',pattern),('input',input),('replacement',replacement)]: (out/(name+'.'+suffix)).write_text(text)
 r=subprocess.run([str(d/'observer'),mode,str(out/(name+'.pattern')),str(out/(name+'.input')),str(out/(name+'.replacement'))],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
 (out/(name+'.output')).write_bytes(r.stdout);records.append(dict(name=name,mode=mode));print(name,r.stdout.decode().strip(),flush=True)
for name,input in [('empty',''),('mixed-case','>x\nagggtaaaAGGGTAAA\ntHaNtHataNDcaNHaDSWaSaNSBY\n'),('adjacent-tags','>head\ntHaNtHaNBYaNSWaStttaccct\n'),('unterminated-header','>nothing follows'),('overlapping-motifs','agggtaaagggtaa\ntttaccctttaccct\n')]:
 (out/(name+'.fasta')).write_text(input);(d/'input5000000.txt').write_text(input)
 r=subprocess.run([str(d/'original')],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
 (out/(name+'.result')).write_bytes(r.stdout);print('program',name,len(r.stdout),flush=True)
(p/'case-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
