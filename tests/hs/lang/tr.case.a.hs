-- rows: tr.case.b tr.case.c tr.case.d tr.case.d.lazy tr.case.e tr.case.f tr.case.g tr.case.i tr.case.j tr.case.q
-- Report 3.17.3: case and its translation by the rules (a) to (j) and (q), each beside its right-hand side.
module Main (main) where

a1, a2 :: Int -> String
a1 x = case x + 1 of { 2 -> "two"; _ -> "other" }
a2 x = (\v -> case v of { 2 -> "two"; _ -> "other" }) (x + 1)

b1, b2 :: Maybe Int -> String
b1 x = case x of { Just 1 -> "a"; Just _ -> "b"; Nothing -> "c" }
b2 x = case x of { Just 1 -> "a"; _ -> case x of { Just _ -> "b"; _ -> case x of { Nothing -> "c"; _ -> error "No match" } } }

c1, c2 :: (Int, Int) -> String
c1 v = case v of
  (p, q) | d > 0 -> "gt"
         | d < 0 -> "lt"
    where d = p - q
  _ -> "eq"
c2 v = case "eq" of { y -> case v of { (p, q) -> let { d = p - q } in if d > 0 then "gt" else if d < 0 then "lt" else y; _ -> y } }

d1, d2 :: (Int, Int) -> Int
d1 v = case v of { ~(x, y) -> x + 1; _ -> 0 }
d2 v = (\x y -> x + 1) (case v of { (x, y) -> x }) (case v of { (x, y) -> y })

e1, e2 :: Maybe Int -> (Maybe Int, Int)
e1 v = case v of { s@(Just x) -> (s, x); _ -> (Nothing, 0) }
e2 v = case v of { Just x -> (\s -> (s, x)) v; _ -> (Nothing, 0) }

g1, g2 :: (Maybe Int, Bool) -> String
g1 v = case v of { (Just 1, True) -> "x"; _ -> "y" }
g2 v = case v of { (x1, x2) -> case x1 of { Just 1 -> case x2 of { True -> "x"; _ -> "y" }; _ -> "y" }; _ -> "y" }

main :: IO ()
main = do
  print (map a1 [1, 2], map a2 [1, 2])
  print (map b1 [Just 1, Just 2, Nothing], map b2 [Just 1, Just 2, Nothing])
  print (map c1 [(2, 1), (1, 2), (1, 1)], map c2 [(2, 1), (1, 2), (1, 1)])
  print (d1 (1, undefined), d2 (1, undefined))
  print (case undefined :: (Int, Int) of { ~(x, y) -> 1; _ -> 2 :: Int })
  print (e1 (Just 4), e2 (Just 4))
  print (map g1 [(Just 1, True), (Just 1, False), (Nothing, True)], map g2 [(Just 1, True), (Just 1, False), (Nothing, True)])
  print (case undefined :: Int of { _ -> 1; _ -> 2 :: Int })
  print (case 5 :: Int of { x -> x + 1; _ -> 0 }, case 5 :: Int of { x -> x + 1 }, (\x -> x + 1) (5 :: Int))
  print (case Just (5 :: Int) of { Just x -> x + 1; _ -> 0 }, (\x -> x + 1) (5 :: Int))
  print (case (undefined :: Int, 2 :: Int) of (x, y) -> y)
