structure ThresholdChecked =
struct
  fun literal bound = 1073741823-bound+1
  fun variable maximum bound = maximum-bound+1
  val maximum=valOf(Int.fromString(valOf(TextIO.inputLine TextIO.stdIn)))
  val _=List.app(fn(bound,expected)=>
    (T.eq Int.toString("threshold/literal-"^Int.toString bound,expected,fn()=>literal bound);
     T.eq Int.toString("threshold/variable-"^Int.toString bound,expected,fn()=>variable maximum bound)))
    [(1,1073741823),(100,1073741724),(1000000000,73741824)]
end
