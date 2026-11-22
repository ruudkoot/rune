-- rows: R36
-- Report 7.3, 3.1, 1.3: error is no IOError, so catch does not see it: the program ends.
module Main (main) where

main :: IO ()
main = catch (error "x") (\_ -> putStrLn "handled")
