package spinup

import "core:fmt"
import "core:thread"
import "core:intrinsics"
import "core:time"

main :: proc() {
    start := time.tick_now()
    N :: 10_000
    for in 1..N {
        thread.run(proc() {
            time.sleep(time.Millisecond * 1000)
        })
    }
    total_time := time.duration_nanoseconds(time.tick_since(start))
    fmt.println(total_time / N, "ns")
}