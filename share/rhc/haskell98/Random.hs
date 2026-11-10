-- Module Random, section 27 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module Random (
	RandomGen(next, split, genRange),
	StdGen, mkStdGen,
	Random( random,   randomR, 
		randoms,  randomRs,
		randomIO, randomRIO ),
	getStdRandom, getStdGen, setStdGen, newStdGen
  ) where
	
import Char (ord, chr)
import PreludeRuntime (Ref, ref_new, ref_get, ref_set, unsafe_perform_io, random_seed)  -- (rhc's)

---------------- The RandomGen class ------------------------

class RandomGen g where
  genRange :: g -> (Int, Int)
  next     :: g -> (Int, g)
  split    :: g -> (g, g)

  -- Default method (27.1; overlay ov.random.defaults)
  genRange g = (minBound,maxBound)

---------------- A standard instance of RandomGen -----------
-- L'Ecuyer's combined generator (CACM 31, 1988), as the Report's
-- references [2,3] ask, with a range of 31 bits; two seeds, each kept
-- within its modulus (overlay ov.random.stdgen)
data StdGen = StdGen Int Int	-- Abstract

instance RandomGen StdGen where
  genRange _ = (0, 2147483562)
  next (StdGen s1 s2) = (if z < 1 then z + 2147483562 else z, StdGen s1'' s2'')
    where z    = s1'' - s2''
          k    = s1 `quot` 53668
          s1'  = 40014 * (s1 - k * 53668) - k * 12211
          s1'' = if s1' < 0 then s1' + 2147483563 else s1'
          k'   = s2 `quot` 52774
          s2'  = 40692 * (s2 - k' * 52774) - k' * 3791
          s2'' = if s2' < 0 then s2' + 2147483399 else s2'
  split g@(StdGen s1 s2) = (StdGen s1' t2, StdGen t1 s2')
    where s1' = if s1 == 2147483562 then 1 else s1 + 1
          s2' = if s2 == 1 then 2147483398 else s2 - 1
          StdGen t1 t2 = snd (next g)

-- show g is the two seeds; read takes them back, so that read (show g) is
-- g, and reads any other string as a generator made from its first
-- characters (27.1)
instance Read 	   StdGen where
  readsPrec p s = case [(StdGen a b, u) | (a, t) <- readsPrec 11 s, (b, u) <- readsPrec 11 t,
                                          a >= 1, a <= 2147483562, b >= 1, b <= 2147483398] of
                    (x:_) -> [x]
                    []    -> let (cs, rest) = splitAt 6 s
                             in [(mkStdGen (foldl (\a c -> ord c + 3 * a `mod` 1000003) 1 cs), rest)]
instance Show 	   StdGen where
  showsPrec p (StdGen a b) = showsPrec 11 a . showChar ' ' . showsPrec 11 b

mkStdGen :: Int -> StdGen
mkStdGen s = StdGen (fromInteger r + 1) (fromInteger (q `mod` 2147483398) + 1)
  where (q, r) = toInteger (abs s) `divMod` 2147483562

---------------- The Random class ---------------------------
class Random a where
   randomR :: RandomGen g => (a, a) -> g -> (a, g)
   random  :: RandomGen g => g -> (a, g)

   randomRs :: RandomGen g => (a, a) -> g -> [a]
   randoms  :: RandomGen g => g -> [a]

   randomRIO :: (a,a) -> IO a
   randomIO  :: IO a

     -- Default methods (27.2; overlay ov.random.defaults)
   randoms g = x : randoms g'
	       where 
		 (x,g') = random g
   randomRs ival g = x : randomRs ival g'
	       where 
		 (x,g') = randomR ival g

   randomIO        = getStdRandom random
   randomRIO range = getStdRandom (randomR range)

-- The instances, by 27.2's ranges: the whole type where it is bounded,
-- [0,1) for a fractional type, Int's range for Integer (ov.random.instances)
instance Random Int     where
  randomR (l,h) g = case randomInteger (toInteger l, toInteger h) g of (x, g') -> (fromInteger x, g')
  random g        = randomR (minBound, maxBound) g
instance Random Integer where
  randomR ival g  = randomInteger ival g
  random g        = randomR (toInteger (minBound :: Int), toInteger (maxBound :: Int)) g
instance Random Float   where
  randomR (l,h) g = case randomR (realToFrac l, realToFrac h :: Double) g of (x, g') -> (realToFrac x, g')
  random g        = case random g of (x, g') -> (realToFrac (x :: Double), g')
instance Random Double  where
  randomR (l,h) g = case random g of (x, g') -> (l + (h - l) * x, g')
  random g        = case randomInteger (0, 9007199254740991) g of
                      (x, g') -> (fromInteger x / 9007199254740992, g')
instance Random Bool    where
  randomR (l,h) g = case randomInteger (toInteger (fromEnum l), toInteger (fromEnum h)) g of
                      (x, g') -> (toEnum (fromInteger x), g')
  random g        = randomR (minBound, maxBound) g
instance Random Char    where
  randomR (l,h) g = case randomInteger (toInteger (ord l), toInteger (ord h)) g of
                      (x, g') -> (chr (fromInteger x), g')
  random g        = randomR (minBound, maxBound) g

-- a number between two, both included: enough of the generator's numbers,
-- in its range's base, reduced to the interval
randomInteger :: (RandomGen g) => (Integer, Integer) -> g -> (Integer, g)
randomInteger (l,h) g
  | l > h     = randomInteger (h,l) g
  | otherwise = case digits (count 1 width) 0 g of (v, g') -> (l + v `mod` (h - l + 1), g')
  where
    (lo, hi) = genRange g
    base = toInteger hi - toInteger lo + 1
    width = (h - l + 1) * 65536
    count n w = if w <= base then n else count (n + 1) (w `div` base)
    digits :: (RandomGen g) => Int -> Integer -> g -> (Integer, g)
    digits 0 acc g = (acc, g)
    digits n acc g = case next g of (x, g') -> digits (n - 1) (acc * base + toInteger x - toInteger lo) g'

---------------- The global random generator ----------------
newStdGen    :: IO StdGen
newStdGen    =  getStdGen >>= \g -> case split g of (a, b) -> setStdGen a >> return b
setStdGen    :: StdGen -> IO ()
setStdGen    =  ref_set theStdGen
getStdGen    :: IO StdGen	
getStdGen    =  ref_get theStdGen
getStdRandom :: (StdGen -> (a, StdGen)) -> IO a
getStdRandom f = getStdGen >>= \g -> case f g of (x, g') -> setStdGen g' >> return x

-- the global generator, made the first time it is used from the system's
-- randomness, or its clock (27.3; ov.random.global)
theStdGen    :: Ref StdGen
theStdGen    =  unsafe_perform_io (random_seed >>= \s -> ref_new (mkStdGen s))


