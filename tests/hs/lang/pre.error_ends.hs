-- Report 8: error s is bottom, which ends the program as 3.1 and chapter 23 say.
module Main (main) where

main :: IO ()
main = do
  putStrLn "before"
  print (error "boom" :: Int)
