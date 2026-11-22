module Stack (StkType, push, pop, empty) where

data StkType a = EmptyStk | Stk a (StkType a)

push x s = Stk x s
pop (Stk _ s) = s
empty = EmptyStk
