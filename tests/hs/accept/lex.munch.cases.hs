-- rows: lex.munch.rule lex.munch.eqeq lex.munch.tildeeq
-- Report 2.2: maximal munch, "the longest possible lexeme satisfying the lexeme production is read":
-- `cases` is a varid though `case` is reserved; `==` and `~=` are varsyms though `=` and `~` are reserved.
module Main (main) where

main :: IO ()
main = print (cases == 1, cases ~= 2)
  where
    cases :: Int
    cases = 1
    a == b = a - b
    a ~= b = a + b
