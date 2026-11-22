-- Report 4.5.4: that signature forces x to Int, so not at Bool.
module Main (main) where

f x = let { g :: Int -> b -> ([Int], b) ; g y z = ([x, y], z) } in g 1 True

y :: ([Int], Bool)
y = f True

main :: IO ()
main = return ()
