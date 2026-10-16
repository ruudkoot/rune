from pathlib import Path
import ast
p=Path(__file__).parent;s=Path('/home/ruud/reference/ghc/nofib/spectral/fish/Main.hs').read_text();tables={}
for name,nextname in [('p_tile','q_tile'),('q_tile','r_tile'),('r_tile','s_tile'),('s_tile','type Line_segment')]:
 tables[name]=ast.literal_eval(s.split(name+' =',1)[1].split(nextname,1)[0].strip())
text='\n'.join(' val '+name+'=Q.fromList['+','.join('('+','.join(map(str,t))+')'for t in values)+']'for name,values in tables.items())
(p/'kernel.sml').write_text((p/'kernel-template.sml').read_text().replace(' TABLES',text))
