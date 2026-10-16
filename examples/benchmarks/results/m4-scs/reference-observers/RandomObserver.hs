module Main where
import qualified RawRandom
main=mapM_ print [(lo,hi,seed,take 32(RawRandom.random(lo,hi)seed)) | (lo,hi)<-ranges,seed<-seeds]
 where
 b=2147483561
 ranges=[(0,2^30-1),(-7,13),(4,4),(0,b-2),(0,b-1),(0,b),(0,2^100)]
 seeds=[0,345,-345,2^100+12345]
