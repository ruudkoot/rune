-- Report (14.1): an index given twice to array makes the array undefined at it; base takes the last.
module Main where
import Data.Array
main = print (array (1, 1) [(1, 'a'), (1, 'b')] ! (1 :: Int))
