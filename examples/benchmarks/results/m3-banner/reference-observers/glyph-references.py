from pathlib import Path
import subprocess,json
p=Path(__file__).parent
cases=[('alphabet','ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n'),('digits','0123456789\n'),('punctuation','.?!-+:; /\\\n'),('whitespace',' \t\r\v\f\n'),('empty','\n'),('mixed','Hello.\nIs this not a great banner?\n')]
for name,text in cases:
 result=subprocess.run([str(p/'original')],input=text.encode(),capture_output=True,check=True,timeout=30)
 (p/(name+'.input')).write_bytes(text.encode());(p/(name+'.output')).write_bytes(result.stdout)
 print('PASS original glyph fixture',name,len(result.stdout),flush=True)
(p/'glyph-cases.json').write_text(json.dumps(cases)+'\n')
