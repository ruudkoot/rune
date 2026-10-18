from pathlib import Path
import subprocess,json,re,resource,hashlib
p=Path(__file__).resolve().parent;d=p/'observer-source'
(d/'Observer.hs').write_text('module Main where\nimport CacheMain (doFile)\nimport System.Environment\nmain=do {args<-getArgs; input<-getContents; out<-doFile (read(head args)) [] input; putStr out}\n')
(d/'Metadata.hs').write_text('module Main where\nimport Arch_x86\nmain=mapM_ (\\(opcode,info)->putStrLn(show opcode++"\\t"++show info++"\\t"++show(elem opcode nonJumpyOpcodes))) x86info\n')
for program,module in [('observer','Observer.hs'),('metadata','Metadata.hs')]:
 with(p/(program+'-cases-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',program,module],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
r=subprocess.run([str(d/'metadata')],capture_output=True,check=True,timeout=30,preexec_fn=cap)
(p/'original-architecture.reference').write_bytes(r.stdout)
meta=[line.split('\t')for line in r.stdout.decode().splitlines()];assert len(meta)==206
generated=json.loads((p/'architecture-identities.json').read_text());assert [row[0]for row in meta]==[row[0]for row in generated['table']]
sml=(p/'architecture.sml').read_text();actual=re.findall(r'\bO_\w+\b',sml.split('val nonJumpyOpcodes=[',1)[1].split(']',1)[0]);expected=[row[0]for row in meta if row[2]=='True'];assert set(actual)==set(expected)and len(actual)==len(expected)
print('PASS all206opcode rows and',len(expected),'exact nonJumpy members',flush=True)
cases=[]
for opcode,info,_ in meta:
 name=opcode[2:]
 if info.startswith('OI ['):
  arities=[]
  for effect in re.findall(r'\bOE_\w+',info):
   count={'OE_RR':2,'OE_RM':2,'OE_RW':2,'OE_nW':2,'OE_RRM':3,'OE_R':1,'OE_M':1,'OE_W':1}[effect]
   if count not in arities:arities.append(count)
  choices=[','.join(['(%eax)','4(%ebx)','8(%ecx)'][:count])for count in arities]
 elif info=='OI_Jumpy':choices=['target','*(%eax)','*%eax']
 elif info=='OI_Special':choices=['(%eax)']if name in ['pushl','popl','call']else['']
 else:choices=['']
 for j,operands in enumerate(choices):
  instruction='\t'+name+(' '+operands if operands else'')+'\n'
  if name=='rep':instruction+='\tmovsb\n'
  if name=='repz':instruction+='\tcmpsb\n'
  if name=='repnz':instruction+='\tscasb\n'
  cases.append((name+'-'+str(j),2,'.file "case.c"\n.globl function\nfunction:\n'+instruction))
special=[
 ('empty',''),('labels','top: movl %eax,(%ebx); incl 4(%ecx)\nret\n'),
 ('stabs','.file "guess.c"\nf:\n.stabs "dir/source,file.c",100,0,0,0\n.stabs "fn:F",36,0,0,0\n.stabn 68,0,123,0\nmovl (%eax),%ebx\n'),
 ('peephole','f:\nmovl %eax,(%ebx)\nmovl (%eax),%ebx\nmovl %eax,(%ebx)\n'),
 ('quoted','.stabs "source.c",100,0,0,0\n.stabs "fn:F",36,0,0,0\nmovl (%eax),%ebx\n'),
 ('rep-copy','rep\nmovsb\nrep\nstosl\n'),
 ('rep-compare','repz\ncmpsb\nrepnz\nscasb\n'),
 ('const-address','movl $-3+4*8,(%eax,%ebx,4)\nleal symbol+2(,%ecx,4),%eax\n'),
 ('st-reg','fadd %st(1),%st\n'),
 ('bad-opcode','rune_unknown %eax\n'),('bad-token','movl &,%eax\n'),
 ('bad-arity','movl %eax\n'),('bad-reg','movl %rune,%eax\n'),
 ('comments','# leading\nmovl %eax,%ebx # trailing\n')
]
for name,source in special:
 for level in [0,1,2]:cases.append((name+'-level'+str(level),level,source))
out=p/'cases';out.mkdir(exist_ok=True);records=[]
for i,(name,level,source)in enumerate(cases):
 key=str(i).zfill(3)+'-'+name;(out/(key+'.s')).write_text(source)
 r=subprocess.run([str(d/'observer'),str(level)],input=source.encode(),capture_output=True,timeout=30,preexec_fn=cap)
 (out/(key+'.expected')).write_bytes(r.stdout);(out/(key+'.stderr')).write_bytes(r.stderr)
 records.append(dict(key=key,name=name,level=level,status='pass'if r.returncode==0 else'original-error',exit=r.returncode,bytes=len(r.stdout),sha256=hashlib.sha256(r.stdout).hexdigest()))
(p/'case-results.json').write_text(json.dumps(records,indent=2)+'\n')
print('Original cases',len(records),'passing',sum(x['status']=='pass'for x in records),'rejected',sum(x['status']=='original-error'for x in records),flush=True)
