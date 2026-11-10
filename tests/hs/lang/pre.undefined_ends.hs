-- Report 8: undefined is error "Prelude.undefined": bottom, which ends the program.
module Main (main) where

main :: IO ()
main = do
  putStrLn "before"
  print (undefined :: Bool)
