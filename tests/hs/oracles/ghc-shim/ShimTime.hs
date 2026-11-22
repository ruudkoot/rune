module ShimTime where

import Prelude
import Data.Ix
import Locale
import System.IO.Unsafe
import Data.Time.Clock.POSIX (getPOSIXTime, posixSecondsToUTCTime, utcTimeToPOSIXSeconds)
import qualified Data.Time as T
import qualified Data.Time.Calendar.OrdinalDate as T

data Month
 = January   | February | March    | April
 | May       | June     | July     | August
 | September | October  | November | December
 deriving (Eq, Ord, Enum, Bounded, Ix, Read, Show)

-- | A day of the week.

data Day 
 = Sunday   | Monday | Tuesday | Wednesday
 | Thursday | Friday | Saturday
 deriving (Eq, Ord, Enum, Bounded, Ix, Read, Show)

-- | A representation of the internal clock time.
-- Clock times may be compared, converted to strings, or converted to an
-- external calendar time 'CalendarTime' for I\/O or other manipulations.

data ClockTime = TOD Integer Integer
		-- ^ Construct a clock time.  The arguments are a number
		-- of seconds since 00:00:00 (UTC) on 1 January 1970,
		-- and an additional number of picoseconds.
		--
		-- In Haskell 98, the 'ClockTime' type is abstract.
	       deriving (Eq, Ord)

-- When a ClockTime is shown, it is converted to a CalendarTime in the current
-- timezone and then printed.  FIXME: This is arguably wrong, since we can't
-- get the current timezone without being in the IO monad.

instance Show ClockTime where
    showsPrec _ t = showString (calendarTimeToString 
	  			 (unsafePerformIO (toCalendarTime t)))

{-
The numeric fields have the following ranges.

\begin{verbatim}
Value         Range             Comments
-----         -----             --------

year    -maxInt .. maxInt       [Pre-Gregorian dates are inaccurate]
day           1 .. 31
hour          0 .. 23
min           0 .. 59
sec           0 .. 61           [Allows for two leap seconds]
picosec       0 .. (10^12)-1    [This could be over-precise?]
yday          0 .. 365          [364 in non-Leap years]
tz       -43200 .. 43200        [Variation from UTC in seconds]
\end{verbatim}
-}

-- | 'CalendarTime' is a user-readable and manipulable
-- representation of the internal 'ClockTime' type.

data CalendarTime 
 = CalendarTime  {
       ctYear    :: Int		-- ^ Year (pre-Gregorian dates are inaccurate)
     , ctMonth   :: Month	-- ^ Month of the year
     , ctDay     :: Int		-- ^ Day of the month (1 to 31)
     , ctHour    :: Int		-- ^ Hour of the day (0 to 23)
     , ctMin     :: Int		-- ^ Minutes (0 to 59)
     , ctSec     :: Int		-- ^ Seconds (0 to 61, allowing for up to
				-- two leap seconds)
     , ctPicosec :: Integer	-- ^ Picoseconds
     , ctWDay    :: Day		-- ^ Day of the week
     , ctYDay    :: Int		-- ^ Day of the year
				-- (0 to 364, or 365 in leap years)
     , ctTZName  :: String	-- ^ Name of the time zone
     , ctTZ      :: Int		-- ^ Variation from UTC in seconds
     , ctIsDST   :: Bool	-- ^ 'True' if Daylight Savings Time would
				-- be in effect, and 'False' otherwise
 }
 deriving (Eq,Ord,Read,Show)

-- | records the difference between two clock times in a user-readable way.

data TimeDiff
 = TimeDiff {
     tdYear    :: Int,
     tdMonth   :: Int,
     tdDay     :: Int,
     tdHour    :: Int,
     tdMin     :: Int,
     tdSec     :: Int,
     tdPicosec :: Integer -- not standard
   }
   deriving (Eq,Ord,Read,Show)

-- | null time difference.

noTimeDiff :: TimeDiff
noTimeDiff = TimeDiff 0 0 0 0 0 0 0

-- -----------------------------------------------------------------------------
-- | returns the current time in its internal representation.

addToClockTime  :: TimeDiff  -> ClockTime -> ClockTime
addToClockTime (TimeDiff year mon day hour min sec psec) 
	       (TOD c_sec c_psec) = 
	let
	  sec_diff = toInteger sec +
                     60 * toInteger min +
                     3600 * toInteger hour +
                     24 * 3600 * toInteger day
          (d_sec, d_psec) = (c_psec + psec) `quotRem` 1000000000000
          cal      = toUTCTime (TOD (c_sec + sec_diff + d_sec) d_psec)
          new_mon  = fromEnum (ctMonth cal) + r_mon 
	  month' = fst tmp
	  yr_diff = snd tmp
          tmp
	    | new_mon < 0  = (toEnum (12 + new_mon), (-1))
	    | new_mon > 11 = (toEnum (new_mon `mod` 12), 1)
	    | otherwise    = (toEnum new_mon, 0)
	    
	  (r_yr, r_mon) = mon `quotRem` 12

          year' = ctYear cal + year + r_yr + yr_diff
	in
	toClockTime cal{ctMonth=month', ctYear=year'}

-- | @'diffClockTimes' t1 t2@ returns the difference between two clock
-- times @t1@ and @t2@ as a 'TimeDiff'.

diffClockTimes  :: ClockTime -> ClockTime -> TimeDiff
-- diffClockTimes is meant to be the dual to `addToClockTime'.
-- If you want to have the TimeDiff properly splitted, use
-- `normalizeTimeDiff' on this function's result
--
-- CAVEAT: see comment of normalizeTimeDiff
diffClockTimes (TOD sa pa) (TOD sb pb) =
    noTimeDiff{ tdSec     = fromIntegral (sa - sb) 
                -- FIXME: can handle just 68 years...
              , tdPicosec = pa - pb
              }


-- | converts a time difference to normal form.

calendarTimeToString  :: CalendarTime -> String
calendarTimeToString  =  formatCalendarTime defaultTimeLocale "%c"

-- | formats calendar times using local conventions and a formatting string.
-- The formatting string is that understood by the ISO C @strftime()@
-- function.

formatCalendarTime :: TimeLocale -> String -> CalendarTime -> String
formatCalendarTime l fmt (CalendarTime year mon day hour min sec _
                                       wday yday tzname _ _) =
        doFmt fmt
  where doFmt ('%':'-':cs) = doFmt ('%':cs) -- padding not implemented
        doFmt ('%':'_':cs) = doFmt ('%':cs) -- padding not implemented
        doFmt ('%':c:cs)   = decode c ++ doFmt cs
        doFmt (c:cs) = c : doFmt cs
        doFmt "" = ""

        decode 'A' = fst (wDays l  !! fromEnum wday) -- day of the week, full name
        decode 'a' = snd (wDays l  !! fromEnum wday) -- day of the week, abbrev.
        decode 'B' = fst (months l !! fromEnum mon)  -- month, full name
        decode 'b' = snd (months l !! fromEnum mon)  -- month, abbrev
        decode 'h' = snd (months l !! fromEnum mon)  -- ditto
        decode 'C' = show2 (year `quot` 100)         -- century
        decode 'c' = doFmt (dateTimeFmt l)           -- locale's data and time format.
        decode 'D' = doFmt "%m/%d/%y"
        decode 'd' = show2 day                       -- day of the month
        decode 'e' = show2' day                      -- ditto, padded
        decode 'H' = show2 hour                      -- hours, 24-hour clock, padded
        decode 'I' = show2 (to12 hour)               -- hours, 12-hour clock
        decode 'j' = show3 yday                      -- day of the year
        decode 'k' = show2' hour                     -- hours, 24-hour clock, no padding
        decode 'l' = show2' (to12 hour)              -- hours, 12-hour clock, no padding
        decode 'M' = show2 min                       -- minutes
        decode 'm' = show2 (fromEnum mon+1)          -- numeric month
        decode 'n' = "\n"
        decode 'p' = (if hour < 12 then fst else snd) (amPm l) -- am or pm
        decode 'R' = doFmt "%H:%M"
        decode 'r' = doFmt (time12Fmt l)
        decode 'T' = doFmt "%H:%M:%S"
        decode 't' = "\t"
        decode 'S' = show2 sec			     -- seconds
        decode 's' = show2 sec			     -- number of secs since Epoch. (ToDo.)
        decode 'U' = show2 ((yday + 7 - fromEnum wday) `div` 7) -- week number, starting on Sunday.
        decode 'u' = show (let n = fromEnum wday in  -- numeric day of the week (1=Monday, 7=Sunday)
                           if n == 0 then 7 else n)
        decode 'V' =                                 -- week number (as per ISO-8601.)
            let (week, days) =                       -- [yep, I've always wanted to be able to display that too.]
                   (yday + 7 - if fromEnum wday > 0 then 
                               fromEnum wday - 1 else 6) `divMod` 7
            in  show2 (if days >= 4 then
                          week+1 
                       else if week == 0 then 53 else week)

        decode 'W' =				     -- week number, weeks starting on monday
            show2 ((yday + 7 - if fromEnum wday > 0 then 
                               fromEnum wday - 1 else 6) `div` 7)
        decode 'w' = show (fromEnum wday)            -- numeric day of the week, weeks starting on Sunday.
        decode 'X' = doFmt (timeFmt l)               -- locale's preferred way of printing time.
        decode 'x' = doFmt (dateFmt l)               -- locale's preferred way of printing dates.
        decode 'Y' = show year                       -- year, including century.
        decode 'y' = show2 (year `rem` 100)          -- year, within century.
        decode 'Z' = tzname                          -- timezone name
        decode '%' = "%"
        decode c   = [c]


show2, show2', show3 :: Int -> String
show2 x
 | x' < 10   = '0': show x'
 | otherwise = show x'
 where x' = x `rem` 100

show2' x
 | x' < 10   = ' ': show x'
 | otherwise = show x'
 where x' = x `rem` 100

show3 x = show (x `quot` 100) ++ show2 (x `rem` 100)

to12 :: Int -> Int
to12 h = let h' = h `mod` 12 in if h' == 0 then 12 else h'

-- Useful extensions for formatting TimeDiffs.

-- | formats time differences using local conventions.


clockTimeOfPOSIX :: Rational -> ClockTime
clockTimeOfPOSIX r = TOD s (truncate ((r - fromInteger s) * 1000000000000)) where s = floor r

getClockTime :: IO ClockTime
getClockTime = do
  t <- getPOSIXTime
  return (clockTimeOfPOSIX (toRational t))

calOf :: T.TimeZone -> Bool -> ClockTime -> CalendarTime
calOf tz isUtc (TOD s p) =
  let u  = posixSecondsToUTCTime (fromInteger s)
      l  = T.utcToLocalTime tz u
      d  = T.localDay l
      tod = T.localTimeOfDay l
      (y, m, dd) = T.toGregorian d
      (_, yd) = T.toOrdinalDate d
      (_, wd) = T.sundayStartWeek d
  in CalendarTime (fromInteger y) (toEnum (m - 1)) dd (T.todHour tod) (T.todMin tod) (truncate (T.todSec tod)) p
       (toEnum wd) (yd - 1) (if isUtc then "UTC" else T.timeZoneName tz)
       (if isUtc then 0 else 60 * T.timeZoneMinutes tz) (not isUtc && T.timeZoneSummerOnly tz)

toUTCTime :: ClockTime -> CalendarTime
toUTCTime = calOf T.utc True

toCalendarTime :: ClockTime -> IO CalendarTime
toCalendarTime c@(TOD s _) = do
  tz <- T.getTimeZone (posixSecondsToUTCTime (fromInteger s))
  return (calOf tz False c)

toClockTime :: CalendarTime -> ClockTime
toClockTime (CalendarTime y m d h mi s p _ _ _ tz _) =
  let day = T.fromGregorian (toInteger y) (fromEnum m + 1) d
      secs = T.toModifiedJulianDay day * 86400 - 40587 * 86400 + toInteger (h * 3600 + mi * 60 + s) - toInteger tz
  in TOD secs p

