#!/usr/bin/env luajit

local objc = require("objc")
objc.loadFramework("Foundation")
objc.loadFramework("CoreBluetooth")

local ffi = require("ffi")
local C = ffi.C

ffi.cdef([[
struct dispatch_queue_s _dispatch_main_q; // global from dispatch/queue.h
void CFRunLoopRun(void);
void NSLog(id, ...);
]])

local CBManagerStatePoweredOn = ffi.new("NSInteger", 5)

local central_manager = nil

local function NSString(str)
    return objc.NSString:stringWithUTF8String(str)
end


local function main()
    local delegate_class = objc.newClass("CentralManagerDelegate")
    objc.addMethod(delegate_class, "centralManagerDidUpdateState:", "v@:@",
        function(self, cmd, central)
            local state = central.state
            C.NSLog(NSString("central state %d"), state)
            if (state == CBManagerStatePoweredOn) then
                print("central manager powered on")
            end
        end)
    local delegate = objc.CentralManagerDelegate:alloc():init()
    local queue = ffi.cast("id", C._dispatch_main_q)
    central_manager = objc.CBCentralManager:alloc():initWithDelegate_queue_(delegate, queue)

    C.CFRunLoopRun()
end

main()
