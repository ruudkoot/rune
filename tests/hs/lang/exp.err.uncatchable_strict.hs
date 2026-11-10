-- rows: R36
-- Report 3.1: errors cannot be caught by the user, raised inside the action catch protects either.
module Main (main) where

main :: IO ()
main = do
  n <- catch (return $! (undefined :: Int)) (\_ -> return 0)
  print n
