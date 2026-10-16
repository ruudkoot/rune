structure Pilot =
struct
  val strict = CommandLine.arguments () = ["strict"]
  val expected = [1780, 1780, 1790, 1798, 1797]
  val result = List.map (fn k => if strict then BenchSecretary.strict 5000 k else BenchSecretary.lazy 5000 k) [35, 36, 37, 38, 39]
  val _ = if List.map #1 result = expected then print "PASS complete original normal success vector\n"
          else raise Fail "incorrect secretary results"
end
