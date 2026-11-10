-- Report 4.6: there are no polymorphic kinds: App at * and at * -> *.
module Main (main) where

data App f a = A (f a)

x :: App Maybe Int
x = undefined

y :: App App Maybe
y = undefined

main :: IO ()
main = return ()
