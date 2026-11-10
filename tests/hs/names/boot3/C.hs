module C where
import A
import B
data C = C
c :: A -> B -> C
c = a `seq` b `seq` undefined
