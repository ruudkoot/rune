-- rows: lex.white.seq lex.delimiter lex.comment.valid lex.white.space lex.white.tab lex.white.newline.lf
-- Report 2.2: program -> {lexeme | whitespace}; whitestuff -> whitechar | comment | ncomment: whitespace of each kind,
-- a space, a tab, a newline, a line comment and a nested comment, delimits lexemes.
module Main (main) where

main :: IO ()
main{- a nested comment between lexemes -}={--}case	1{--}of -- a line comment
  x->print{--}(x	::	Int)
