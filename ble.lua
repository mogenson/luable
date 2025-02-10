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

-- constants
local CBManagerStatePoweredOn = ffi.new("NSInteger", 5)
local YES = ffi.new("BOOL", 1)

-- globals
local central_manager = nil

local function NSString(str)
    return objc.NSString:stringWithUTF8String(str)
end

local function centralManagerDidUpdateState_(self, cmd, central)
    local state = central.state
    C.NSLog(NSString("central state %d"), state)
    if (state == CBManagerStatePoweredOn) then
        C.NSLog(NSString("central manager powered on, starting scan"))
        local services = ffi.new("id") -- null pointer
        local options = ffi.new("id")  -- null pointer
        central_manager:scanForPeripheralsWithServices_options_(services, options)
    end
end

local function centralManager_didDiscoverPeripheral_advertisementData_RSSI_(self, cmd, central, peripheral,
                                                                            advertisement_data, rssi)
    -- local ch8 = NSString("CH-8")
    local ch8 = NSString("Govee_H6076_1959")
    local name = peripheral.name
    C.NSLog(NSString("discovered peripheral %@"), name)
    if name and name:isEqualToString_(ch8) == YES then
        C.NSLog(NSString("found %@, stopping scan"), ch8)
        central_manager:stopScan()
    end
end

local function makeDelegate()
    local delegate_class = objc.newClass("CentralManagerDelegate")
    objc.addMethod(delegate_class, "centralManagerDidUpdateState:", "v@:@", centralManagerDidUpdateState_)
    objc.addMethod(delegate_class, "centralManager:didDiscoverPeripheral:advertisementData:RSSI:", "v@:@@@@",
        centralManager_didDiscoverPeripheral_advertisementData_RSSI_)
    return objc.CentralManagerDelegate:alloc():init()
end


local function main()
    local delegate = makeDelegate()
    local queue = ffi.cast("id", C._dispatch_main_q)
    central_manager = objc.CBCentralManager:alloc():initWithDelegate_queue_(delegate, queue)

    C.CFRunLoopRun()
end

main()
