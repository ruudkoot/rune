-- Report 7.1 (readings.md R84): readFile reads on demand; rhc's policy is that the head of a file costs what the head
-- needs. io.readfile.lazy.budget: writing a file of n lines and reading its first line costs little more than
-- writing it alone.
module Main (main) where

main :: IO ()
main = do
  [n, how] <- fmap words getLine
  writeFile "big.txt" (concat (replicate (read n) "0123456789\n"))
  if how == "read" then readFile "big.txt" >>= putStrLn . takeWhile (/= '\n') else putStrLn "0123456789"
