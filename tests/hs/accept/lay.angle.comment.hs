-- Report 9.3: "Where the start of a lexeme is preceded only by white space on the same line, this lexeme is preceded by
-- <n>", and white space holds comments: the column of x below is its own, not the comment's.
module Main (main) where

main :: IO ()
main = print (x + y)
  where
    y = 1 :: Int
{--}x = 2

x :: Int
x = 5
