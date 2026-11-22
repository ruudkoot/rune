-- Report 2.7, the rule for an illegal lexeme where a close brace is legal: then, else and of close implicit blocks.
module Main (main) where

main :: IO ()
main = print (if case x of y -> y then 1 else case x of y -> 2, case case x of y -> y of z -> z)
  where x = True
