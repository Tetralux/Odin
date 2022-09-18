package main

import "core:mem/virtual"
import "core:fmt"
import "core:mem"

main :: proc() {
	using fmt;

	a: virtual.Arena;
	ok := virtual.arena_init(&a, mem.gigabytes(3));
	assert(ok);
	allocator := virtual.arena_allocator(&a);

	for i := 1; true; i += 1 {
		buf := make([]byte, mem.megabytes(4));
		if buf == nil {
			break;
		}
		println(i);
	}
}
