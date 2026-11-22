-- Report 4.5.3: where no instance reduces a constraint, a static error: == on functions.
module Main (main) where

f x = [x] == [id]

main :: IO ()
main = return ()
