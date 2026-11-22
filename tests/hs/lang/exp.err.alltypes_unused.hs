-- rows: exp.err.lazy
-- Report 3.1: every type has bottom, so undefined may be bound at any type and, unused, does nothing; error "a" bound
-- and never demanded does nothing either.
module Main (main) where

data D = D Int
newtype N = N Int

f :: Int -> Int
f = undefined

d :: D
d = undefined

t :: (Int, Bool)
t = undefined

l :: [Int]
l = undefined

n :: N
n = undefined

i :: Int
i = undefined

main :: IO ()
main = do
  print (let x = error "a" in 1 :: Int)
  putStrLn "done"
