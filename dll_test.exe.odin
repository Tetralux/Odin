package main

import "core:dynlib"

main :: proc() {
	lib, ok1 := dynlib.load_library("./mylib.so", false);
	assert(ok1, "cant load lib");

	ptr, ok2 := dynlib.symbol_address(lib, "my_lib_foo");
	assert(ok2, "cant find symbol");

	fn := cast(proc "c" ()) ptr;
	fn();
}
