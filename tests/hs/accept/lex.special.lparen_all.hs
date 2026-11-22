-- rows: lex.special.rparen lex.special.comma lex.special.semi lex.special.lbracket lex.special.rbracket lex.special.backquote lex.special.lbrace lex.special.rbrace
-- Report 2.2: special -> ( | ) | , | ; | [ | ] | ` | { | }: each a lexeme of its own, next to whatever it
-- touches: `(a` and `a)` are two tokens, `a,b` and `a;b` three, `,,` two, `x`div`y` five.
module Main (main) where

main :: IO ()
main = print (f(1)[2],x`div`y,(,,)'a''b''c') where{f a b=a:b;x=7;y=2}
