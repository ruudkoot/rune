module Main where
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
js s="\""++concatMap esc s++"\"" where
 esc '"'="\\\""
 esc '\\'="\\\\"
 esc c | ord c<32="\\u"++replicate(4-length h)'0'++h where h=showHex(ord c)""
 esc c=[c]
arr xs="["++intercalate","xs++"]"

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
