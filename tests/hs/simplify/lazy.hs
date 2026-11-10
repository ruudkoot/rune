-- What must stay lazy (M23): a binding never forced, a constructor's
-- field never forced, an infinite list, a knot, an error in a branch not
-- taken, and seq where it forces.
module Main where

ones :: [Int]
ones = 1 : ones

fibs :: [Integer]
fibs = 0 : 1 : zipWith (+) fibs (tail fibs)

lazyPair :: (Int, Int)
lazyPair = (1, undefined)

main :: IO ()
main = do
  let x = undefined :: Int
      y = 5 :: Int
  print (const y x)
  print (fst lazyPair, take 3 ones, fibs !! 50)
  print (if y > 3 then 1 else error "not taken" :: Int)
  let xs = map (* 2) [1 ..] :: [Int]
  print (takeWhile (< 20) xs)
  print (length [undefined, undefined :: Int])
  let z = y + 1 in z `seq` print z
  print (snd (undefined :: Int, 7 :: Int))
