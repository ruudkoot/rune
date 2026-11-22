-- rows: dec.ctx.tvarhead dec.ctx.tvarhead.inferred dec.ctx.derive.reducible
-- Report 4.5.3: inferred contexts are reduced to head normal form, Eq a for xs == [y]; C (m t) with m a variable stays;
-- a derived instance whose constituents' constraints reduce to variables has a simple context.
module Main (main) where

f :: Eq a => [a] -> a -> Bool
f xs y = xs == [y]

g :: (Monad m, Eq (m a)) => a -> m a -> Bool
g x y = return x == y

h x y = return x == y

data T a = C [a] (Maybe a) deriving Show

main :: IO ()
main = print (f [1] 1, g 1 (Just 1), h 1 (Just (1 :: Int)), C [1] Nothing)
