-- rows: R3
-- Report 9.3: "Some error conditions are not detected by the algorithm ... for example let }": the grammar
-- refuses it all the same.
module Main (main) where

main :: IO ()
main = print (let } 1)
