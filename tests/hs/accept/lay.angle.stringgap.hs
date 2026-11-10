-- Report 9.3: a string gap continues its lexeme, so the line of \Bill below begins no lexeme and gets no <n>, though it
-- stands left of the block (the Report's fragment f = ("Hello \ / \Bill", "Jake")).
module Main (main) where

main :: IO ()
main = print f
  where
    f = ("Hello \
  \Bill", "Jake")
