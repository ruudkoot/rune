-- Report 9.3: an if in a do block, its then and else indented more than the block, makes no ; and parses.
module Main (main) where

main :: IO ()
main = do
  if True
    then print 1
    else print 2
  return ()
