-- Report 4.1.4: an instantiation whose context does not hold is an error: double at Char.
module Main (main) where

double :: Num a => a -> a
double x = x + x

y :: Char
y = double 'a'

main :: IO ()
main = return ()
