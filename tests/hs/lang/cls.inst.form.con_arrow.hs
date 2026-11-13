-- rows: syn.r.inst.spelled ty.fun.prefix
-- Report 4.3.2, 9.5: an instance's type is a bare gtycon, the function type's (->) of kind *->*->* among them
-- (4.1.2), as GHC's tcrun001 has it; and (->) given one type, ((->) r), at kind *->*. Run, so that the dictionary's
-- type at (->) and at ((->) Int) goes through Core to Mid in every way (ruling 60).
module Main (main) where

class Flob k where
  twice :: k a a -> k a a

instance Flob (->) where
  twice f = f . f

class Apply f where
  apply :: (a -> b) -> f a -> f b

instance Apply ((->) r) where
  apply g h = g . h

main :: IO ()
main = do
  print (twice (+ 1) (40 :: Int))
  print (apply (* 2) (+ 1) (20 :: Int))
