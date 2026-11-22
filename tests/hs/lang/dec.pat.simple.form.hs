-- rows: dec.pat.novars dec.pat.recursive dec.pat.guarded dec.pat.guarded.var dec.pat.toplevel
-- Report 4.4.3.2: a pattern binding is lazy, with or without variables; it may be recursive and guarded; at the top level
-- too.
module Main (main) where

(a, b) = undefined :: (Int, Int)

(xs, n) = (1 : xs, 2) :: ([Int], Int)

(p, q) | c = (1, 2) | otherwise = (3, 4) :: (Int, Int)
  where c = True

v | False = 1
  | otherwise = 2 :: Int

main :: IO ()
main = do
  print (let (x, y) = undefined in 1 :: Int, let True = False in 1 :: Int, let (_, _) = undefined in 1 :: Int)
  print (take 2 xs :: [Int], n)
  print ((p, q), v)
