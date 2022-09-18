package main

import "core:fmt"
import c "core:c"

foreign import libc "system:c";

foreign libc {
	getrlimit64 :: proc(res: Limit, rlim: ^rlimit) -> c.int ---;
}

rlimit :: struct {
	rlim_cur, rlim_max: u64,
}

Limit :: enum c.int {
	Address_Space = 9,
	Data = 2,
	Resident_Set = 5,

}


main :: proc() {
	limits: rlimit;

	for limit in Limit {
		res := getrlimit64(.Resident_Set, &limits);
		assert(res == 0);
		fmt.printf("%v / %v (%v)\n", limits.rlim_cur, limits.rlim_max, limit);
	}

}