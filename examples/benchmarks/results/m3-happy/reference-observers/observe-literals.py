from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;o=p/'literal-observer-source';o.mkdir(exist_ok=True)
helpers=(p/'lexer-observer-source/ObserveLexer.hs').read_text();a=helpers.index('js s=');b=helpers.index('ids=',a)
t='''module Main where
import Data.Char
import Numeric(showHex)
import Data.List(intercalate)
import System.Environment
'''+helpers[a:b]+r'''
main=do
 [mode,path]<-getArgs
 input<-readFile path
 putStrLn(if mode=="string" then
  case reads input::[(String,String)]of []->arr[js"none"];(value,rest):_->arr[js"ok",js(show value),js rest]
  else case reads input::[(Char,String)]of []->arr[js"none"];(value,rest):_->arr[js"ok",js(show value),js rest])
'''
(o/'Main.hs').write_text(t)
cases=[]
for n in list(range(256))+[511,512,1000,65535,65536,1114111]:
 cases +=[('char',"'\\x"+format(n,'x')+"'tail"),('string','"\\x'+format(n,'x')+'"tail')]
for literal in ['""','"a\\n\\t\\r\\b\\f\\v\\a"tail','"\\SO\\&H1"','"\\xC8\\&1"','"\\&\\&"','"a\\ \n \t\\b"','"a\nb"','"\\^?"','"\\^@"','"\\X41"','"\\O101"','"\\SP\\DEL"','"\\1114112"','"\\x110000"','"\\q"','"unterminated','"a\\"b"']:
 cases.append(('string',literal))
for literal in ["'a'","'\\''","'\"'","'\\\\'","'\\&'","''","'ab'","'\n'","'\\^?'","'\\q'","'\\X41'","'\\O101'"]:
 cases.append(('char',literal))
data=p/'literal-data';data.mkdir(exist_ok=True)
with(p/'literal-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','Main.hs','-o','observe-literal'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
records=[]
for index,(mode,text)in enumerate(cases):
 name=str(index)
 (data/(name+'.input')).write_text(text)
 r=subprocess.run([str(o/'observe-literal'),mode,str(data/(name+'.input'))],capture_output=True,check=True,timeout=10)
 json.loads(r.stdout);(data/(name+'.reference')).write_bytes(r.stdout)
 records.append({'name':name,'mode':mode,'input':text})
(p/'literal-cases.json').write_text(json.dumps(records,indent=2)+'\n')
print(len(records),'original literal read/show records')
