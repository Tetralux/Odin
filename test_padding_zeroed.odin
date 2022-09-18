package main

import "core:fmt"
import "core:mem"

S :: struct {
	i: i32,
	u: u64,
};

main :: proc() {
	using fmt;

	u : uint = 11;
	i := int(u);
	fmt.printf("%v\n", mem.ptr_to_bytes(&i, 1));


	s: S;

	data := mem.ptr_to_bytes(&s);
	for b, i in &data {
		b = 0xaa;
	}

	print_bytes(&s);
	println(s);

	// s.i = 0;
	// s.u = 0;
	s =  {};

	print_bytes(&s);
	println(s);
}

print_bytes :: proc(s: ^S) {
	data := mem.ptr_to_bytes(s, 1);
	fmt.printf("%x\n", data);
}
