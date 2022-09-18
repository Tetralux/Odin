package net_server_sync

import "core:net"
import "core:fmt"
import "core:thread"
import sync "core:sync/sync2"
import "core:intrinsics"

Client :: struct {
    skt: net.TCP_Socket,
    ep: net.Endpoint,
    done: bool,
}

clients: [dynamic]Client


main :: proc() {
    using fmt

    lprintf :: proc(format: string, args: ..any) {
        @static m: sync.Mutex
        sync.mutex_lock(&m)
        defer sync.mutex_unlock(&m)
        fmt.printf(format, ..args)
    }

    acquire_client_index :: proc() -> int {
        for _, i in clients {
            if sync.atomic_exchange(&clients[i].done, false) {
                assert(clients[i].done == false)
                lprintf("[info] reusing index %v\n", i)
                return i
            }
        }
        append_nothing(&clients)
        return len(clients) - 1
    }

    release_client_index :: proc(index: int) {
        sync.atomic_store(&clients[index].done, true)
    }


    pool := &thread.Pool{}
    thread.pool_init(pool, 4)
    thread.pool_start(pool)

    server, err := net.listen_tcp({net.IP4_Loopback, 9000})
    if err != nil do panicf("listen failed: %v", err)

    reserve(&clients, 32)

    for {
        lprintf("[info] waiting for clients...\n")
        cl, ep, err := net.accept_tcp(server)
        if err != nil {
            lprintf("[info] accept failed: %v (%v)\n", err, int(err.(net.Accept_Error)))
            break
        }
        lprintf("[info] accepted from %v\n", net.endpoint_to_string(ep))

        client_index := acquire_client_index()
        clients[client_index] = Client {
            skt = cl,
            ep = ep,
        }

        thread.pool_add_task(pool, proc(task: ^thread.Task) {
            client := clients[task.user_index]
            cl, ep := client.skt, client.ep
            defer {
                net.close(cl)
                lprintf("[%v] disconnected\n", net.endpoint_to_string(ep))
                release_client_index(task.user_index)
            }

            buf: [8192]u8
            nr, recverr := net.recv(cl, buf[:])
            if recverr != nil {
                lprintf("[%v] failed to recv: %v\n", net.endpoint_to_string(ep), recverr)
                return
            }

            lprintf("[%v] received %v bytes\n", net.endpoint_to_string(ep), nr)

            out := buf[:nr]
            nw, senderr := net.send(cl, out)
            if senderr != nil {
                lprintf("[%v] failed to send: %v\n", net.endpoint_to_string(ep), senderr)
                return
            }

            lprintf("[%v] wrote %v bytes\n", net.endpoint_to_string(ep), nw)
        }, nil, client_index)
    }
}