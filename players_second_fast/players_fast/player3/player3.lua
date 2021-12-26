#!/usr/bin/env tarantool

local ffi = require('ffi')

AF_INET = 2
SOCK_STREAM = 1
SO_REUSEADDR = 2
SOL_SOCKET = 1

ffi.cdef[[
    struct in_addr {
        uint32_t s_addr;
    };

    struct sockaddr {
        uint16_t sa_family;
        char sa_data[14];
    };
    struct sockaddr_in {
        uint16_t sin_family;
        uint16_t sin_port;
        struct in_addr sin_addr;
        char sin_zero[8];
    };

    int socket(int domain, int type, int protocol);
    int bind(int sockfd, const struct sockaddr *addr,
                socklen_t addrlen);
    int close(int s);

    uint16_t htons(uint16_t hostshort);

    int setsockopt(int s, int level, int optname, const void* optval, uint32_t optlen);

    int accept(int s, struct sockaddr *, int *);
    int connect(int s, const struct sockaddr * name, int namelen);
    int listen(int s, int backlog);
    int recv(int s, char* buf, int len, int flags);
    int send(int s, const char* buf, int len, int flags);

    typedef void (*sighandler_t)(int32_t);
    extern sighandler_t signal(int32_t signum, sighandler_t handler);
    void exit(int status);
]]

local SIGINT = 2
local handler = ffi.C.signal(SIGINT, ffi.C.exit)

while true do
    local s = ffi.C.socket(AF_INET, SOCK_STREAM, 0)
    if s < 0 then
        print('error while create')
        return
    end

    val = ffi.new("int[1]", 1)
    ffi.C.setsockopt(s, SOL_SOCKET, SO_REUSEADDR, val, ffi.sizeof(val))

    local address = ffi.new("struct sockaddr_in[1]",
        {{
            sin_family=AF_INET,
            sin_addr = {s_addr=0},
            sin_port = ffi.C.htons(8081),
            sin_zero = {0,0,0,0,0,0,0,0}
        }})

    local rc = ffi.C.bind(s, ffi.cast('const struct sockaddr *', address), ffi.sizeof(address))
    if rc == -1 then
        print('error while bind')
        return
    end

    local rc = ffi.C.listen(s, 1)
    if rc < 0 then
        print('error while listen')
        return
    end

    local address = ffi.new("struct sockaddr_in[1]")
    local client = ffi.C.accept(s, ffi.cast("struct sockaddr *", address),
                                ffi.new("unsigned int[1]", ffi.sizeof(address)))
    if client < 0 then
        print('error while accept')
        return
    end

    local len = ffi.C.send(client, 'thebot++++++', 10, 0)
    if len <= 0 then
        print('error while send')
        return
    end

    local actions = {
        "hit",
        "hooking",
        "squat",
        "jump",
    }

    math.randomseed(require('fiber').time())

    while true do
        local health = ffi.new("char[10]", {0, 0, 0})
        local len = ffi.C.recv(client, health, 1, 0)
        if len <= 0 then
            break
        end
        print(ffi.string(health))
        action = actions[math.random(4)]
        local len = ffi.C.send(client, action, 3, 0)
        if len <= 0 then
            break
        end
    end

    ffi.C.close(client)
    ffi.C.close(s)
end