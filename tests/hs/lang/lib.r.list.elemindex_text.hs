-- rows: lib.r.list.elemindices lib.r.list.find lib.r.list.findindex lib.r.list.findindices
-- Report 17.1: elemIndex gives Just the first index or Nothing, elemIndices every index in order, find the first element
-- that satisfies a predicate or Nothing, findIndex its index, findIndices all of them.
module Main (main) where

import List

main :: IO ()
main = do
  print (elemIndex 3 [1, 2, 3, 2, 3 :: Int], elemIndex 9 [1, 2, 3 :: Int], elemIndex 'a' "")
  print (elemIndices 3 [3, 1, 3, 3 :: Int], elemIndices 'z' "abc", take 3 (elemIndices 0 (cycle [0, 1 :: Int])))
  print (find even [1, 3, 4, 6 :: Int], find (> 5) [1, 2 :: Int], find (== 'b') "abcb", find (> 2) [1 :: Int ..])
  print (findIndex even [1, 3, 4, 6 :: Int], findIndex (> 5) [1, 2 :: Int], findIndex (> 2) [1 :: Int ..])
  print (findIndices even [1, 2, 3, 4 :: Int], findIndices (const False) "abc", take 3 (findIndices odd [0 :: Int ..]))
