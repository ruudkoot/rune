-- Report 3.14: empty statements are dropped: the do with them is the do without.
module Main (main) where

main :: IO ()
main = do
  do {;putStr "a";; putStr "b";}
  putStrLn ""
  do { putStr "a"; putStr "b" }
  putStrLn ""
