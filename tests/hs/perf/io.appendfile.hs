-- Report 7.1 and 21.2.3: appendFile appends to its file, under the locks of 21.2.3. rhc's policy is that n appends
-- cost n times one: the locks look through the handles open, not through every one the program has made (nofib's
-- maillist appends some 25,000 times, and was quadratic in them). io.appendfile.budget: 2,000 appends cost at most
-- 2.5 times 1,000.
module Main (main) where

main :: IO ()
main = do
  n <- fmap read getLine
  writeFile "log.txt" ""
  mapM_ (\i -> appendFile "log.txt" (show i ++ "\n")) [1 .. n :: Int]
  s <- readFile "log.txt"
  print (length (lines s))
