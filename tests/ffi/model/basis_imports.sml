(* Only the Basis structures named by the public signature goldens.
   Datatype constructors named Text or Timer do not import those modules. *)
structure ProjectionInt32 = Int32
structure ProjectionInt64 = Int64
structure ProjectionWord16 = Word16
structure ProjectionWord32 = Word32
structure ProjectionWord64 = Word64
structure ProjectionBytes = Word8Array
