from pathlib import Path
import subprocess,resource,hashlib,json
r=Path(__file__).resolve().parent
for source,exe in [('Main.hs','original'),('RulesDump.hs','rules-dump')]:
 with(r/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,source],cwd=r,check=True,stdout=log,stderr=subprocess.STDOUT)
rules=json.loads(subprocess.check_output([str(r/'rules-dump')],text=True));assert all(all(32<=ord(c)<127 and c not in '\\"'for c in rule)for rule in rules)
(r/'rules.json').write_text(json.dumps(rules,indent=2)+'\n')
(r/'rules.sml').write_text('(* Exact pinned Rulebasetext.hs strings, including spaces; do not normalize. *)\nstructure BenchBoyerTwoRules =\nstruct\n  val texts = [\n'+',\n'.join('    "'+rule+'"'for rule in rules)+'\n  ]\nend\n')
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(600,600))
meta=[]
for profile,n in [('smoke',1),('fast',60),('normal',600),('large',3000)]:
 result=subprocess.run([str(r/'original'),str(n)],capture_output=True,timeout=615,preexec_fn=bounded);assert result.returncode==0,result.stderr
 assert result.stdout==b'The term is a tautology\n'*n
 if profile in ['fast','normal','large']:
  fixture=r/('boyer2.'+('faststdout'if profile=='fast'else'slowstdout'if profile=='large'else'stdout'));assert result.stdout==fixture.read_bytes()
 (r/(profile+'.output')).write_bytes(result.stdout);meta.append(dict(profile=profile,iterations=n,output_sha256=hashlib.sha256(result.stdout).hexdigest(),comparison='complete original output and every expected theorem result'))
 print('PASS original full output',profile,n,flush=True)
(r/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n');print('Rule strings preserved:',len(rules),flush=True)
