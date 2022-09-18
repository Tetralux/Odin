package test_sync

import "core:sync"
import "core:time"
import "core:fmt"
import "core:thread"

main :: proc() {
	m: sync.Mutex;
	c: sync.Condition;
	sync.condition_init(&c, &m);

	t := thread.create(proc(t: ^thread.Thread) {
		m := (^sync.Condition)(t.data);
		sync.condition_wait_for(m);
		fmt.println(2);
	}, .Normal);

	t.data = &c;
	thread.start(t);

	time.sleep(1 * time.Second);

	fmt.println(11);
	sync.condition_signal(&c);
	fmt.println(12);

	thread.join(t);

	fmt.println(13);
}