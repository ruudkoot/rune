-- Report 3.14: the Report's example, do putStr "x: " ; l <- getLine ; return (words l), and its translation, on one input.
module Main (main) where

main :: IO ()
main = do
  r1 <- do { putStr "x: " ; l <- getLine ; return (words l) }
  print r1
  r2 <- putStr "x: " >> getLine >>= \l -> return (words l)
  print r2
