-- A newtype's constructor in a pattern forces nothing (3.17.2; rules (k), (l)); its field's selector unwraps.
module Main (main) where

newtype N = N Int
newtype W a = W a
newtype Age = Age { unAge :: Int }

constN :: N -> Int
constN (N _) = 1

firstW :: W (Int, Int) -> Int
firstW (W (a, _)) = a

grow :: Age -> Age
grow a = a { unAge = unAge a + 1 }

main :: IO ()
main = do
  print (constN undefined)
  print (case undefined of N _ -> (2 :: Int))
  print (firstW (W (5, undefined)))
  print (unAge (grow (Age 41)))
