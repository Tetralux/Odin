package main

import "core:fmt"
import "core:bufio"
import "core:os"
import "core:io"

main :: proc() {
	using fmt

	s := "hello"
	t := "hello"
	println(s, t)

	s2 := transmute([]byte) s
	s2[0] = 'W'

	println(s, t)


	// stream := os.stream_from_handle(os.stdin);
	// r: bufio.Reader;
	// bufio.reader_init(&r, io.Reader{stream});
	// s, err := bufio.reader_read_string(&r, '\n');
	// assert(err == .None);
	// fmt.println(s);

	// {

	// 	checked_cast :: proc ($TO: typeid, value: $FROM) -> TO {
	// 	    when size_of(TO) <= size_of(FROM) {
	// 	    	low := min(TO)
	// 	    	hi := max(TO)
	// 	        if value < FROM(low) || value > FROM(hi) {
	// 	            panic("cast truncated bits")
	// 	        }
	// 	    }

	// 	    return TO(value)
	// 	}


	// 	u := uint(25)
	// 	i := checked_cast(int, u)
	// 	fmt.println(1)
	// }
}


Union :: union #maybe {
	i32,
}
union_ptr :: proc() {
	some := Union(i32(1));
	none := Union(nil);

	{
		value := some.?;
		assert(value == 1);
	}

	{
		value, ok := some.?;
		assert(ok);
		assert(value == 1);
	}

	{
		ptr := &some.?;
		assert(ptr != nil);
		assert(ptr^ == 1);
	}


	// TODOS

	{
		ptr := &none.?; // TODO: should work
		assert(ptr == nil);
	}

	{
		ptr, ok := &some.?;
		assert(ok);
		assert(ptr^ == 1);
	}

}