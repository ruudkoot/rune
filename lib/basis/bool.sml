(* Bool *)
structure Bool =
struct
  datatype bool = datatype bool
  val not = not
  fun toString true = "true"
    | toString false = "false"
  fun fromString "true" = SOME true
    | fromString "false" = SOME false
    | fromString _ = NONE
end
