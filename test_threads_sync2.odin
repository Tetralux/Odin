package test_threads;

import "core:thread";
import "core:fmt";
import "core:time";
import "core:sync/sync2";
import "core:intrinsics";
import "core:os";
import "core:math/rand";

stop: bool;
work_completed: int;

thread_proc :: proc(t: ^thread.Thread) {
    using fmt;

    println("IN THE THREAD");
    ss := tprintf("Hello, %v", "World!");
    printf("%p\n", transmute([]byte) ss);

    time.sleep(time.Duration(4) * time.Second);
    s := (^sync2.Sema)(t.data);
    for {
        sync2.sema_wait(s);
        if stop do break;
        println("DOING WORK", work_completed+1);
        time.sleep(time.Duration(rand.float64()*1500) * time.Millisecond);
        work_completed += 1;
    }
    println("END OF THREAD");
    return;
}

main :: proc() {
    using fmt;

    ss := tprintf("Hello, %v", "World!");
    printf("%p\n", transmute([]byte) ss);


    page_size := os.get_page_size();
    println(page_size);

    println("creating thread");
    t := thread.create(thread_proc);
    assert(t != nil);

    se : sync2.Sema;
    t.data = &se;

    println("waiting");
    time.sleep(time.Duration(2) * time.Second);

    println("starting");
    thread.start(t);

    time.sleep(time.Duration(2) * time.Second);

    for i in 1..8 {
        time.sleep(time.Duration(500) * time.Millisecond);
        println("posting work", i);
        sync2.sema_post(&se);
    }

    assert(!thread.is_done(t)); // the thread is still doing the work at this point.

    for work_completed < 8 do intrinsics.cpu_relax();

    stop = true;
    sync2.sema_post(&se);

    println("joining");
    thread.join(t);
    time.sleep(time.Duration(500) * time.Millisecond);

    assert(thread.is_done(t));

    println("done");
}


// thread_proc :: proc "c" (t: rawptr) -> rawptr {
//  (^i32)(t)^ = 42;
//  println("IN THE THREAD");
//  println("END OF THREAD");
//  return rawptr(uintptr(1));
// }

// import "core:sys/linux";

// main :: proc() {
//  attrs: linux.pthread_attr_t;
//  assert(linux.pthread_attr_init(&attrs) == 0);
//  assert(linux.pthread_attr_setdetachstate(&attrs, linux.PTHREAD_CREATE_JOINABLE) == 0);

//  t: linux.pthread_t;
//  arg: u64; // The value the thread modifies.

//  assert(linux.pthread_create(&t, &attrs, thread_proc, &arg) == 0);

//  retval: ^i32; // The return result of the thread.
//  res := linux.pthread_join(t, rawptr(&retval));
//  if res != 0 do panicf("pthread_join faile with code %v\n", res);

//  if arg != 42 do panicf("arg not set to 42; got %v", arg);
//  if int(uintptr(retval)) != 1 do panicf("return value of worker should be 1; got %v", retval);

//  println("done!");
// }