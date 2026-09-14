signature RUNE_SOURCE_SPAN =
sig
  type t
  val make : {start : int, finish : int} -> t
  val start : t -> int
  val finish : t -> int
end

signature RUNE_DIAGNOSTIC =
sig
  datatype severity = Error | Warning | Note
  type t
  val make : {severity : severity, code : string,
              span : RUNE_SOURCE_SPAN.t, message : string} -> t
end

signature RUNE_COMPILER_PHASE =
sig
  datatype ('a, 'b) result = Ok of 'a | Error of 'b
  type input
  type output
  type error
  val run : input -> (output, error) result
end
