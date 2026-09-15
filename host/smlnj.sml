structure SMLNJMain =
struct
  fun main (name, args) = Main.main (name, List.map (fn arg =>
    if String.isPrefix "rune:" arg then String.extract (arg, 5, NONE)
    else raise Fail "invalid Rune launcher argument") args)
end
