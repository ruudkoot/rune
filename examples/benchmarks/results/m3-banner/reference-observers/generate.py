from pathlib import Path
import ast,json
p=Path(__file__).parent;s=Path('/home/ruud/reference/ghc/nofib/spectral/banner/Main.hs').read_text()
parts={}
parts['digits']=ast.literal_eval(s.split('digits =',1)[1].split('alphas =',1)[0].strip())
parts['alphas']=ast.literal_eval(s.split('alphas =',1)[1].split('-- end of banner',1)[0].strip())
parts['punct']=ast.literal_eval(s.split('punct  =',1)[1].split('digits =',1)[0].strip())
def picture(rows):return 'picture ['+','.join(json.dumps(row)for row in rows)+']'
def table(name,rows):return ' val '+name+'=fontTable '+json.dumps(rows)+'\n'
text=table('alphas',parts['alphas'])+table('digits',parts['digits'])
text+=' val punct=punctTable['+','.join('(#'+json.dumps(c)+','+json.dumps(rows)+')'for c,rows in parts['punct'])+']\n'
text+=' val blank='+picture(['     ']*5)+'\n val slant='+picture(['    ','   ','  ',' ',''])+'\n'
(p/'kernel.sml').write_text((p/'kernel-template.sml').read_text().replace(' TABLES',text))
