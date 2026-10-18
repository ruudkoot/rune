from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'lexer-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
f=o/'Lexer.lhs';t=f.read_text();f.write_text('> {-# OPTIONS_GHC -DDEBUG #-}\n'+t)
observer=r'''module Main where
import Lexer
import ParseMonad
import Data.Char
import Numeric(showHex)
import Data.List(intercalate,elemIndex)
import System.Environment
js s="\""++concatMap esc s++"\"" where
 esc '"'="\\\""
 esc '\\'="\\\\"
 esc c | ord c<32="\\u"++replicate(4-length h)'0'++h where h=showHex(ord c)""
 esc c=[c]
arr xs="["++intercalate","xs++"]"
ids=[TokId,TokSpecId_TokenType,TokSpecId_Token,TokSpecId_Name,TokSpecId_Partial,TokSpecId_Lexer,TokSpecId_ImportedIdentity,TokSpecId_Monad,TokSpecId_Nonassoc,TokSpecId_Left,TokSpecId_Right,TokSpecId_Prec,TokSpecId_Expect,TokSpecId_Error,TokSpecId_Attributetype,TokSpecId_Attribute,TokCodeQuote,TokColon,TokSemiColon,TokDoubleColon,TokDoublePercent,TokBar,TokNum]
rank token=case elemIndex token ids of Just i->show i;Nothing->error"id"
emit(token,l)=arr(case token of
 TokenInfo s i->[js"I",rank i,js s,show l]
 TokenNum n i->[js"N",rank i,show n,show l]
 TokenKW i->[js"K",rank i,show l]
 TokenEOF->[js"E",show l])
collect=lexer(\tok->do
 line<-lineP
 case tok of
  TokenEOF->return[(tok,line)]
  _->do rest<-collect;return((tok,line):rest))
main=do
 [path]<-getArgs
 s<-readFile path
 putStrLn(case runP collect s 1 of OkP ts->arr(map emit ts);FailP message->arr[js"error",js message])
'''
(o/'ObserveLexer.hs').write_text(observer)
data=p/'lexer-data';data.mkdir(exist_ok=True)
cases={'default':(p/'source/TestInput.y').read_text(),'empty':'','basic':'%token x { T }\n%%\nr : x { $1 }',
'directives':'%tokentype %token %name %partial %importedidentity %monad %lexer %nonassoc %left %right %prec %expect %error %attributetype %attribute',
'punctuation':': :: ; | %% 1234 abc_x ABC9','comments':'-- before\n{- a {- b -}\n c -}\nname',
'code':'{  f {x} "a}b" \'c\' a\' x  }\nnext',
'quoted-newline':'"a\nb"\nnext','escaped':'"a\\"b" \'\\\'\'',
'unterminated-string':'"abc','unterminated-char':"'abc",'unterminated-comment':'{- x\n',
'unterminated-code':'{ a {b}','unknown-directive':'%unknown abc','directive-prefix':'%tokenz',
'bad-symbol':'?','underscore':'_x','code-trim':'{ \n \t hello \t \n }',
'code-prime':'{ f a\' + b\' }','comment-start-line':'\n{- first\n {- nested\n -}\n'}
for name,text in cases.items():(data/(name+'.input')).write_text(text)
with(p/'lexer-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-fforce-recomp','ObserveLexer.hs','-o','observe-lexer'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
for name in cases:
 r=subprocess.run([str(o/'observe-lexer'),str(data/(name+'.input'))],capture_output=True,check=True,timeout=60)
 json.loads(r.stdout);(data/(name+'.reference')).write_bytes(r.stdout)
 print(name,len(r.stdout),flush=True)
(p/'lexer-cases.json').write_text(json.dumps(list(cases),indent=2)+'\n')
