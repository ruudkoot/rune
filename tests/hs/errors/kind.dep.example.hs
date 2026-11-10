-- Report 4.6: in the Report's example every instance of C has kind *: not C Maybe.
module Main (main) where

data C a => D a = Foo (S a)
type S a = [D a]
class C a where
  bar :: a -> D a -> Bool

instance C Maybe where
  bar _ _ = True

main :: IO ()
main = return ()
