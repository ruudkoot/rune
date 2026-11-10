-- Report 9.5: fbind -> qvar = exp: no wildcard of fields.
module Main (main) where

data R = R { a :: Int }

f :: Int -> R
f a = R {..}

main :: IO ()
main = return ()
