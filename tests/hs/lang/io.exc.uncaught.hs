-- rows: R37
-- Report 7.3: an exception leaving the main program ends it, after its IOError is printed; chapter 23: as exitFailure.
module Main (main) where

main :: IO ()
main = do
  putStrLn "before"
  ioError (userError "boom")
  putStrLn "after"
