(* Report wording retained from the original collector score schema. *)
structure MeasureScoreText =
struct
  val ratios = "Ratios are candidate / baseline of each run's round with the least task-clock (below 1 is better); the other columns are baseline -> candidate of those rounds. A pause varies from round to round (the first touch of a new space, the host): the range of the longest over every round of both VMs is beside them."
  val none = "None: every run exited 0, every program of examples/benchmarks printed PASS, and every output and every count of bytes and objects allocated is the baseline's."
  val weight_note = "Each score is the weighted geometric mean of the groups present, divided by the weight present (T %d, M %d, P %d of the set's 100, 95 and 95: the set's M and P columns sum to 95, a slip found after it was fixed, so a full run divides those two by 95)."
end
