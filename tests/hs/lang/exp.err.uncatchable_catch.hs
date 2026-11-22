-- rows: R36
-- Report 3.1: errors cannot be caught by the user: the handler of catch does not run.
module Main (main) where

main :: IO ()
main = catch (error "x") (\_ -> putStrLn "handled")
