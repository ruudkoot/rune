-- Report 3.17.2: a pattern of a single-constructor data type is refutable: (\(D x) -> 0) bottom diverges; only newtype's
-- is not.
module Main (main) where

data D = D Int

main :: IO ()
main = print ((\(D x) -> 0 :: Int) undefined)
