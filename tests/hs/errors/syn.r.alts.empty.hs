-- rows: R13
-- Report 3.13 and 9.5: "A case expression must have at least one alternative": case x of {} parses and is refused
-- (R13).
module Main (main) where

main :: IO ()
main = print (case 1 of {} :: Int)
