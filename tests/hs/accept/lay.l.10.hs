-- rows: lay.note5.def lay.parseerror.let R1
-- Report 9.3, equation 10 and Note 5: an implicit } is inserted before a token t where t is no valid continuation and }
-- is: `let x = e; y = x in e'` is `let { x = e; y = x } in e'` (R1: rhc closes by the grammar's error rule, D27).
module Main (main) where

main :: IO ()
main = print (let x = 1; y = x in y + 1 :: Int, (case 1 of z -> z) :: Int)
