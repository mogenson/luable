local ffi = require("ffi")
local bit = require("bit")

local C = ffi.C

local debug = true

ffi.cdef([[
struct pollfd {
    int fd;
    short events;
    short revents;
};

struct sockaddr {
    uint16_t sa_family;
    char sa_data[14];
};

int ioctl(int fd, int request, ...);
char *strerror(int errnum);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
int close(int fd);
int socket(int domain, int type, int protocol);
int bind(int sockfd, struct sockaddr *addr, int addrlen);
int write(int fd, const char* buf, int len);
int read(int fd, char* buf, int len);
]])

local function const(t)
    return setmetatable({}, {
        __index = t,
        __newindex = function(t, k, v)
            error("tried to overwrite constant " .. k .. " with " .. v, 2)
        end
    })
end

local socket = {
    constants = const({
        POLLIN = 0x0001,
        AF_BLUETOOTH = 31,
        BTPROTO_HCI = 1,
        SOCK_RAW = 3,
        SOCK_CLOEXEC = 0x80000,
        SOCK_NONBLOCK = 0x800,
        HCI_CHANNEL_USER = 1,
    }),
}

function socket:poll(fds, nfds, timeout)
    local ret = C.poll(fds, nfds, timeout)
    if ret < 0 then
        return nil, ffi.string(C.strerror(ffi.errno()))
    end
    return ret
end

function socket:close(fd)
    if fd and type(fd) == "number" and fd > 0 then
        C.close(fd)
    end
end

function socket:open(dev)
    --[[
SOCK_RAW 3 SOCK_CLOEXEC 524288 SOCK_NONBLOCK 2048 BTPROTO_HCI 1
HCIDEVDOWN 1074022602    0x400448ca
NEED TO DO IOCTL
  if(dd >= 0)
    {
    if(ioctl(dd,HCIDEVDOWN,gpar.devid) >= 0)  // hci0
      retval = 1;
    close(dd);
    }

]]
    --
    local fd = C.socket(self.constants.AF_BLUETOOTH,
        bit.bor(self.constants.SOCK_RAW, self.constants.SOCK_CLOEXEC, self.constants.SOCK_NONBLOCK),
        self.constants.BTPROTO_HCI)
    if fd < 0 then
        return nil, ffi.string(C.strerror(ffi.errno()))
    end

    local sockaddr = ffi.new("char[6]")
    sockaddr[0] = self.constants.AF_BLUETOOTH
    sockaddr[1] = 0
    sockaddr[2] = bit.band(dev, 0xFF)
    sockaddr[3] = bit.band(bit.rshift(dev, 8), 0xFF)
    sockaddr[4] = self.constants.HCI_CHANNEL_USER
    sockaddr[5] = 0

    if C.bind(fd, ffi.cast("struct sockaddr*", sockaddr), ffi.sizeof(sockaddr)) < 0 then
        local err = ffi.string(C.strerror(ffi.errno()))
        self.close(fd)
        return nil, err
    end

    return fd
end

function socket:write(fd, buf, len)
    if debug then
        io.write("send:")
        for i = 0, len - 1 do io.write(string.format(" %02X", buf[i])) end
        io.write("\n")
    end

    local bytes_out = 0
    while bytes_out < len do
        local ret = C.write(fd, buf, len)
        if (ret < 0) then
            return nil, ffi.string(C.strerror(ffi.errno()))
        end
        bytes_out = bytes_out + ret
    end

    return bytes_out
end

function socket:read(fd, buf, len)
    local bytes_in = 0
    while bytes_in < len do
        local ret = C.read(fd, buf + bytes_in, len)
        if (ret < 0) then
            return nil, ffi.string(C.strerror(ffi.errno()))
        end
        bytes_in = bytes_in + ret
    end
    if debug then
        io.write("recv:")
        for i = 0, len - 1 do io.write(string.format(" %02X", buf[i])) end
        io.write("\n")
    end
    return bytes_in
end

local hci = {
    constants = const({
        HCI_COMMAND = 1,
        HCI_ACL_DATA = 2,
        HCI_SYNC_DATA = 3,
        HCI_EVENT = 4,
        HCI_ISO_DATA = 5,
    }),
}

function hci:command(ocf, ogf, data)
    data = data or {}
    local len = #data
    if (len > 0xFF) then return nil, "data len too long" end
    local buf = ffi.new("char[?]", len + 4)
    buf[0] = hci.constants.HCI_COMMAND
    buf[1] = bit.band(ocf, 0xFF)
    buf[2] = bit.bor(bit.band(bit.lshift(ogf, 2), 0xFC), bit.band(bit.rshift(ocf, 8), 0x03))
    buf[3] = len
    for i, v in ipairs(data) do
        buf[i + 3] = v
    end
    return buf, len + 4
end

function hci:reset()
    return assert(self:command(0x0003, 0x03))
end

local ble = {
    --fd = nil,
    --tx_buf = ffi.new("char[255]"),
    --rx_buf = ffi.new("char[255]"),
}



local function main()
    if debug then print("stopping bluez") end
    os.execute("hciconfig hci down")
    os.execute("service bluetooth stop")
    os.execute("sleep 1")

    local fd = assert(socket:open(0))
    local cmd, len = hci:reset()
    assert(socket:write(fd, cmd, len))
    os.execute("sleep 0.1")
    len = 7
    local buf = ffi.new("char[?]", len)
    len = assert(socket:read(fd, buf, len))
    print("read len", len)
end

main()
