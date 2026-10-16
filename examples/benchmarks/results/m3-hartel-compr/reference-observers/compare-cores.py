from pathlib import Path
import hashlib,json,difflib
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel'
a=(up/'listcompr/Main.hs').read_text();b=(up/'listcopy/Main.hs').read_text()
(p/'source-variants.diff').write_text(''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile='listcompr/Main.hs',tofile='listcopy/Main.hs')))
b=b.replace('module Main (main) -- listcopy','module Main (main) -- listcompr',1)
lines=b.splitlines(True);selected=[]
for line in lines:
 if line.startswith(('    f_copy []=', '    f_copy (', '    f_nlines ')):continue
 if line.startswith('    f_benchmark_main '):
  assert 'f_copy (f_sp' in line
  line='    f_benchmark_main a_n=f_sp (f_tp (f_concat (f_take a_n (f_repeat c_prg))));\n'
 selected.append(line)
b=''.join(selected);assert a==b
(p/'core-equality-final.json').write_text(json.dumps({'scope':'whole source comparison after exactly the attached benchmark label/copy/unused line-counter differences','normalized_sha256':hashlib.sha256(a.encode()).hexdigest(),'listcompr_source_sha256':hashlib.sha256((up/'listcompr/Main.hs').read_bytes()).hexdigest(),'listcopy_source_sha256':hashlib.sha256((up/'listcopy/Main.hs').read_bytes()).hexdigest()},indent=2)+'\n')
print('PASS whole-source reviewed variant comparison')
