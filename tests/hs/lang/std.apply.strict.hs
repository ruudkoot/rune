-- Report 6.2: f $! x is x `seq` f x: const 1 $! undefined diverges.
module Main (main) where

main :: IO ()
main = print (const 1 $! (undefined :: Int) :: Int)
