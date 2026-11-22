-- Report 6.3.6: fail s at IO raises userError s: catch sees it and isUserError is True.
module Main (main) where

import IO

main :: IO ()
main = catch (do { Just x <- return Nothing; print (x :: Int) }) (\e -> print (isUserError e))
