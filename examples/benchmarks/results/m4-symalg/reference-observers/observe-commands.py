from pathlib import Path
import subprocess,json,resource
p=Path(__file__).resolve().parent
script=['?','',"$a = '2+3",'$a','$a = $a+1','env','2+3*4','(2+3)*4','2^3','real(1)/3','rat(real(1)/3)','0.1','x+y','foo(2,3,4)','2==2','2<3','real(2)>1','2>=3','3/2','-3+4','-3/2','!invalid','$a =','2 +','clear','env','exit']
(p/'commands.stdin').write_text('\n'.join(script)+'\n')
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
r=subprocess.run([str(p/'source/original')],input=(p/'commands.stdin').read_bytes(),capture_output=True,check=True,timeout=60,preexec_fn=cap)
(p/'commands.stdout').write_bytes(r.stdout);(p/'commands.stderr').write_bytes(r.stderr)
print('Observed',len(script),'source command paths and complete transcript')
