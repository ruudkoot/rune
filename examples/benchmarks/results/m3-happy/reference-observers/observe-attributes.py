from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'attribute-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
helpers=(p/'lexer-observer-source/ObserveLexer.hs').read_text();a=helpers.index('js s=');b=helpers.index('ids=',a)
observer='''module Main where
import AttrGrammar
import AttrGrammarParser
import ParseMonad
import Data.Char
import Numeric(showHex)
import Data.List(intercalate)
import System.Environment
'''+helpers[a:b]+r'''
tag name fields=arr(js name:fields)
tok t=case t of
 AgTok_LBrace->tag"{"[];AgTok_RBrace->tag"}"[];AgTok_Where->tag"where"[];AgTok_Semicolon->tag";"[];AgTok_Eq->tag"="[]
 AgTok_SelfRef s->tag"self"[js s]
 AgTok_SubRef(n,s)->tag"sub"[show n,js s]
 AgTok_RightmostRef s->tag"right"[js s]
 AgTok_Unknown s->tag"unknown"[js s]
 AgTok_EOF->tag"eof"[]
rule r=case r of
 SelfAssign s ts->tag"SelfAssign"[js s,arr(map tok ts)]
 SubAssign(n,s)ts->tag"SubAssign"[show n,js s,arr(map tok ts)]
 RightmostAssign s ts->tag"RightmostAssign"[js s,arr(map tok ts)]
 Conditional ts->tag"Conditional"[arr(map tok ts)]
main=do
 [mode,path]<-getArgs
 s<-readFile path
 putStrLn(if mode=="tokens"then case runP agLexAll s 0 of OkP ts->arr(map tok ts);FailP e->tag"error"[js e]
  else case runP agParser s 0 of OkP rs->arr(map rule rs);FailP e->tag"error"[js e])
'''
(o/'ObserveAttributes.hs').write_text(observer)
cases={'empty':'','whitespace':' \n\t','simple':'$$ = $1',
 'attrs':'$$.value=$1.value + $2; $1.inherited=$$.inherited; where ok $1',
 'right':'$>.a=$$.a; $$=$>',
 'nested':'$$={ x = { y; z }; $1 }; where f $>',
 'embedded-dollar':'$$=abc$>xyz; where xyz$1 + foo$$',
 'where-prefix':'wherever thing',
 'bad-attr':'$$.Upper=$1','dangling-dot':'$$. = $1',
 'trailing-dot':'$$= $1.',
 'underscore-attr':'$$.some_attr=$1',
 'char-quotes':'$$="x;$1"; where $2',
 'empty-values':'$$=; $1=; where',
 'terminal-attrs':'$$=$1.named','right-inside-braces':'$$={ $>; $1 }',
 'two-values':'$$.a=$1; $$.b=$2;',
 'zero':'$0.attr=$0','unknown-dollar':'$$ = $abc + $'}
data=p/'attribute-data';data.mkdir(exist_ok=True)
for name,text in cases.items():(data/(name+'.input')).write_text(text)
with(p/'attribute-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-fforce-recomp','ObserveAttributes.hs','-o','observe-attributes'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
for name in cases:
 for mode in ['tokens','rules']:
  r=subprocess.run([str(o/'observe-attributes'),mode,str(data/(name+'.input'))],capture_output=True,check=True,timeout=30)
  json.loads(r.stdout);(data/(name+'-'+mode+'.reference')).write_bytes(r.stdout)
(p/'attribute-cases.json').write_text(json.dumps(list(cases),indent=2)+'\n')
print(len(cases),'full lexer and attribute-rule observations')
