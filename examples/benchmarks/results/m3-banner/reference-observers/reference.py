from pathlib import Path
import subprocess,resource,hashlib,json,ast
p=Path(__file__).parent;up=Path('/home/ruud/reference/ghc/nofib/spectral/banner')
subprocess.run(['ghc','-O2','-outputdir',str(p/'build'),'-o',str(p/'original'),str(up/'Main.hs')],check=True,stdout=(p/'build.log').open('w'),stderr=subprocess.STDOUT)
s=(up/'Main.hs').read_text();letters=ast.literal_eval(s.split('alphas =',1)[1].split('-- end of banner',1)[0]);digits=ast.literal_eval(s.split('digits =',1)[1].split('alphas =',1)[0]);punct=dict(ast.literal_eval(s.split('punct  =',1)[1].split('digits =',1)[0]));slant=['    ','   ','  ',' ','']
def glyph(c):
 if 'A'<=c<='Z':return letters[ord(c)-ord('A')]
 if 'a'<=c<='z':return letters[ord(c)-ord('a')]
 if c.isspace():return ['     ']*5
 if '0'<=c<='9':return digits[ord(c)-ord('0')]
 if c=='/':return slant
 if c=='\\':return slant[::-1]
 if c in punct:return punct[c]
 raise ValueError('infinite fallback outside finite fixture domain')
def say(line):return '\n'+''.join('  '.join(row)+'\n'for row in zip(*(glyph(c)for c in line)))
def render(data):return ''.join(say(line)for line in data.decode('ascii').splitlines()).encode()
template=(up/'banner.stdin.template').read_bytes();expected=(up/'banner.stdout.template').read_bytes();assert render(template)==expected
meta={'source_revision':'b7391df4540ac8b11b35e1b2e2c15819b5171798','ghc':subprocess.check_output(['ghc','--numeric-version']).decode().strip(),'profiles':[]}
with(p/'reference.log').open('w')as log:
 for profile,n,seconds,memory in [('smoke',2,30,1024**3),('fast',3500,600,4*1024**3),('normal',35000,600,4*1024**3),('large',180000,3600,8*1024**3)]:
  def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
  data=template*n;output=expected*n
  result=subprocess.run([str(p/'original')],input=data,capture_output=True,check=True,timeout=seconds,preexec_fn=limits);assert result.stdout==output
  h=0
  for c in output:h=(h*131+c)&0xffffffff
  meta['profiles'].append({'profile':profile,'repetitions':n,'input_bytes':len(data),'output_bytes':len(output),'input_sha256':hashlib.sha256(data).hexdigest(),'output_sha256':hashlib.sha256(output).hexdigest(),'output_hash32':f'{h:X}','timeout':seconds,'memory_bytes':memory})
  print('PASS original GHC, independent renderer and pinned repeated template',profile,n,len(data),len(output),file=log,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
