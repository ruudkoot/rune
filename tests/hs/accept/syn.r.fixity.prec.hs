-- rows: R9
-- Report 9.5: gendecl -> fixity [integer] ops, integer the lexeme of 2.5 in any radix: 0x6 is precedence 6.
module Main (main) where

infixl 0x6 +++
(+++) :: Int -> Int -> Int
a +++ b = a - b

main :: IO ()
main = print (10 +++ 2 +++ 3)
