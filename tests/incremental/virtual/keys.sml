structure IntOrd =
struct
  type t = int
  val compare = Int.compare
  val show = Int.toString
end

structure StringOrd =
struct
  type t = string
  val compare = String.compare
  fun show s = s
end
