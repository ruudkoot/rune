-- rows: pre.even pre.odd pre.gcd pre.lcm pre.caret pre.caretcaret pre.fromintegral pre.realtofrac pre.sequence pre.sequenceu pre.mapm pre.mapmu pre.eqltlt.def pre.id pre.const pre.dot pre.flip pre.seq pre.dollar pre.dollarbang pre.ampamp.def pre.not pre.otherwise pre.maybe pre.either pre.fst pre.snd pre.curry pre.uncurry pre.until pre.astypeof
-- Report 8 (Prelude): each function against the Report's own definition, copied under a new name, on samples and on
-- partial values that show how lazy the definition is.
module Main (main) where

subtract' :: (Num a) => a -> a -> a
subtract' = flip (-)

even', odd' :: (Integral a) => a -> Bool
even' n = n `rem` 2 == 0
odd' = not . even'

gcd' :: (Integral a) => a -> a -> a
gcd' 0 0 = error "Prelude.gcd: gcd 0 0 is undefined"
gcd' x y = gcd'' (abs x) (abs y)
  where gcd'' x 0 = x
        gcd'' x y = gcd'' y (x `rem` y)

lcm' :: (Integral a) => a -> a -> a
lcm' _ 0 = 0
lcm' 0 _ = 0
lcm' x y = abs ((x `quot` (gcd' x y)) * y)

pow :: (Num a, Integral b) => a -> b -> a
pow x 0 = 1
pow x n | n > 0 = f x (n - 1) x
  where f _ 0 y = y
        f x n y = g x n
          where g x n | even n = g (x * x) (n `quot` 2)
                      | otherwise = f x (n - 1) (x * y)
pow _ _ = error "Prelude.^: negative exponent"

powf :: (Fractional a, Integral b) => a -> b -> a
powf x n = if n >= 0 then pow x n else recip (pow x (- n))

fromIntegral' :: (Integral a, Num b) => a -> b
fromIntegral' = fromInteger . toInteger

realToFrac' :: (Real a, Fractional b) => a -> b
realToFrac' = fromRational . toRational

sequence' :: (Monad m) => [m a] -> m [a]
sequence' = foldr mcons (return [])
  where mcons p q = p >>= \x -> q >>= \y -> return (x : y)

sequence_' :: (Monad m) => [m a] -> m ()
sequence_' = foldr (>>) (return ())

mapM' :: (Monad m) => (a -> m b) -> [a] -> m [b]
mapM' f as = sequence' (map f as)

mapM_' :: (Monad m) => (a -> m b) -> [a] -> m ()
mapM_' f as = sequence_' (map f as)

bindr :: (Monad m) => (a -> m b) -> m a -> m b
bindr f x = x >>= f

id' :: a -> a
id' x = x

const' :: a -> b -> a
const' x _ = x

dot :: (b -> c) -> (a -> b) -> a -> c
dot f g = \x -> f (g x)

flip' :: (a -> b -> c) -> b -> a -> c
flip' f x y = f y x

strictApply :: (a -> b) -> a -> b
strictApply f x = x `seq` f x

apply :: (a -> b) -> a -> b
apply f x = f x

and2, or2 :: Bool -> Bool -> Bool
and2 True x = x
and2 False _ = False
or2 True _ = True
or2 False x = x

not' :: Bool -> Bool
not' True = False
not' False = True

otherwise' :: Bool
otherwise' = True

maybe' :: b -> (a -> b) -> Maybe a -> b
maybe' n f Nothing = n
maybe' n f (Just x) = f x

either' :: (a -> c) -> (b -> c) -> Either a b -> c
either' f g (Left x) = f x
either' f g (Right y) = g y

fst' :: (a, b) -> a
fst' (x, _) = x

snd' :: (a, b) -> b
snd' (_, y) = y

curry' :: ((a, b) -> c) -> a -> b -> c
curry' f x y = f (x, y)

uncurry' :: (a -> b -> c) -> ((a, b) -> c)
uncurry' f p = f (fst p) (snd p)

until' :: (a -> Bool) -> (a -> a) -> a -> a
until' p f x = if p x then x else until' p f (f x)

asTypeOf' :: a -> a -> a
asTypeOf' = const

k :: Int -> Maybe Int
k x = if x > 0 then Just x else Nothing

u :: Int
u = undefined

main :: IO ()
main = do
  print (subtract 3 10 == subtract' 3 (10 :: Int))
  print (map even [-3, -2, 0, 7 :: Int] == map even' [-3, -2, 0, 7 :: Int])
  print (map odd [-3, -2, 0, 7 :: Integer] == map odd' [-3, -2, 0, 7 :: Integer])
  print ([gcd a b | a <- [12, -12, 0], b <- [18, -18, 5 :: Int]] == [gcd' a b | a <- [12, -12, 0], b <- [18, -18, 5 :: Int]])
  print ([lcm a b | a <- [4, -4, 0], b <- [6, -6, 0 :: Int]] == [lcm' a b | a <- [4, -4, 0], b <- [6, -6, 0 :: Int]])
  print (lcm u 0 == lcm' u 0)
  print ([2 ^ n | n <- [0 .. 10 :: Int]] == ([pow 2 n | n <- [0 .. 10 :: Int]] :: [Integer]))
  print ((u ^ (0 :: Int)) == pow u (0 :: Int))
  print ([2 ^^ n | n <- [-3 .. 3 :: Int]] == ([powf 2 n | n <- [-3 .. 3 :: Int]] :: [Double]))
  print ((fromIntegral (7 :: Int) :: Double) == fromIntegral' (7 :: Int))
  print ((realToFrac (2.5 :: Float) :: Double) == realToFrac' (2.5 :: Float))
  print ((sequence [Just 1, Just 2], sequence [[1, 2], [3 :: Int]]) == (sequence' [Just 1, Just (2 :: Int)], sequence' [[1, 2], [3 :: Int]]))
  print ((sequence_ [Just 1, Nothing], mapM k [1, 2], mapM k [1, 0], mapM_ k [1, 2]) == (sequence_' [Just (1 :: Int), Nothing], mapM' k [1, 2], mapM' k [1, 0], mapM_' k [1, 2]))
  print ((k =<< Just 5) == bindr k (Just 5))
  print ((id 3, const 1 u, ((+ 1) . (* 2)) 5, flip (-) 1 10) == (id' (3 :: Int), const' (1 :: Int) u, dot (+ 1) (* 2) (5 :: Int), flip' (-) 1 (10 :: Int)))
  print ((flip const u 2, seq (Just u) 1) == (flip' const' u (2 :: Int), seq (Just u) (1 :: Int)))
  print ((negate $ 3, negate $! 3) == (apply negate (3 :: Int), strictApply negate (3 :: Int)))
  print ((const 1 $ u) == apply (const (1 :: Int)) u)
  print ([(a && b, a || b) | a <- [False, True], b <- [False, True]] == [(and2 a b, or2 a b) | a <- [False, True], b <- [False, True]])
  print ((False && undefined, True || undefined) == (and2 False undefined, or2 True undefined))
  print ((map not [False, True], otherwise) == (map not' [False, True], otherwise'))
  print ((maybe 0 (+ 1) (Just 5), maybe 0 (+ 1) Nothing, maybe 0 (const 1) (Just u)) == (maybe' 0 (+ 1) (Just (5 :: Int)), maybe' 0 (+ 1) Nothing, maybe' (0 :: Int) (const 1) (Just u)))
  print ((either (+ 1) length (Left 3), either (+ 1) length (Right "ab"), either (const 1) (const 2) (Left u)) == (either' (+ 1) length (Left (3 :: Int)), either' (+ 1) length (Right "ab"), either' (const (1 :: Int)) (const 2) (Left u :: Either Int Int)))
  print ((fst (1, u), snd (u, 2)) == (fst' (1 :: Int, u), snd' (u, 2 :: Int)))
  print ((curry fst 1 u, uncurry (+) (3, 4), uncurry (\_ _ -> 1) undefined) == (curry' fst' (1 :: Int) u, uncurry' (+) (3, 4 :: Int), uncurry' (\_ _ -> 1 :: Int) (undefined :: (Int, Int))))
  print (until (> 100) (* 2) 1 == until' (> 100) (* 2) (1 :: Int))
  print (asTypeOf 1 (2 :: Int) == asTypeOf' 1 (2 :: Int))
