(* Representative raw and idiomatic fixture contracts. A pointer is an
   abstract foreign resource; an address is never an SML integer. *)
signature RUNEFFI_FIXTURE_RAW =
sig
  eqtype pointer
  type pair = {integer : Int32.int, fraction : real}
  val rf_i8 : Int8.int -> Int8.int
  val rf_i64 : Int64.int -> Int64.int
  val rf_u64 : Word64.word -> Word64.word
  val rf_make_pair : Int32.int * real -> pair
  val rf_pair_total : pair -> real
  val rf_length : pointer -> Word64.word
  val rf_copy : pointer -> pointer option
  val rf_free : pointer -> unit
  val rf_set_callback : (pointer * int -> int) option * pointer -> unit
  val rf_invoke : int -> int
end

signature RUNEFFI_FIXTURE =
sig
  type pair = {integer : Int32.int, fraction : real}
  val makePair : Int32.int * real -> pair
  val pairTotal : pair -> real
  val copy : string -> string
  val withCallback : (int -> int) -> (unit -> 'a) -> 'a
  val invoke : int -> int
end
