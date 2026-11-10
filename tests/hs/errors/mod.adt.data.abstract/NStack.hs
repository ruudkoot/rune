module NStack (StkType, push, pop, empty) where

newtype StkType a = Stk [a]

push x (Stk s) = Stk (x : s)
pop (Stk (_ : s)) = Stk s
empty = Stk []
