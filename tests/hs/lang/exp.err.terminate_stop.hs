-- rows: exp.err.error.exit R37
-- Report 3.1: an error, evaluated, ends the program at once: nothing after it runs; chapter 23: as exitFailure.
module Main (main) where

main :: IO ()
main = do
  putStrLn "a"
  error "stop"
  putStrLn "b"
