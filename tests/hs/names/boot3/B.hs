module B where
import A
import C
data B = B
b :: A -> B -> C
b = a `seq` c `seq` undefined
