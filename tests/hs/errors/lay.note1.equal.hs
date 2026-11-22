-- rows: R3
-- Report 9.3, Note 1: n > m, so a do block at the column of the block it is in opens no context (R3: rhc reads n > m
-- strictly, without GHC's NondecreasingIndentation); print 2 belongs to the outer block, and the inner do is empty.
module Main (main) where

main :: IO ()
main = do
  print 1
  id $ do
  print 2
