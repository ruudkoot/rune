from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'grammar-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
helpers=(p/'lexer-observer-source/ObserveLexer.hs').read_text();a=helpers.index('js s=');b=helpers.index('ids=',a)
observer='''module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import Data.Array
import Data.Char
import Numeric(showHex)
import Data.List(intercalate)
import Control.Exception
import System.Environment
'''+helpers[a:b]+r'''
opt f Nothing="null"
opt f(Just x)=f x
ints xs=arr(map show xs)
pair f g(a,b)=arr[f a,g b]
assoc a=case a of LeftAssoc->js"Left";RightAssoc->js"Right";None->js"None"
prio No=arr[js"No"]
prio(Prio a n)=arr[js"Prio",assoc a,show n]
prod(n,rhs,(code,used),priority)=arr[show n,ints rhs,arr[js code,ints used],prio priority]
start(name,n,s,partial)=arr[js name,show n,show s,if partial then"true"else"false"]
emit g=arr[
 arr(map prod(productions g)),
 arr(map(\n->arr[show n,ints(lookupProdsOfName g n)])(non_terminals g)),
 arr(map(pair show js)(token_specs g)),ints(terminals g),ints(non_terminals g),
 arr(map start(starts g)),
 arr(map(pair show(opt js))(assocs(types g))),
 arr(map(pair show js)(assocs(token_names g))),
 show(first_nonterm g),show(first_term g),show(eof_term g),
 arr(map(pair show prio)(priorities g)),
 js(token_type g),if imported_identity g then"true"else"false",
 let(b,a,c,d,e)=monad g in arr[if b then"true"else"false",js a,js c,js d,js e],
 opt show(expect g),arr(map(pair js js)(attributes g)),js(attributetype g),
 opt(pair js js)(lexer g),opt js(error_handler g)]
result s=case runP ourParser s 1 of
 FailP message->arr[js"parse-error",js message]
 OkP ast->case mangler"input.y"ast of
  Failed messages->arr[js"mangle-error",arr(map js messages)]
  Succeeded g->arr[js"grammar",emit g]
main=do
 [path]<-getArgs
 s<-readFile path
 r<-try(evaluate(let x=result s in seq(length x)x))::IO(Either SomeException String)
 putStrLn(case r of Right x->x;Left e->arr[js"exception",js(takeWhile(/='\n')(displayException e))])
'''
(o/'ObserveGrammar.hs').write_text(observer)
data=p/'grammar-data';data.mkdir(exist_ok=True)
basic='%tokentype { T }\n%token x { X }\n%%\nstart : x { $1 }\n'
cases={'default':(p/'source/TestInput.y').read_text(),'basic':basic,
 'precedence':'%tokentype {T}\n%token x {X} plus {P} times {M}\n%left plus\n%left times\n%name parse expr\n%%\nexpr : expr plus expr {$1+$3} | expr times expr {$1*$3} | x {$1}',
 'typed':'%tokentype {T}\n%token x {X}\n%%\nstart :: {A} : x {one}; | {zero}\nnext :: {B} ignored : start {two}',
 'multiple-starts':'%tokentype {T}\n%token x {X}\n%name p a\n%partial q b\n%%\na : x {$1}\nb : a {$1}',
 'unknown-token':'%tokentype {T}\n%token x {X}\n%%\na : missing {$1}',
 'duplicate-name':'%tokentype {T}\n%token x {X}\n%%\na : x {$1}\nb : x {$1}\na : x {$1}',
 'bad-reference':'%tokentype {T}\n%token x {X}\n%%\na : x {$2}',
 'empty-rightmost':'%tokentype {T}\n%token x {X}\n%%\na : {$>}',
 'unknown-precedence':'%tokentype {T}\n%token x {X}\n%%\na : x %prec other {$1}',
 'quote-normalization':'%tokentype {T}\n%token x {X}\n%%\na : x {("\\x41",\'\\x42\',\\$1,$1,$>)}',
 'attributes':'%tokentype {T}\n%token x {X}\n%attributetype {Attrs}\n%attribute value {Int}\n%%\na : x { $$ = $1 }',
 'attribute-groups':'%tokentype {T}\n%token x {X}\n%attribute a {Int}\n%attribute b {Int}\n%%\nstart : child child { $1.a = 1; $1.b = 2; $1.a = 3; $2.a = 4; $$.a = $1.a; where ok $2 }\nchild : x { $$ = $1 }',
 'attribute-rightmost':'%tokentype {T}\n%token x {X}\n%attribute value {Int}\n%%\nstart : x { $$ = $> }',
 'attribute-terminal-name':'%tokentype {T}\n%token x {X}\n%attribute value {Int}\n%%\nstart : x { $$ = $1.named }',
 'attribute-range':'%tokentype {T}\n%token x {X}\n%attribute value {Int}\n%%\nstart : x { $$ = $9 }',
 'attribute-zero':'%tokentype {T}\n%token x {X}\n%attribute value {Int}\n%%\nstart : x { $$ = $0 }',
 'attribute-empty':'%tokentype {T}\n%token x {X}\n%attribute value {Int}\n%%\nstart : x { }',
 'monad-lexer':'%tokentype {T}\n%token x {X}\n%monad {Ctx}{M}{bind}{ret}\n%lexer {lex}{eof}\n%error {bad}\n%expect 0\n%%\na : x {$1}'}
for name,text in cases.items():(data/(name+'.input')).write_text(text)
with(p/'grammar-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-fforce-recomp','ObserveGrammar.hs','-o','observe-grammar'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
for name in cases:
 r=subprocess.run([str(o/'observe-grammar'),str(data/(name+'.input'))],capture_output=True,check=True,timeout=60)
 json.loads(r.stdout);(data/(name+'.reference')).write_bytes(r.stdout)
 print(name,len(r.stdout),flush=True)
(p/'grammar-cases.json').write_text(json.dumps(list(cases),indent=2)+'\n')
