{-# LANGUAGE RebindableSyntax, PackageImports #-}
-- H2010.Classes: the Haskell 2010 Report's numeric and monadic classes (T10 chapter 9), as classes of their own beside
-- base's, so that Num has Eq and Show as superclasses, Monad has fail and no Applicative superclass, and Functor,
-- Monad and MonadPlus have only the Report's instances.  Eq, Ord, Enum, Bounded, Show, Read and Ix stay base's: they are
-- the derivable classes, and `deriving` can only name base's.  Class bodies and the numeric functions are the Report's
-- code as rhc's haskell98 library has it (share/rhc/haskell98/Prelude.hs at 75ed95861, which is the 98 Report's code
-- with errata; T10 chapter 9 has the same text for these).  Instances for base's types delegate to base.
-- Programs see these through RebindableSyntax: literals, negation, do and if use the names in scope.
module H2010.Classes (
    Num((+), (-), (*), negate, abs, signum, fromInteger),
    Real(toRational),
    Integral(quot, rem, div, mod, quotRem, divMod, toInteger),
    Fractional((/), recip, fromRational),
    Floating(pi, exp, log, sqrt, (**), logBase, sin, cos, tan,
             asin, acos, atan, sinh, cosh, tanh, asinh, acosh, atanh),
    RealFrac(properFraction, truncate, round, ceiling, floor),
    RealFloat(floatRadix, floatDigits, floatRange, decodeFloat,
              encodeFloat, exponent, significand, scaleFloat, isNaN,
              isInfinite, isDenormalized, isIEEE, isNegativeZero, atan2),
    Monad((>>=), (>>), return, fail),
    Functor(fmap),
    MonadPlus(mzero, mplus),
    mapM, mapM_, sequence, sequence_, (=<<),
    subtract, even, odd, gcd, lcm, (^), (^^),
    fromIntegral, realToFrac,
    ifThenElse, Rational, Ratio, (%), numerator, denominator, approxRational,
    numericEnumFrom, numericEnumFromThen, numericEnumFromTo, numericEnumFromThenTo,
    error, undefined
  ) where

import "base" Prelude (Eq(..), Ord(..), Show(..), Read, Enum, Bounded, Bool(..), Int, Integer, Float, Double, IO,
    Maybe(..), String, Ordering(..), (.), ($), otherwise, not, (&&), (||), flip, map, concat, foldr, takeWhile,
    iterate, fst, snd)
import qualified "base" Prelude as P
import "base" GHC.Real (Ratio((:%)))
import qualified "base" GHC.Real as R
import "base" System.IO.Error (ioError, userError)
import qualified "array" Data.Array as A

infixr 8  ^, ^^, **
infixl 7  *, /, `quot`, `rem`, `div`, `mod`, %
infixl 6  +, -
infixl 1  >>, >>=
infixr 1  =<<

-- RebindableSyntax: `if` means ifThenElse wherever this is in scope (the Prelude exports it).
ifThenElse :: Bool -> a -> a -> a
ifThenElse True  t _ = t
ifThenElse False _ e = e

type Rational = Ratio Integer

error :: [P.Char] -> a
error = P.errorWithoutStackTrace

undefined :: a
undefined = error "Prelude.undefined"

class  (Eq a, Show a) => Num a  where
    (+), (-), (*)    :: a -> a -> a
    negate           :: a -> a
    abs, signum      :: a -> a
    fromInteger      :: Integer -> a
    x - y            =  x + negate y
    negate x         =  0 - x

class  (Num a, Ord a) => Real a  where
    toRational       ::  a -> Rational

class  (Real a, Enum a) => Integral a  where
    quot, rem        :: a -> a -> a
    div, mod         :: a -> a -> a
    quotRem, divMod  :: a -> a -> (a,a)
    toInteger        :: a -> Integer
    n `quot` d       =  q  where (q,r) = quotRem n d
    n `rem` d        =  r  where (q,r) = quotRem n d
    n `div` d        =  q  where (q,r) = divMod n d
    n `mod` d        =  r  where (q,r) = divMod n d
    divMod n d       =  if signum r == - signum d then (q-1, r+d) else qr
                        where qr@(q,r) = quotRem n d

class  (Num a) => Fractional a  where
    (/)              :: a -> a -> a
    recip            :: a -> a
    fromRational     :: Rational -> a
    recip x          =  1 / x
    x / y            =  x * recip y

class  (Fractional a) => Floating a  where
    pi                  :: a
    exp, log, sqrt      :: a -> a
    (**), logBase       :: a -> a -> a
    sin, cos, tan       :: a -> a
    asin, acos, atan    :: a -> a
    sinh, cosh, tanh    :: a -> a
    asinh, acosh, atanh :: a -> a
    x ** y           =  exp (log x * y)
    logBase x y      =  log y / log x
    sqrt x           =  x ** 0.5
    tan  x           =  sin  x / cos  x
    tanh x           =  sinh x / cosh x

class  (Real a, Fractional a) => RealFrac a  where
    properFraction   :: (Integral b) => a -> (b,a)
    truncate, round  :: (Integral b) => a -> b
    ceiling, floor   :: (Integral b) => a -> b
    truncate x       =  m  where (m,_) = properFraction x
    round x          =  let (n,r) = properFraction x
                            m     = if r < 0 then n - 1 else n + 1
                          in case signum (abs r - 0.5) of
                                -1 -> n
                                0  -> if even n then n else m
                                1  -> m
    ceiling x        =  if r > 0 then n + 1 else n
                        where (n,r) = properFraction x
    floor x          =  if r < 0 then n - 1 else n
                        where (n,r) = properFraction x

class  (RealFrac a, Floating a) => RealFloat a  where
    floatRadix       :: a -> Integer
    floatDigits      :: a -> Int
    floatRange       :: a -> (Int,Int)
    decodeFloat      :: a -> (Integer,Int)
    encodeFloat      :: Integer -> Int -> a
    exponent         :: a -> Int
    significand      :: a -> a
    scaleFloat       :: Int -> a -> a
    isNaN, isInfinite, isDenormalized, isNegativeZero, isIEEE
                     :: a -> Bool
    atan2            :: a -> a -> a
    exponent x       =  if m == 0 then 0 else n + floatDigits x
                        where (m,n) = decodeFloat x
    significand x    =  encodeFloat m (- floatDigits x)
                        where (m,_) = decodeFloat x
    scaleFloat k x   =  encodeFloat m (n+k)
                        where (m,n) = decodeFloat x
    atan2 y x
      | x>0           =  atan (y/x)
      | x==0 && y>0   =  pi/2
      | x<0  && y>0   =  pi + atan (y/x)
      |(x<=0 && y<0)  ||
       (x<0 && isNegativeZero y) ||
       (isNegativeZero x && isNegativeZero y)
                      = -atan2 (-y) x
      | y==0 && (x<0 || isNegativeZero x)
                      =  pi
      | x==0 && y==0  =  y
      | otherwise     =  x + y

subtract         :: (Num a) => a -> a -> a
subtract         =  flip (-)

even, odd        :: (Integral a) => a -> Bool
even n           =  n `rem` 2 == 0
odd              =  not . even

gcd              :: (Integral a) => a -> a -> a
gcd 0 0          =  error "Prelude.gcd: gcd 0 0 is undefined"
gcd x y          =  gcd' (abs x) (abs y)
                    where gcd' x 0  =  x
                          gcd' x y  =  gcd' y (x `rem` y)

lcm              :: (Integral a) => a -> a -> a
lcm _ 0          =  0
lcm 0 _          =  0
lcm x y          =  abs ((x `quot` (gcd x y)) * y)

(^)              :: (Num a, Integral b) => a -> b -> a
x ^ 0            =  1
x ^ n | n > 0    =  f x (n-1) x
                    where f _ 0 y = y
                          f x n y = g x n  where
                                    g x n | even n  = g (x*x) (n `quot` 2)
                                          | otherwise = f x (n-1) (x*y)
_ ^ _            = error "Prelude.^: negative exponent"

(^^)             :: (Fractional a, Integral b) => a -> b -> a
x ^^ n           =  if n >= 0 then x^n else recip (x^(-n))

fromIntegral     :: (Integral a, Num b) => a -> b
fromIntegral     =  fromInteger . toInteger

realToFrac     :: (Real a, Fractional b) => a -> b
realToFrac      =  fromRational . toRational

-- Monadic classes

class  Functor f  where
    fmap              :: (a -> b) -> f a -> f b

class  Monad m  where
    (>>=)  :: m a -> (a -> m b) -> m b
    (>>)   :: m a -> m b -> m b
    return :: a -> m a
    fail   :: String -> m a
    m >> k  =  m >>= \_ -> k
    fail s  = error s

class  (Monad m) => MonadPlus m  where
    mzero  :: m a
    mplus  :: m a -> m a -> m a

sequence       :: Monad m => [m a] -> m [a]
sequence       =  foldr mcons (return [])
                    where mcons p q = p >>= \x -> q >>= \y -> return (x:y)

sequence_      :: Monad m => [m a] -> m ()
sequence_      =  foldr (>>) (return ())

mapM             :: Monad m => (a -> m b) -> [a] -> m [b]
mapM f as        =  sequence (map f as)

mapM_            :: Monad m => (a -> m b) -> [a] -> m ()
mapM_ f as       =  sequence_ (map f as)

(=<<)            :: Monad m => (a -> m b) -> m a -> m b
f =<< x          =  x >>= f

instance Functor [] where
    fmap = map
instance Monad [] where
    m >>= k          = concat (map k m)
    return x         = [x]
    fail s           = []
instance MonadPlus [] where
    mzero = []
    mplus = (P.++)

instance Functor Maybe where
    fmap f Nothing    =  Nothing
    fmap f (Just x)   =  Just (f x)
instance Monad Maybe where
    (Just x) >>= k   =  k x
    Nothing  >>= k   =  Nothing
    return           =  Just
    fail s           =  Nothing
instance MonadPlus Maybe where
    mzero                 = Nothing
    Nothing `mplus` ys    = ys
    xs      `mplus` ys    = xs

instance Functor IO where
    fmap f x  =  x >>= (return . f)
instance Monad IO where
    (>>=)     =  (P.>>=)
    (>>)      =  (P.>>)
    return    =  P.return
    fail s    =  ioError (userError s)

instance A.Ix i => Functor (A.Array i) where
    fmap = P.fmap

-- Int, Integer, Float, Double

instance Num Int where
    (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum
    fromInteger = P.fromInteger
instance Real Int where
    toRational = P.toRational
instance Integral Int where
    quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod
    toInteger = P.toInteger

instance Num Integer where
    (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum
    fromInteger = P.fromInteger
instance Real Integer where
    toRational = P.toRational
instance Integral Integer where
    quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod
    toInteger = P.toInteger

instance Num Float where
    (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum
    fromInteger = P.fromInteger
instance Real Float where
    toRational = P.toRational
instance Fractional Float where
    (/) = (P./); recip = P.recip; fromRational = P.fromRational
instance Floating Float where
    pi = P.pi; exp = P.exp; log = P.log; sqrt = P.sqrt; (**) = (P.**); logBase = P.logBase
    sin = P.sin; cos = P.cos; tan = P.tan; asin = P.asin; acos = P.acos; atan = P.atan
    sinh = P.sinh; cosh = P.cosh; tanh = P.tanh; asinh = P.asinh; acosh = P.acosh; atanh = P.atanh
instance RealFrac Float where
    properFraction x = case P.properFraction x of (n, f) -> (fromInteger n, f)
    truncate x = fromInteger (P.truncate x)
    round x = fromInteger (P.round x)
    ceiling x = fromInteger (P.ceiling x)
    floor x = fromInteger (P.floor x)
instance RealFloat Float where
    floatRadix = P.floatRadix; floatDigits = P.floatDigits; floatRange = P.floatRange
    decodeFloat = P.decodeFloat; encodeFloat = P.encodeFloat
    isNaN = P.isNaN; isInfinite = P.isInfinite; isDenormalized = P.isDenormalized
    isNegativeZero = P.isNegativeZero; isIEEE = P.isIEEE

instance Num Double where
    (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum
    fromInteger = P.fromInteger
instance Real Double where
    toRational = P.toRational
instance Fractional Double where
    (/) = (P./); recip = P.recip; fromRational = P.fromRational
instance Floating Double where
    pi = P.pi; exp = P.exp; log = P.log; sqrt = P.sqrt; (**) = (P.**); logBase = P.logBase
    sin = P.sin; cos = P.cos; tan = P.tan; asin = P.asin; acos = P.acos; atan = P.atan
    sinh = P.sinh; cosh = P.cosh; tanh = P.tanh; asinh = P.asinh; acosh = P.acosh; atanh = P.atanh
instance RealFrac Double where
    properFraction x = case P.properFraction x of (n, f) -> (fromInteger n, f)
    truncate x = fromInteger (P.truncate x)
    round x = fromInteger (P.round x)
    ceiling x = fromInteger (P.ceiling x)
    floor x = fromInteger (P.floor x)
instance RealFloat Double where
    floatRadix = P.floatRadix; floatDigits = P.floatDigits; floatRange = P.floatRange
    decodeFloat = P.decodeFloat; encodeFloat = P.encodeFloat
    isNaN = P.isNaN; isInfinite = P.isInfinite; isDenormalized = P.isDenormalized
    isNegativeZero = P.isNegativeZero; isIEEE = P.isIEEE

-- Ratio: base's type (a fractional literal is base's Rational), the Report's code (Data.Ratio, T10 22.1; rhc's
-- haskell98 Ratio.hs).  Eq, Ord, Enum, Show and Read of Ratio a are base's instances: Ord, Enum and Read need base's
-- Integral a, so Real and RealFrac of Ratio a below need it too (true of Int and Integer, not of a type variable).


reduce :: Integral a => a -> a -> Ratio a
reduce _ 0              =  error "Ratio.% : zero denominator"
reduce x y              =  (x `quot` d) :% (y `quot` d)
                           where d = gcd x y

(%)                     :: (Integral a) => a -> a -> Ratio a
x % y                   =  reduce (x * signum y) (abs y)

numerator, denominator  :: (Integral a) => Ratio a -> a
numerator (x :% _)      =  x
denominator (_ :% y)    =  y

instance  (Integral a)  => Num (Ratio a)  where
    (x:%y) + (x':%y')   =  reduce (x*y' + x'*y) (y*y')
    (x:%y) * (x':%y')   =  reduce (x * x') (y * y')
    negate (x:%y)       =  (-x) :% y
    abs (x:%y)          =  abs x :% y
    signum (x:%y)       =  signum x :% 1
    fromInteger x       =  fromInteger x :% 1

instance  (Integral a, P.Integral a)  => Real (Ratio a)  where
    toRational (x:%y)   =  toInteger x :% toInteger y

instance  (Integral a)  => Fractional (Ratio a)  where
    (x:%y) / (x':%y')   =  (x*y') % (y*x')
    recip (x:%y)        =  y % x
    fromRational (x:%y) =  fromInteger x :% fromInteger y

instance  (Integral a, P.Integral a)  => RealFrac (Ratio a)  where
    properFraction (x:%y) = (fromIntegral q, r:%y)
                            where (q,r) = quotRem x y

approxRational          :: (RealFrac a) => a -> a -> Rational
approxRational x eps    =  simplest (x-eps) (x+eps)
        where simplest x y | y < x      =  simplest y x
                           | x == y     =  xr
                           | x > 0      =  simplest' n d n' d'
                           | y < 0      =  - simplest' (-n') d' (-n) d
                           | otherwise  =  0 :% 1
                                        where xr@(n:%d) = toRational x
                                              (n':%d')  = toRational y

              simplest' n d n' d'       -- assumes 0 < n%d < n'%d'
                        | r == 0     =  q :% 1
                        | q /= q'    =  (q+1) :% 1
                        | otherwise  =  (q*n''+d'') :% n''
                                     where (q,r)      =  quotRem n d
                                           (q',r')    =  quotRem n' d'
                                           (n'':%d'') =  simplest' d' r' d r

-- The Report's numericEnumFrom family (T10 chapter 9), for Data.Complex-free Enum instances written over these classes.
numericEnumFrom         :: (Fractional a) => a -> [a]
numericEnumFrom n       =  iterate (+1) n
numericEnumFromThen     :: (Fractional a) => a -> a -> [a]
numericEnumFromThen n m =  iterate (+(m-n)) n
numericEnumFromTo       :: (Fractional a, Ord a) => a -> a -> [a]
numericEnumFromTo n m   =  takeWhile (<= m+1/2) (numericEnumFrom n)
numericEnumFromThenTo   :: (Fractional a, Ord a) => a -> a -> a -> [a]
numericEnumFromThenTo n n' m = takeWhile p (numericEnumFromThen n n')
                             where
                               p | n' >= n   = (<= m + (n'-n)/2)
                                 | otherwise = (>= m + (n'-n)/2)
