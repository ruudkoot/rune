-- Polymorphic code that forces, given a newtype (4.2.3: a newtype adds no
-- level, so forcing N x forces x): seq, $! and a strict field, inlined and
-- specialised at -O2 into a case on what the newtype wraps.
module Main where

newtype N = N Int
newtype Age = Age Integer deriving (Show)

data Box a = Box !a

unN :: N -> Int
unN (N x) = x

force :: a -> b -> b
force = seq

main :: IO ()
main = do
  print (seq (N 3) (1 :: Int), unN (N 4))
  print (force (Age 5) "forced", Age 6)
  let b = Box (N 7)
  case b of Box n -> print (unN n)
  print (unN $! N 8)
  print (length (map (\x -> x `seq` x) [N 1, N 2]))
  print (seq (N undefined) "not reached" == "")
