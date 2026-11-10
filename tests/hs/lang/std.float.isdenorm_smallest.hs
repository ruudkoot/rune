-- Report 6.4.6: isDenormalized of the smallest denormal of IEEE Double, 2^-1074, is True, and of 1.0 False.
module Main (main) where

main :: IO ()
main = print (isDenormalized (encodeFloat 1 (-1074) :: Double), isDenormalized (1 :: Double), encodeFloat 1 (-1074) > (0 :: Double))
