-- Report 9.3, equation 2 keeps <n>, so one line may close several contexts and then begin an item: } } ; below.
module Main (main) where

f :: Int -> Int
f x = g x
  where
    g y = h y
      where
        h z = z
g :: Int
g = 1

main :: IO ()
main = print (f g)
