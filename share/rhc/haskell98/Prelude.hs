-- Module Prelude, section 8 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module Prelude (
    module PreludeList, module PreludeText, module PreludeIO,
    Bool(False, True),
    Maybe(Nothing, Just),
    Either(Left, Right),
    Ordering(LT, EQ, GT),
    Char, String, Int, Integer, Float, Double, Rational, IO,

--      These built-in types are defined in the Prelude, but
--      are denoted by built-in syntax, and cannot legally
--      appear in an export list.
--  List type: []((:), [])
--  Tuple types: (,)((,)), (,,)((,,)), etc.
--  Trivial type: ()(())
--  Functions: (->)

    Eq((==), (/=)),
    Ord(compare, (<), (<=), (>=), (>), max, min),
    Enum(succ, pred, toEnum, fromEnum, enumFrom, enumFromThen,
         enumFromTo, enumFromThenTo),
    Bounded(minBound, maxBound),
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
    mapM, mapM_, sequence, sequence_, (=<<), 
    maybe, either,
    (&&), (||), not, otherwise,
    subtract, even, odd, gcd, lcm, (^), (^^), 
    fromIntegral, realToFrac, 
    fst, snd, curry, uncurry, id, const, (.), flip, ($), until,
    asTypeOf, error, undefined,
    seq, ($!)
  ) where

import PreludeBuiltin                      -- Contains all `prim' values
import UnicodePrims( primUnicodeMaxChar )  -- Unicode primitives
import PreludeList
import PreludeText
import PreludeIO
import Ratio( Rational )
import PreludeEnum                         -- numericEnumFrom... (rhc's)
import Numeric( fromRat )                  -- Float's and Double's fromRational

infixr 9  .
infixr 8  ^, ^^, **
infixl 7  *, /, `quot`, `rem`, `div`, `mod`
infixl 6  +, -

-- The (:) operator is built-in syntax, and cannot legally be given
-- a fixity declaration; but its fixity is given by:
--   infixr 5  :

infix  4  ==, /=, <, <=, >=, >
infixr 3  &&
infixr 2  ||
infixl 1  >>, >>=
infixr 1  =<<
infixr 0  $, $!, `seq`

-- Standard types, classes, instances and related functions

-- Equality and Ordered classes


class  Eq a  where
    (==), (/=) :: a -> a -> Bool

        -- Minimal complete definition:
        --      (==) or (/=)
    x /= y     =  not (x == y)
    x == y     =  not (x /= y)


class  (Eq a) => Ord a  where
    compare              :: a -> a -> Ordering
    (<), (<=), (>=), (>) :: a -> a -> Bool
    max, min             :: a -> a -> a

        -- Minimal complete definition:
        --      (<=) or compare
        -- Using compare can be more efficient for complex types.
    compare x y
         | x == y    =  EQ
         | x <= y    =  LT
         | otherwise =  GT

    x <= y           =  compare x y /= GT
    x <  y           =  compare x y == LT
    x >= y           =  compare x y /= LT
    x >  y           =  compare x y == GT

-- note that (min x y, max x y) = (x,y) or (y,x)
    max x y 
         | x <= y    =  y
         | otherwise =  x
    min x y
         | x <= y    =  x
         | otherwise =  y

-- Enumeration and Bounded classes


class  Enum a  where
    succ, pred       :: a -> a
    toEnum           :: Int -> a
    fromEnum         :: a -> Int
    enumFrom         :: a -> [a]             -- [n..]
    enumFromThen     :: a -> a -> [a]        -- [n,n'..]
    enumFromTo       :: a -> a -> [a]        -- [n..m]
    enumFromThenTo   :: a -> a -> a -> [a]   -- [n,n'..m]

        -- Minimal complete definition:
        --      toEnum, fromEnum
	--
	-- NOTE: these default methods only make sense for types
	-- 	 that map injectively into Int using fromEnum
	--	 and toEnum.
    succ             =  toEnum . (+1) . fromEnum
    pred             =  toEnum . (subtract 1) . fromEnum
    enumFrom x       =  map toEnum [fromEnum x ..]
    enumFromTo x y   =  map toEnum [fromEnum x .. fromEnum y]
    enumFromThen x y =  map toEnum [fromEnum x, fromEnum y ..]
    enumFromThenTo x y z = 
                        map toEnum [fromEnum x, fromEnum y .. fromEnum z]


class  Bounded a  where
    minBound         :: a
    maxBound         :: a

-- Numeric classes


class  (Eq a, Show a) => Num a  where
    (+), (-), (*)    :: a -> a -> a
    negate           :: a -> a
    abs, signum      :: a -> a
    fromInteger      :: Integer -> a

        -- Minimal complete definition:
        --      All, except negate or (-)
    x - y            =  x + negate y
    negate x         =  0 - x


class  (Num a, Ord a) => Real a  where
    toRational       ::  a -> Rational


class  (Real a, Enum a) => Integral a  where
    quot, rem        :: a -> a -> a   
    div, mod         :: a -> a -> a
    quotRem, divMod  :: a -> a -> (a,a)
    toInteger        :: a -> Integer

        -- Minimal complete definition:
        --      quotRem, toInteger
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

        -- Minimal complete definition:
        --      fromRational and (recip or (/))
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

        -- Minimal complete definition:
        --      pi, exp, log, sin, cos, sinh, cosh
        --      asin, acos, atan
        --      asinh, acosh, atanh
    x ** y           =  exp (log x * y)
    logBase x y      =  log y / log x
    sqrt x           =  x ** 0.5
    tan  x           =  sin  x / cos  x
    tanh x           =  sinh x / cosh x



class  (Real a, Fractional a) => RealFrac a  where
    properFraction   :: (Integral b) => a -> (b,a)
    truncate, round  :: (Integral b) => a -> b
    ceiling, floor   :: (Integral b) => a -> b

        -- Minimal complete definition:
        --      properFraction
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

        -- Minimal complete definition:
        --      All except exponent, significand, 
        --                 scaleFloat, atan2
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
                      =  pi    -- must be after the previous test on zero y
      | x==0 && y==0  =  y     -- must be after the other double zero tests
      | otherwise     =  x + y -- x or y is a NaN, return a NaN (via +)

-- Numeric functions


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

        -- Minimal complete definition:
        --      (>>=), return
    m >> k  =  m >>= \_ -> k
    fail s  = error s


sequence       :: Monad m => [m a] -> m [a] 
sequence       =  foldr mcons (return [])
                    where mcons p q = p >>= \x -> q >>= \y -> return (x:y)


sequence_      :: Monad m => [m a] -> m () 
sequence_      =  foldr (>>) (return ())

-- The xxxM functions take list arguments, but lift the function or
-- list element to a monad type

mapM             :: Monad m => (a -> m b) -> [a] -> m [b]
mapM f as        =  sequence (map f as)


mapM_            :: Monad m => (a -> m b) -> [a] -> m ()
mapM_ f as       =  sequence_ (map f as)


(=<<)            :: Monad m => (a -> m b) -> m a -> m b
f =<< x          =  x >>= f


-- Trivial type


-- () is built-in syntax: the instances its deriving clause names, as
-- chapter 10 derives them (overlay ov.prelude.unit)

instance  Eq ()  where
    () == ()         =  True

instance  Ord ()  where
    compare () ()    =  EQ

instance  Enum ()  where
    toEnum 0         =  ()
    toEnum _         =  error "Prelude.Enum.().toEnum: bad argument"
    fromEnum ()      =  0
    enumFrom x       =  enumFromTo x ()
    enumFromThen x y =  enumFromThenTo x y ()

instance  Bounded ()  where
    minBound         =  ()
    maxBound         =  ()

-- Function type

-- identity function

id               :: a -> a
id x             =  x

-- constant function

const            :: a -> b -> a
const x _        =  x

-- function composition

(.)              :: (b -> c) -> (a -> b) -> a -> c
f . g            =  \ x -> f (g x)

-- flip f  takes its (first) two arguments in the reverse order of f.

flip             :: (a -> b -> c) -> b -> a -> c
flip f x y       =  f y x


seq :: a -> b -> b
seq =  primSeq   -- Primitive

-- right-associating infix application operators 
-- (useful in continuation-passing style)

($), ($!) :: (a -> b) -> a -> b
f $  x    =  f x
f $! x    =  x `seq` f x


-- Boolean type


data  Bool  =  False | True     deriving (Eq, Ord, Enum, Read, Show, Bounded)

-- Boolean functions


(&&), (||)       :: Bool -> Bool -> Bool
True  && x       =  x
False && _       =  False
True  || _       =  True
False || x       =  x
                                        

not              :: Bool -> Bool
not True         =  False
not False        =  True


otherwise        :: Bool
otherwise        =  True


-- Character type


data Char       -- Unicode values: a code point, 0 to 0x10FFFF (rhc's primitive)


instance  Eq Char  where
    c == c'          =  fromEnum c == fromEnum c'


instance  Ord Char  where
    c <= c'          =  fromEnum c <= fromEnum c'


instance  Enum Char  where
    toEnum            = primIntToChar
    fromEnum          = primCharToInt
    enumFrom c        = map toEnum [fromEnum c .. fromEnum (maxBound::Char)]
    enumFromThen c c' = map toEnum [fromEnum c, fromEnum c' .. fromEnum lastChar]
                      where lastChar :: Char
                            lastChar | c' < c    = minBound
                                     | otherwise = maxBound


instance  Bounded Char  where
    minBound  =  '\0'
    maxBound  =  primUnicodeMaxChar


type  String = [Char]


-- Maybe type


data  Maybe a  =  Nothing | Just a      deriving (Eq, Ord, Read, Show)


maybe              :: b -> (a -> b) -> Maybe a -> b
maybe n f Nothing  =  n
maybe n f (Just x) =  f x


instance  Functor Maybe  where
    fmap f Nothing    =  Nothing
    fmap f (Just x)   =  Just (f x)
        

instance  Monad Maybe  where
    (Just x) >>= k   =  k x
    Nothing  >>= k   =  Nothing
    return           =  Just
    fail s           =  Nothing

-- Either type


data  Either a b  =  Left a | Right b   deriving (Eq, Ord, Read, Show)


either               :: (a -> c) -> (b -> c) -> Either a b -> c
either f g (Left x)  =  f x
either f g (Right y) =  g y

-- IO type


data IO a       -- abstract (rhc's primitive: a state token, D25)


instance  Functor IO where
   fmap f x           =  x >>= (return . f)


instance Monad IO where
   (>>=)  = io_bind
   return = io_return
   fail s = ioError (userError s)

-- Ordering type


data  Ordering  =  LT | EQ | GT
          deriving (Eq, Ord, Enum, Read, Show, Bounded)


-- Standard numeric types.  The data declarations for these types cannot
-- be expressed directly in Haskell since the constructor lists would be
-- far too large.


-- Int is rhc's primitive, Mid's int, on the checked primitives: an
-- arithmetic past its range is an error (D22), and its Enum is bounded (R40)
data  Int

instance  Eq       Int  where
    (==)             =  int_eq
    (/=)             =  int_ne

instance  Ord      Int  where
    (<)              =  int_lt
    (<=)             =  int_le
    (>=)             =  int_ge
    (>)              =  int_gt
    compare x y
      | int_lt x y   =  LT
      | int_eq x y   =  EQ
      | otherwise    =  GT

instance  Num      Int  where
    (+)              =  int_add
    (-)              =  int_sub
    (*)              =  int_mul
    negate           =  int_neg
    abs x            =  if int_lt x 0 then int_neg x else x
    signum x
      | int_gt x 0   =  1
      | int_lt x 0   =  -1
      | otherwise    =  0
    fromInteger      =  integer_to_int

instance  Real     Int  where
    toRational x     =  toRational (toInteger x)

instance  Integral Int  where
    quot             =  int_quot
    rem              =  int_rem
    div              =  int_div
    mod              =  int_mod
    quotRem x y      =  (int_quot x y, int_rem x y)
    divMod x y       =  (int_div x y, int_mod x y)
    toInteger        =  integer_from_int

instance  Enum     Int  where
    succ x           =  x + 1
    pred x           =  x - 1
    toEnum x         =  x
    fromEnum x       =  x
    enumFrom x       =  enumFromTo x maxBound
    enumFromThen x y =  enumFromThenTo x y (if y >= x then maxBound else minBound)
    enumFromTo x y   =  if x > y then [] else up x
                        where up i = i : (if i == y then [] else up (i + 1))
    enumFromThenTo x y z =
                        map fromInteger (enumFromThenTo (toInteger x) (toInteger y) (toInteger z))

instance  Bounded  Int  where
    minBound         =  int_min
    maxBound         =  int_max


-- Integer is rhc's primitive, IntInf's representation (D20, M31)
data  Integer

instance  Eq       Integer  where
    (==)             =  integer_eq
    (/=)             =  integer_ne

instance  Ord      Integer  where
    (<)              =  integer_lt
    (<=)             =  integer_le
    (>=)             =  integer_ge
    (>)              =  integer_gt
    compare x y
      | integer_lt x y = LT
      | integer_eq x y = EQ
      | otherwise      = GT

instance  Num      Integer  where
    (+)              =  integer_add
    (-)              =  integer_sub
    (*)              =  integer_mul
    negate           =  integer_neg
    abs x            =  if integer_lt x 0 then integer_neg x else x
    signum x
      | integer_gt x 0 = 1
      | integer_lt x 0 = -1
      | otherwise      = 0
    fromInteger x    =  x

instance  Real     Integer  where
    toRational x     =  fromInteger x

instance  Integral Integer  where
    quot             =  integer_quot
    rem              =  integer_rem
    div              =  integer_div
    mod              =  integer_mod
    quotRem x y      =  (integer_quot x y, integer_rem x y)
    divMod x y       =  (integer_div x y, integer_mod x y)
    toInteger x      =  x

instance  Enum     Integer  where
    succ x           =  x + 1
    pred x           =  x - 1
    toEnum           =  integer_from_int
    fromEnum         =  integer_to_int
    enumFrom x       =  x `seq` (x : enumFrom (x + 1))
    enumFromThen x y =  x `seq` y `seq` (x : enumFromThen y (y + y - x))
    enumFromTo x y   =  if x > y then [] else x : enumFromTo (x + 1) y
    enumFromThenTo x y z
      | y >= x       =  if x > z then [] else x : enumFromThenTo y (y + y - x) z
      | otherwise    =  if x < z then [] else x : enumFromThenTo y (y + y - x) z


-- Float is rhc's primitive: a binary64 rounded to binary32 after each
-- operation, as Rune's Real32 is (D23)
data  Float

-- a function of Double's, taken to Float's
viaDouble        :: (Double -> Double) -> Float -> Float
viaDouble f x    =  float_from_double (f (float_to_double x))

viaDouble2       :: (Double -> Double -> Double) -> Float -> Float -> Float
viaDouble2 f x y =  float_from_double (f (float_to_double x) (float_to_double y))

instance  Eq         Float  where
    x == y           =  float_to_double x == float_to_double y

instance  Ord        Float  where
    x <  y           =  float_to_double x <  float_to_double y
    x <= y           =  float_to_double x <= float_to_double y
    x >= y           =  float_to_double x >= float_to_double y
    x >  y           =  float_to_double x >  float_to_double y
    compare x y      =  compare (float_to_double x) (float_to_double y)

instance  Num        Float  where
    (+)              =  viaDouble2 (+)
    (-)              =  viaDouble2 (-)
    (*)              =  viaDouble2 (*)
    negate           =  viaDouble negate
    abs              =  viaDouble abs
    signum           =  viaDouble signum
    fromInteger n
      | abs n < 9007199254740992 = float_from_double (integer_to_double n)
      | otherwise    =  fromRat (fromInteger n)

instance  Real       Float  where
    toRational x     =  toRational (float_to_double x)

instance  Fractional Float  where
    (/)              =  viaDouble2 (/)
    fromRational     =  fromRat

instance  Floating   Float  where
    pi               =  float_from_double pi
    exp              =  viaDouble exp
    log              =  viaDouble log
    sqrt             =  viaDouble sqrt
    (**)             =  viaDouble2 (**)
    logBase          =  viaDouble2 logBase
    sin              =  viaDouble sin
    cos              =  viaDouble cos
    tan              =  viaDouble tan
    asin             =  viaDouble asin
    acos             =  viaDouble acos
    atan             =  viaDouble atan
    sinh             =  viaDouble sinh
    cosh             =  viaDouble cosh
    tanh             =  viaDouble tanh
    asinh            =  viaDouble asinh
    acosh            =  viaDouble acosh
    atanh            =  viaDouble atanh

instance  RealFrac   Float  where
    properFraction x =  case properFraction (float_to_double x) of
                          (n, f) -> (n, float_from_double f)

instance  RealFloat  Float  where
    floatRadix _     =  2
    floatDigits _    =  24
    floatRange _     =  (-125, 128)
    decodeFloat x    =  case decodeFloat (float_to_double x) of
                          (m, e) -> if m == 0 then (0, 0) else (m `quot` 536870912, e + 29)
    encodeFloat m e  =  float_from_double (encodeFloat m e)
    isNaN x          =  isNaN (float_to_double x)
    isInfinite x     =  isInfinite (float_to_double x)
    isDenormalized x =  x /= 0 && not (isNaN x) && abs x < encodeFloat 1 (-126)
    isNegativeZero x =  isNegativeZero (float_to_double x)
    isIEEE _         =  True


-- Double is rhc's primitive, Mid's real, a binary64
data  Double

instance  Eq         Double  where
    (==)             =  double_eq
    (/=)             =  double_ne

instance  Ord        Double  where
    (<)              =  double_lt
    (<=)             =  double_le
    (>=)             =  double_ge
    (>)              =  double_gt
    compare x y
      | double_lt x y = LT
      | double_eq x y = EQ
      | otherwise     = GT

instance  Num        Double  where
    (+)              =  double_add
    (-)              =  double_sub
    (*)              =  double_mul
    negate           =  double_neg
    abs              =  double_abs
    signum x
      | x > 0        =  1
      | x < 0        =  -1
      | otherwise    =  x
    fromInteger      =  integer_to_double

instance  Real       Double  where
    toRational x     =  fromInteger m * fromInteger (floatRadix x) ^^ n
                        where (m,n) = decodeFloat x

instance  Fractional Double  where
    (/)              =  double_div
    fromRational     =  fromRat

instance  Floating   Double  where
    pi               =  3.141592653589793238
    exp              =  double_exp
    log              =  double_log
    sqrt             =  double_sqrt
    (**)             =  double_pow
    sin              =  double_sin
    cos              =  double_cos
    tan              =  double_tan
    asin x           =  double_atan2 x (double_sqrt (1 - x*x))
    acos x           =  double_atan2 (double_sqrt (1 - x*x)) x
    atan             =  double_atan
    sinh             =  double_sinh
    cosh             =  double_cosh
    tanh             =  double_tanh
    asinh x          =  log (x + sqrt (x*x + 1))
    acosh x          =  log (x + sqrt (x*x - 1))
    atanh x          =  (log (1 + x) - log (1 - x)) / 2

instance  RealFrac   Double  where
    properFraction x
      | e >= 0       =  (fromInteger m * 2 ^ e, 0)
      | otherwise    =  (fromInteger q, encodeFloat r e)
      where (m,e) = decodeFloat x
            (q,r) = quotRem m (2 ^ negate e)

instance  RealFloat  Double  where
    floatRadix _     =  2
    floatDigits _    =  53
    floatRange _     =  (-1021, 1024)
    decodeFloat x    =  (double_mantissa x, double_exponent x)
    encodeFloat      =  double_encode
    isNaN            =  double_is_nan
    isInfinite x     =  not (isNaN x) && x /= 0 && x + x == x
    isDenormalized x =  x /= 0 && not (isNaN x) && abs x < encodeFloat 1 (-1022)
    isNegativeZero x =  x == 0 && 1 / x < 0
    isIEEE _         =  True

-- The Enum instances for Floats and Doubles are slightly unusual.
-- The `toEnum' function truncates numbers to Int.  The definitions
-- of enumFrom and enumFromThen allow floats to be used in arithmetic
-- series: [0,0.1 .. 0.95].  However, roundoff errors make these somewhat
-- dubious.  This example may have either 10 or 11 elements, depending on
-- how 0.1 is represented.


instance  Enum Float  where
    succ x           =  x+1
    pred x           =  x-1
    toEnum           =  fromIntegral
    fromEnum         =  fromInteger . truncate   -- may overflow
    enumFrom x       =  x `seq` numericEnumFrom x
    enumFromThen x y =  x `seq` y `seq` numericEnumFromThen x y
    enumFromTo       =  numericEnumFromTo
    enumFromThenTo   =  numericEnumFromThenTo


instance  Enum Double  where
    succ x           =  x+1
    pred x           =  x-1
    toEnum           =  fromIntegral
    fromEnum         =  fromInteger . truncate   -- may overflow
    enumFrom x       =  x `seq` numericEnumFrom x
    enumFromThen x y =  x `seq` y `seq` numericEnumFromThen x y
    enumFromTo       =  numericEnumFromTo
    enumFromThenTo   =  numericEnumFromThenTo


-- numericEnumFrom, numericEnumFromThen, numericEnumFromTo and
-- numericEnumFromThenTo are in PreludeEnum, which Ratio imports too
-- (overlay ov.prelude.numericenum)

-- Lists


-- [a] is built-in syntax: the instances its deriving clause names, as
-- chapter 10 derives them (overlay ov.prelude.list)

instance  (Eq a) => Eq [a]  where
    []     == []     =  True
    (x:xs) == (y:ys) =  x == y && xs == ys
    _      == _      =  False

instance  (Ord a) => Ord [a]  where
    compare []     []     =  EQ
    compare []     (_:_)  =  LT
    compare (_:_)  []     =  GT
    compare (x:xs) (y:ys) =  case compare x y of
                                 EQ    -> compare xs ys
                                 other -> other


instance Functor [] where
    fmap = map


instance  Monad []  where
    m >>= k          = concat (map k m)
    return x         = [x]
    fail s           = []

-- Tuples


-- Tuples are built-in syntax: the instances their deriving clauses name,
-- as chapter 10 derives them, at every size to 15 (6.1.4; overlay
-- ov.prelude.tuples, ov.tuples.fifteen)

instance  (Eq a, Eq b) => Eq (a,b)  where
    (a1,a2) == (b1,b2) =
        a1 == b1 && a2 == b2

instance  (Ord a, Ord b) => Ord (a,b)  where
    compare (a1,a2) (b1,b2) =
        lexOrder [compare a1 b1, compare a2 b2]

instance  (Bounded a, Bounded b) => Bounded (a,b)  where
    minBound = (minBound,minBound)
    maxBound = (maxBound,maxBound)

instance  (Eq a, Eq b, Eq c) => Eq (a,b,c)  where
    (a1,a2,a3) == (b1,b2,b3) =
        a1 == b1 && a2 == b2 && a3 == b3

instance  (Ord a, Ord b, Ord c) => Ord (a,b,c)  where
    compare (a1,a2,a3) (b1,b2,b3) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3]

instance  (Bounded a, Bounded b, Bounded c) => Bounded (a,b,c)  where
    minBound = (minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d) => Eq (a,b,c,d)  where
    (a1,a2,a3,a4) == (b1,b2,b3,b4) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4

instance  (Ord a, Ord b, Ord c, Ord d) => Ord (a,b,c,d)  where
    compare (a1,a2,a3,a4) (b1,b2,b3,b4) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4]

instance  (Bounded a, Bounded b, Bounded c, Bounded d) => Bounded (a,b,c,d)  where
    minBound = (minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e) => Eq (a,b,c,d,e)  where
    (a1,a2,a3,a4,a5) == (b1,b2,b3,b4,b5) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5

instance  (Ord a, Ord b, Ord c, Ord d, Ord e) => Ord (a,b,c,d,e)  where
    compare (a1,a2,a3,a4,a5) (b1,b2,b3,b4,b5) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e) => Bounded (a,b,c,d,e)  where
    minBound = (minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f) => Eq (a,b,c,d,e,f)  where
    (a1,a2,a3,a4,a5,a6) == (b1,b2,b3,b4,b5,b6) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f) => Ord (a,b,c,d,e,f)  where
    compare (a1,a2,a3,a4,a5,a6) (b1,b2,b3,b4,b5,b6) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f) => Bounded (a,b,c,d,e,f)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g) => Eq (a,b,c,d,e,f,g)  where
    (a1,a2,a3,a4,a5,a6,a7) == (b1,b2,b3,b4,b5,b6,b7) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g) => Ord (a,b,c,d,e,f,g)  where
    compare (a1,a2,a3,a4,a5,a6,a7) (b1,b2,b3,b4,b5,b6,b7) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g) => Bounded (a,b,c,d,e,f,g)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h) => Eq (a,b,c,d,e,f,g,h)  where
    (a1,a2,a3,a4,a5,a6,a7,a8) == (b1,b2,b3,b4,b5,b6,b7,b8) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h) => Ord (a,b,c,d,e,f,g,h)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8) (b1,b2,b3,b4,b5,b6,b7,b8) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h) => Bounded (a,b,c,d,e,f,g,h)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h, Eq i) => Eq (a,b,c,d,e,f,g,h,i)  where
    (a1,a2,a3,a4,a5,a6,a7,a8,a9) == (b1,b2,b3,b4,b5,b6,b7,b8,b9) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8 && a9 == b9

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h, Ord i) => Ord (a,b,c,d,e,f,g,h,i)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8,a9) (b1,b2,b3,b4,b5,b6,b7,b8,b9) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8, compare a9 b9]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h, Bounded i) => Bounded (a,b,c,d,e,f,g,h,i)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h, Eq i, Eq j) => Eq (a,b,c,d,e,f,g,h,i,j)  where
    (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) == (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8 && a9 == b9 && a10 == b10

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h, Ord i, Ord j) => Ord (a,b,c,d,e,f,g,h,i,j)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8, compare a9 b9, compare a10 b10]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h, Bounded i, Bounded j) => Bounded (a,b,c,d,e,f,g,h,i,j)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h, Eq i, Eq j, Eq k) => Eq (a,b,c,d,e,f,g,h,i,j,k)  where
    (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11) == (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8 && a9 == b9 && a10 == b10 && a11 == b11

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h, Ord i, Ord j, Ord k) => Ord (a,b,c,d,e,f,g,h,i,j,k)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11) (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8, compare a9 b9, compare a10 b10, compare a11 b11]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h, Bounded i, Bounded j, Bounded k) => Bounded (a,b,c,d,e,f,g,h,i,j,k)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h, Eq i, Eq j, Eq k, Eq l) => Eq (a,b,c,d,e,f,g,h,i,j,k,l)  where
    (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12) == (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8 && a9 == b9 && a10 == b10 && a11 == b11 && a12 == b12

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h, Ord i, Ord j, Ord k, Ord l) => Ord (a,b,c,d,e,f,g,h,i,j,k,l)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12) (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8, compare a9 b9, compare a10 b10, compare a11 b11, compare a12 b12]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h, Bounded i, Bounded j, Bounded k, Bounded l) => Bounded (a,b,c,d,e,f,g,h,i,j,k,l)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h, Eq i, Eq j, Eq k, Eq l, Eq m) => Eq (a,b,c,d,e,f,g,h,i,j,k,l,m)  where
    (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13) == (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8 && a9 == b9 && a10 == b10 && a11 == b11 && a12 == b12 && a13 == b13

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h, Ord i, Ord j, Ord k, Ord l, Ord m) => Ord (a,b,c,d,e,f,g,h,i,j,k,l,m)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13) (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8, compare a9 b9, compare a10 b10, compare a11 b11, compare a12 b12, compare a13 b13]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h, Bounded i, Bounded j, Bounded k, Bounded l, Bounded m) => Bounded (a,b,c,d,e,f,g,h,i,j,k,l,m)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h, Eq i, Eq j, Eq k, Eq l, Eq m, Eq n) => Eq (a,b,c,d,e,f,g,h,i,j,k,l,m,n)  where
    (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14) == (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8 && a9 == b9 && a10 == b10 && a11 == b11 && a12 == b12 && a13 == b13 && a14 == b14

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h, Ord i, Ord j, Ord k, Ord l, Ord m, Ord n) => Ord (a,b,c,d,e,f,g,h,i,j,k,l,m,n)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14) (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8, compare a9 b9, compare a10 b10, compare a11 b11, compare a12 b12, compare a13 b13, compare a14 b14]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h, Bounded i, Bounded j, Bounded k, Bounded l, Bounded m, Bounded n) => Bounded (a,b,c,d,e,f,g,h,i,j,k,l,m,n)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

instance  (Eq a, Eq b, Eq c, Eq d, Eq e, Eq f, Eq g, Eq h, Eq i, Eq j, Eq k, Eq l, Eq m, Eq n, Eq o) => Eq (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)  where
    (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15) == (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15) =
        a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6 && a7 == b7 && a8 == b8 && a9 == b9 && a10 == b10 && a11 == b11 && a12 == b12 && a13 == b13 && a14 == b14 && a15 == b15

instance  (Ord a, Ord b, Ord c, Ord d, Ord e, Ord f, Ord g, Ord h, Ord i, Ord j, Ord k, Ord l, Ord m, Ord n, Ord o) => Ord (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)  where
    compare (a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15) (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15) =
        lexOrder [compare a1 b1, compare a2 b2, compare a3 b3, compare a4 b4, compare a5 b5, compare a6 b6, compare a7 b7, compare a8 b8, compare a9 b9, compare a10 b10, compare a11 b11, compare a12 b12, compare a13 b13, compare a14 b14, compare a15 b15]

instance  (Bounded a, Bounded b, Bounded c, Bounded d, Bounded e, Bounded f, Bounded g, Bounded h, Bounded i, Bounded j, Bounded k, Bounded l, Bounded m, Bounded n, Bounded o) => Bounded (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)  where
    minBound = (minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound,minBound)
    maxBound = (maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound,maxBound)

-- the order of a tuple: its components', the first that differs
lexOrder         :: [Ordering] -> Ordering
lexOrder []      =  EQ
lexOrder (EQ:os) =  lexOrder os
lexOrder (o:_)   =  o

-- component projections for pairs:
-- (NB: not provided for triples, quadruples, etc.)

fst              :: (a,b) -> a
fst (x,y)        =  x


snd              :: (a,b) -> b
snd (x,y)        =  y

-- curry converts an uncurried function to a curried function;
-- uncurry converts a curried function to a function on pairs.

curry            :: ((a, b) -> c) -> a -> b -> c
curry f x y      =  f (x, y)


uncurry          :: (a -> b -> c) -> ((a, b) -> c)
uncurry f p      =  f (fst p) (snd p)

-- Misc functions

-- until p f  yields the result of applying f until p holds.

until            :: (a -> Bool) -> (a -> a) -> a -> a
until p f x 
     | p x       =  x
     | otherwise =  until p f (f x)

-- asTypeOf is a type-restricted version of const.  It is usually used
-- as an infix operator, and its typing forces its first argument
-- (which is usually overloaded) to have the same type as the second.

asTypeOf         :: a -> a -> a
asTypeOf         =  const

-- error stops execution and displays an error message


error            :: String -> a
error            =  primError

-- It is expected that compilers will recognize this and insert error
-- messages that are more appropriate to the context in which undefined 
-- appears. 


undefined        :: a
undefined        =  error "Prelude.undefined"

