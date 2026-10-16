structure Pilot =
struct
  val strict = CommandLine.arguments () = ["strict"]
  val expected = [173, 175, 179, 177, 170]
  val result = List.map (fn k => if strict then BenchSecretary.strict 500 k else BenchSecretary.lazy 500 k) [35, 36, 37, 38, 39]
  val _ = if List.map #1 result = expected then print "PASS complete original normal success vector\n"
          else raise Fail "incorrect secretary results"
end
