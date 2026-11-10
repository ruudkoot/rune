-- rows: exp.free.then exp.free.fail
-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: do uses the Prelude's >>=, >> and fail, not the module's, which abort.
module Main (main) where

import Prelude hiding ((>>=), (>>), fail)

(>>=) :: Int -> Int -> Int
_ >>= _ = error "own >>="

(>>) :: Int -> Int -> Int
_ >> _ = error "own >>"

fail :: String -> Int
fail _ = error "own fail"

main :: IO ()
main = do
  putStr "a"
  x <- return (1 :: Int)
  print x
  print (do { Just y <- Just Nothing; return (y :: Int) })
