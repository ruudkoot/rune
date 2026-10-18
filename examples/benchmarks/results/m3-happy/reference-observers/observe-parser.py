from pathlib import Path
import shutil,subprocess,json
p=Path(__file__).resolve().parent;o=p/'parser-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
helpers=(p/'lexer-observer-source/ObserveLexer.hs').read_text()
a=helpers.index('js s=');b=helpers.index('ids=',a)
observer='''module Main where
import Parser
import ParseMonad
import AbsSyn
import Data.Char
import Numeric(showHex)
import Data.List(intercalate)
import System.Environment
'''+helpers[a:b]+r'''
opt f Nothing="null"
opt f(Just x)=f x
tag name fields=arr(js name:fields)
strings xs=arr(map js xs)
pair(a,b)=arr[js a,js b]
directive d=case d of
 TokenType s->tag"TokenType"[js s]
 TokenSpec xs->tag"TokenSpec"[arr(map pair xs)]
 TokenName s start partial->tag"TokenName"[js s,opt js start,if partial then"true"else"false"]
 TokenLexer a b->tag"TokenLexer"[js a,js b]
 TokenImportedIdentity->tag"TokenImportedIdentity"[]
 TokenMonad a b c d->tag"TokenMonad"[js a,js b,js c,js d]
 TokenNonassoc xs->tag"TokenNonassoc"[strings xs]
 TokenRight xs->tag"TokenRight"[strings xs]
 TokenLeft xs->tag"TokenLeft"[strings xs]
 TokenExpect n->tag"TokenExpect"[show n]
 TokenError s->tag"TokenError"[js s]
 TokenAttributetype s->tag"TokenAttributetype"[js s]
 TokenAttribute a b->tag"TokenAttribute"[js a,js b]
rule(names,code,line,priority)=arr[strings names,js code,show line,opt js priority]
production(name,rules,ty)=arr[js name,arr(map rule rules),opt js ty]
emit(AbsSyn header dirs prods footer)=tag"AbsSyn"[opt js header,arr(map directive dirs),arr(map production prods),opt js footer]
main=do
 [path]<-getArgs
 s<-readFile path
 putStrLn(case runP ourParser s 1 of OkP ast->emit ast;FailP message->arr[js"error",js message])
'''
(o/'ObserveParser.hs').write_text(observer)
data=p/'parser-data';data.mkdir(exist_ok=True)
basic='%tokentype { T }\n%token x { X }\n%%\nstart : x { $1 }\n'
cases={'default':(p/'source/TestInput.y').read_text(),'basic':basic,'empty':'',
 'typed':'%token x {X}\n%%\nstart :: {A} : x {one}; | {zero}\nnext :: {B} ignored : start {two}',
 'directives':'{ header }\n%tokentype {T}\n%token x {X} y {Y}\n%name p start\n%partial q\n%importedidentity\n%lexer {lex}{eof}\n%monad {M}\n%monad {C}{M}\n%monad {M}{bind}{ret}\n%monad {C}{M}{bind}{ret}\n%nonassoc x\n%right y\n%left x y\n%expect 3\n%error {bad}\n%attributetype {Attrs}\n%attribute value {Int}\n%%\nstart : x y %prec x {act}; | {empty}\n{ footer }',
 'multiple-rules':'%token x {X}\n%%\na : x {A}\nb : a {B} | x {X}',
 'syntax-error':'%token x {X}\n%%\nstart : x',
 'missing-separator':'%tokentype {T}\nstart : {x}',
 'unknown-directive':'%unknown {x}','unterminated-code':'%token x {',
 'missing-id':'%name\n%%\na : {}','extra-code':basic+'{footer}\nmore'}
for name,text in cases.items():(data/(name+'.input')).write_text(text)
with(p/'parser-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-fforce-recomp','ObserveParser.hs','-o','observe-parser'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
for name in cases:
 r=subprocess.run([str(o/'observe-parser'),str(data/(name+'.input'))],capture_output=True,check=True,timeout=60)
 json.loads(r.stdout);(data/(name+'.reference')).write_bytes(r.stdout)
 print(name,len(r.stdout),flush=True)
(p/'parser-cases.json').write_text(json.dumps(list(cases),indent=2)+'\n')
