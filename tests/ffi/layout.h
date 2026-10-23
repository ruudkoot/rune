/* Owned C11 layout fixture. The SML frontend consumes these exact bytes. */
struct pair { int integer; double fraction; };
union variant { unsigned long long bits; double real; };
struct anonymous { char prefix; struct { int x; int y; }; double tail; };
struct matrix { char prefix; int cells[3][2]; };
struct flexible { int count; char bytes[]; };
#pragma pack(push,1)
struct packed { char prefix; int value; };
#pragma pack(pop)
struct bitfields { unsigned low:3; unsigned high:5; };
