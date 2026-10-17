functor PicPlainPairFn(S:sig type t val left:t val right:t end) =
struct
 datatype pair=Pair of S.t*S.t
 val pair=Pair(S.left,S.right)
 fun read(Pair(x,y))=(x,y)
end
structure K=PicPlainPairFn(struct type t=real val left=1.25 val right=2.5 end)
structure PicPlainPairProbe =
struct
 val K.Pair(x,y)=K.pair
 val _=print("DETAIL first-order "^Real.toString x^" "^Real.toString y^"\n")
 val _=T.check("pic-plain-pair/external",fn()=>Real.==(x,1.25)andalso Real.==(y,2.5))
end
