-- Report 4.5.5: the usual restriction holds too: the environment's variables stay ungeneralised.
module Main (main) where

f x = let g y = (x, y) in (fst (g ()) && True, fst (g ()) == 'c')

main :: IO ()
main = return ()
