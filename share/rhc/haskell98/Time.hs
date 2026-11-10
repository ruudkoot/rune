-- Module Time, section 24.1 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module Time (
        ClockTime, 
        Month(January,February,March,April,May,June,
              July,August,September,October,November,December),
        Day(Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday),
	CalendarTime(CalendarTime, ctYear, ctMonth, ctDay, ctHour, ctMin,
		     ctSec, ctPicosec, ctWDay, ctYDay, 
                     ctTZName, ctTZ, ctIsDST),
	TimeDiff(TimeDiff, tdYear, tdMonth, tdDay, 
		 tdHour, tdMin, tdSec, tdPicosec),
        getClockTime, addToClockTime, diffClockTimes,
        toCalendarTime, toUTCTime, toClockTime,
        calendarTimeToString, formatCalendarTime ) where

import Ix(Ix)
import Locale(TimeLocale(..),defaultTimeLocale)
import Char ( intToDigit )
import PreludeBuiltin                   -- ClockTime's representation, the clock (rhc's)

-- ClockTime is PreludeBuiltin's: seconds since 1970-01-01 00:00 UTC, and
-- picoseconds (overlay ov.time.clocktime)
instance Ord  ClockTime where
    compare (ClockTime s p) (ClockTime s' p') = compare (s, p) (s', p')
instance Eq   ClockTime where
    ClockTime s p == ClockTime s' p' = s == s' && p == p'

data Month =  January   | February | March    | April
           |  May       | June     | July     | August
           |  September | October  | November | December
           deriving (Eq, Ord, Enum, Bounded, Ix, Read, Show)

data Day   =  Sunday | Monday  | Tuesday  | Wednesday | Thursday 
           |  Friday | Saturday
           deriving (Eq, Ord, Enum, Bounded, Ix, Read, Show)

data CalendarTime = CalendarTime {
                ctYear                          :: Int,
                ctMonth                         :: Month,
                ctDay, ctHour, ctMin, ctSec     :: Int,
                ctPicosec                       :: Integer,
                ctWDay                          :: Day,
                ctYDay                          :: Int,
                ctTZName                        :: String,
                ctTZ                            :: Int,
                ctIsDST                         :: Bool
        } deriving (Eq, Ord, Read, Show)

data TimeDiff = TimeDiff {
                tdYear, tdMonth, tdDay, tdHour, tdMin, tdSec :: Int,
                tdPicosec                                    :: Integer
        } deriving (Eq, Ord, Read, Show)


getClockTime            :: IO ClockTime
getClockTime            =  time_now >>= \t ->     -- microseconds
                           return (ClockTime (toInteger t `div` 1000000)
                                             (toInteger t `mod` 1000000 * 1000000))

addToClockTime          :: TimeDiff     -> ClockTime -> ClockTime
addToClockTime (TimeDiff year mon day hour min sec psec) (ClockTime s p) =
                           let (carry, p') = (p + psec) `divMod` 1000000000000
                               s' = s + carry + toInteger (sec + 60 * min + 3600 * hour + 86400 * day)
                               cal = toUTCTime (ClockTime s' p')
                               (years, m) = (fromEnum (ctMonth cal) + mon + 12 * year) `divMod` 12
                           in  toClockTime (cal { ctYear = ctYear cal + years, ctMonth = toEnum m })

diffClockTimes          :: ClockTime    -> ClockTime -> TimeDiff
diffClockTimes (ClockTime s1 p1) (ClockTime s2 p2) =
                           TimeDiff 0 0 0 0 0 (fromInteger (s1 - s2)) (p1 - p2)

toCalendarTime          :: ClockTime    -> IO CalendarTime
toCalendarTime (ClockTime s p) =
                           let t = fromInteger s in
                           date_offset t >>= \off ->
                           date_zone_name t >>= \name ->
                           date_is_dst t >>= \dst ->
                           return (calendar s p off (primUnpackStr name) dst)

toUTCTime               :: ClockTime    -> CalendarTime
toUTCTime (ClockTime s p) = calendar s p 0 "UTC" False

toClockTime             :: CalendarTime -> ClockTime
toClockTime (CalendarTime year mon day hour min sec psec _ _ _ tz _) =
                           let (carry, p) = psec `divMod` 1000000000000
                           in  ClockTime (daysFrom (toInteger year) (fromEnum mon + 1) day * 86400
                                          + toInteger (3600 * hour + 60 * min + sec - tz) + carry)
                                         p

-- The time `s` seconds and `p` picoseconds after the epoch, `off` seconds
-- ahead of UTC, in the zone `name`, in summer time or not; by the
-- Gregorian calendar, before 1582 too
calendar                :: Integer -> Integer -> Int -> String -> Bool -> CalendarTime
calendar s p off name dst =
                           let local = s + toInteger off
                               days = local `div` 86400
                               t = fromInteger (local `mod` 86400)
                               (y, m, d) = dateOf days
                           in  CalendarTime { ctYear = fromInteger y, ctMonth = toEnum (m - 1), ctDay = d,
                                              ctHour = t `div` 3600, ctMin = t `mod` 3600 `div` 60,
                                              ctSec = t `mod` 60, ctPicosec = p,
                                              ctWDay = toEnum (fromInteger ((days + 4) `mod` 7)),
                                              ctYDay = fromInteger (days - daysFrom y 1 1),
                                              ctTZName = name, ctTZ = off, ctIsDST = dst }

-- the days from 1970-01-01 to a year, a month (1 to 12) and a day, and the
-- date of a day (H. Hinnant's algorithms)
daysFrom                :: Integer -> Int -> Int -> Integer
daysFrom y m d          =  let y' = if m <= 2 then y - 1 else y
                               era = y' `div` 400
                               yoe = y' - era * 400
                               mp = toInteger ((m + 9) `mod` 12)
                               doy = (153 * mp + 2) `div` 5 + toInteger d - 1
                               doe = yoe * 365 + yoe `div` 4 - yoe `div` 100 + doy
                           in  era * 146097 + doe - 719468

dateOf                  :: Integer -> (Integer, Int, Int)
dateOf z                =  let z' = z + 719468
                               era = z' `div` 146097
                               doe = z' - era * 146097
                               yoe = (doe - doe `div` 1460 + doe `div` 36524 - doe `div` 146096) `div` 365
                               doy = doe - (365 * yoe + yoe `div` 4 - yoe `div` 100)
                               mp = (5 * doy + 2) `div` 153
                               d = fromInteger (doy - (153 * mp + 2) `div` 5 + 1)
                               m = fromInteger (if mp < 10 then mp + 3 else mp - 9)
                           in  (yoe + era * 400 + (if m <= 2 then 1 else 0), m, d)

calendarTimeToString    :: CalendarTime -> String
calendarTimeToString    =  formatCalendarTime defaultTimeLocale "%c"

formatCalendarTime :: TimeLocale -> String -> CalendarTime -> String
formatCalendarTime l fmt ct@(CalendarTime year mon day hour min sec sdec 
                                           wday yday tzname _ _) =
        doFmt fmt
  where doFmt ('%':c:cs) = decode c ++ doFmt cs
        doFmt (c:cs) = c : doFmt cs
        doFmt "" = ""

        to12 :: Int -> Int
        to12 h = let h' = h `mod` 12 in if h' == 0 then 12 else h'

        decode 'A' = fst (wDays l  !! fromEnum wday)
        decode 'a' = snd (wDays l  !! fromEnum wday)
        decode 'B' = fst (months l !! fromEnum mon)
        decode 'b' = snd (months l !! fromEnum mon)
        decode 'h' = snd (months l !! fromEnum mon)
        decode 'C' = show2 (year `quot` 100)
        decode 'c' = doFmt (dateTimeFmt l)
        decode 'D' = doFmt "%m/%d/%y"
        decode 'd' = show2 day
        decode 'e' = show2' day
        decode 'H' = show2 hour
        decode 'I' = show2 (to12 hour)
        decode 'j' = show3 yday
        decode 'k' = show2' hour
        decode 'l' = show2' (to12 hour)
        decode 'M' = show2 min
        decode 'm' = show2 (fromEnum mon+1)
        decode 'n' = "\n"
        decode 'p' = (if hour < 12 then fst else snd) (amPm l)
        decode 'R' = doFmt "%H:%M"
        decode 'r' = doFmt (time12Fmt l)
        decode 'T' = doFmt "%H:%M:%S"
        decode 't' = "\t"
        decode 'S' = show2 sec
        decode 's' = case toClockTime ct of ClockTime s _ -> show s   -- seconds since the epoch (rhc's)
        decode 'U' = show2 ((yday + 7 - fromEnum wday) `div` 7)
        decode 'u' = show (let n = fromEnum wday in 
                           if n == 0 then 7 else n)
        decode 'V' = 
            let (week, days) = 
                   (yday + 7 - if fromEnum wday > 0 then 
                               fromEnum wday - 1 else 6) `divMod` 7
            in  show2 (if days >= 4 then
                          week+1 
                       else if week == 0 then 53 else week)

        decode 'W' = 
            show2 ((yday + 7 - if fromEnum wday > 0 then 
                               fromEnum wday - 1 else 6) `div` 7)
        decode 'w' = show (fromEnum wday)
        decode 'X' = doFmt (timeFmt l)
        decode 'x' = doFmt (dateFmt l)
        decode 'Y' = show year
        decode 'y' = show2 (year `rem` 100)
        decode 'Z' = tzname
        decode '%' = "%"
        decode c   = [c]

show2, show2', show3 :: Int -> String
show2 x = [intToDigit (x `quot` 10), intToDigit (x `rem` 10)]

show2' x = if x < 10 then [ ' ', intToDigit x] else show2 x

show3 x = intToDigit (x `quot` 100) : show2 (x `rem` 100)

