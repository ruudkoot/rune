-- Report 5.1: an abbreviated module is module Main (main) where, so it exports main alone.
import Other

main :: IO ()
main = return ()

x :: Int
x = 1
