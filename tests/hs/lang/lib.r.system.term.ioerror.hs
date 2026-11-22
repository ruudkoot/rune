-- Report 23, 7.3: an uncaught IOError ends the program with a status that is not 0.
module Main (main) where

main :: IO ()
main = do
  putStrLn "before"
  ioError (userError "boom")
