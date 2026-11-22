-- rows: lay.informal.comments lay.informal.continue
-- Report 2.7: "the indentation of the next lexeme (whether or not on a new line) is remembered", the white space before
-- it may hold comments, and a later line with only white space, or indented more, continues the item.
module Main (main) where

main :: IO ()
main = print (a + b + c + d)
  where {- a comment -} a = 1 :: Int
                        b = let
                              x = 2
                            in x

-- a comment at column 1 inside the block inserts nothing
                        c = 3
                          + 4
                        d = 5
