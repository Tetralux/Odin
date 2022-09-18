package test

import "core:fmt"
import "core:os"

main :: proc() {
	out: [dynamic]byte
	buf: [4096]byte

	for {
		n, err := os.read(os.stdin, buf[:])
		if err != 0 {
			fmt.eprintf("error reading stdin: %v\n", err)
			os.exit(1)
		}
		fmt.eprintln(n)
		if n == 0 {
			break
		}
		append(&out, ..buf[:n])
	}
	fmt.println("DONE")
	fmt.println(string(out[:]))
}