-- rows: std.seq.val std.seq.whnf std.seq.anytype std.seq.lambda std.seq.partial std.apply.lazy std.apply.fixity std.apply.section R35
-- Report 6.2: functions are non-strict; seq evaluates its first argument to weak head normal form: a tuple, a cons, a lambda
-- or a partial application is already one; $ is lazy and infixr 0.
module Main (main) where

main :: IO ()
main = do
  print (const 1 (undefined :: Int) :: Int, seq (1 :: Int) (2 :: Int), seq (undefined :: Int, undefined :: Int) (1 :: Int), seq [undefined :: Int] (1 :: Int), seq id (1 :: Int))
  print (seq (\x -> (undefined :: Int)) (1 :: Int), seq (flip undefined :: Int -> Int -> Int) (1 :: Int), seq (const undefined :: Int -> Int) (1 :: Int), const 1 $ (undefined :: Int) :: Int)
  print (negate $ abs $ subtract 5 2 :: Int, map ($ 3) [(+ 1), (* 2)] :: [Int])
