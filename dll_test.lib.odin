package main

import "core:fmt"
import "core:runtime"

@export
my_lib_foo :: proc "c" () {
	context = runtime.default_context();
	fmt.println("my_lib_foo");
}
