-- Report 4.6: and D has kind * -> *: not D Maybe.
module Main (main) where

data C a => D a = Foo (S a)
type S a = [D a]
class C a where
  bar :: a -> D a -> Bool

x :: D Maybe
x = undefined

main :: IO ()
main = return ()
