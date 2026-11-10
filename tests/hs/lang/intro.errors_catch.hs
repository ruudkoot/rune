-- rows: R36
-- Report 1.3, 3.1, 7.3 (readings.md R36): catch does not see error: the program ends.
module Main (main) where

main :: IO ()
main = catch (print (error "x" :: Int)) (\_ -> putStrLn "caught")
