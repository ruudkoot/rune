-- rows: exp.lambda.infixpat.paren
-- Report 3.3: \ p1 ... pn -> e, n >= 1, each pi an apat; \(x:xs)->x is legal.
module Main (main) where

data C = C Int

main :: IO ()
main = print ((\x y -> x + y) 1 2, (\(x, y) -> x + y) (1, 2), (\_ -> 1) (), (\ ~x -> x) 1,
              (\(C x) -> x) (C 1) + (\(x:xs)->x) [1 :: Int])
