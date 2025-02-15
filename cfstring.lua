local ffi = require("ffi")

-- Define the necessary Core Foundation types and functions
ffi.cdef[[
typedef struct __CFString *CFStringRef;
typedef struct __CFAllocator *CFAllocatorRef; // Define CFAllocatorRef
typedef long CFIndex;
typedef enum {
    kCFStringEncodingUTF8 = 0x0800,  // UTF-8 encoding
} CFStringEncoding;
typedef void *CFTypeRef;

CFIndex CFStringGetLength(CFStringRef string);
CFStringRef CFStringCreateWithCString(CFAllocatorRef allocator, const char *cStr, CFStringEncoding encoding);
void CFShow(CFTypeRef obj);  // For quick printing (stderr)
void CFRelease(CFTypeRef cf);
CFStringRef CFStringCreateWithBytes(CFAllocatorRef alloc, const uint8_t *bytes, CFIndex numBytes, CFStringEncoding encoding, bool isExternalRepresentation);
const char *CFStringGetCStringPtr(CFStringRef theString, CFStringEncoding encoding);
]]

ffi.load("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")

-- Create a C string
local c_string = ffi.new("const char*", "Hello from LuaJIT!")
--local c_string = ffi.new("const uint8_t[5]", "hello")

-- Create a CFString from the C string
local cf_string = ffi.C.CFStringCreateWithCString(nil, c_string, ffi.C.kCFStringEncodingUTF8)
if cf_string == nil then print("cfstring is null") end
--local cf_string = ffi.C.CFStringCreateWithBytes(nil, c_string, 5, ffi.C.kCFStringEncodingUTF8, false)

-- Print the CFString (using CFShow for demonstration)
print("A")
ffi.C.CFShow(cf_string)  -- Output to stderr
print("B")

local ptr = ffi.C.CFStringGetCStringPtr(cf_string, ffi.C.kCFStringEncodingUTF8)
if ptr == nil then print("ptr is null") end
print(ffi.string(ptr))
os.exit()

-- Convert to C string and print using printf (more control over stdout)
local c_string_from_cf = ffi.string(cf_string, ffi.C.CFStringGetLength(cf_string)) -- Important!

print("String from CFString (stdout):", c_string_from_cf)


-- **CRITICAL:** Release the CFString when done!
ffi.C.CFRelease(cf_string)



-- Example of dynamic CFString creation (and release)
local dynamic_cf_string = ffi.C.CFStringCreateWithCString(nil, "Dynamic String", ffi.C.kCFStringEncodingUTF8)
ffi.C.CFShow(dynamic_cf_string)
ffi.C.CFRelease(dynamic_cf_string)
