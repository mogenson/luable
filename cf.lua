local ffi = require("ffi")
local C = ffi.C

ffi.cdef([[
typedef const void *CFTypeRef;
typedef struct __CFAllocator *CFAllocatorRef;
typedef struct __CFString *CFStringRef;
typedef uint32_t CFStringEncoding;

CFStringRef CFStringCreateWithCString(CFAllocatorRef alloc, const char *cStr, CFStringEncoding encoding);
void CFShow(CFTypeRef obj);
]])

ffi.load("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", true)

local kCFStringEncodingASCII = ffi.new("CFStringEncoding", 0x0600)

return {
    CFString = function(str) return C.CFStringCreateWithCString(nil, str, kCFStringEncodingASCII) end,
    CFShow = C.CFShow,
}
