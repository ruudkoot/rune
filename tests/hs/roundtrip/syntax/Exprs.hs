module Exprs where

-- Every form of expression of 3.1 to 3.16, by its production in 9.5.
literals = (0, 123, 0x1F, 0XfF, 0o17, 0O7, 1.5, 1e10, 1.5e-3, 2E+2, 'a', '\n', '\'', "str")
escapes = "\a\b\f\n\r\t\v\\\"\'\& \SOH\SO\&H\DEL\^A\^@\^[\65\x41\o101"
gap = "a string \
      \with a gap"
chars = ['\NUL', '\SP', '\^Z', '\1114111', '"']

lambda = \x y -> x
lambda2 = \(a, b) [c] ~d _ -> a
letin = let x = 1; y = 2 in x + y
letin2 = let { x = 1 } in x
cond c = if c then 1 else 2
caseof x = case x of
  0 -> "zero"
  n | n < 0 -> "negative"
    | otherwise -> "positive"
    where q = n
dos = do
  x <- getLine
  let y = x
      z = y
  putStrLn y
  return ()
tuples = ((), (1, 2), (1, 2, 3), (,) 1 2, (,,) 1 2 3)
lists = ([], [1], [1, 2, 3], [1 ..], [1, 3 ..], [1 .. 10], [1, 3 .. 10])
comprehension = [(x, y) | x <- [1 .. 3], let y = x * x, odd x, (a, b) <- zip [x] [y]]
sections = ((+ 1), (1 +), (`div` 2), (2 `div`), (subtract 1), (- 1), (-), (:), (Exprs.++ []))
negation = - 1 + (- x) * (- y)
  where x = 1
        y = 2
operators = a `div` b `mod` c Exprs.+ d : e : []
  where a = 1; b = 2; c = 3; d = 4; e = 5
applications = f (g x) [y] (z, w) Just Nothing
  where f = undefined; g = id; x = (); y = (); z = (); w = ()
records = (Rec { field = 1 }, r { field = 2 }, (r { field = 3 }) { field = 4 }, Rec {})
  where r = Rec 0
typed = (1 :: Int, (2 :: (Num a) => a), [] :: [()], (\x -> x) :: a -> a)
qualified = (Prelude.map, Prelude.Just, (Prelude.+), (Prelude.:+))
nested = case case 1 of { y -> y } of { z -> if z then do { a } else let { b = 1 } in b }
x ++ y = x
data Rec = Rec { field :: Int }
