# XML reference checks

The portable SML recipe generates each profile using its exact seed and
byte target. Python ElementTree independently parses the resulting XML,
counts all elements and attributes, and agrees with both start/end callback
counts reported by the original fxp parser compiled on MLton.

REFERENCE smoke 79 79 131
REFERENCE normal 11362 11362 17000
REFERENCE large 45290 45290 67933

The benchmark generates a fresh input.xml for every invocation; this recipe
and its parameter tuple identify the input, rather than the old awk bytes.
