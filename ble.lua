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
local App = {
    delegate = nil,
    peripheral = nil,
}

local function NSString(str)
    return objc.NSString:stringWithUTF8String(str)
end

local function centralManagerDidUpdateState_(self, cmd, central)
    local state = central.state
    C.NSLog(NSString("Central state %d"), state)
    if (state == CBManagerStatePoweredOn) then
        C.NSLog(NSString("Central manager powered on, starting scan"))
        local services = ffi.new("id") -- null pointer
        local options = ffi.new("id")  -- null pointer
        central:scanForPeripheralsWithServices_options_(services, options)
    end
end

local function centralManager_didDiscoverPeripheral_advertisementData_RSSI_(self, cmd, central, peripheral,
                                                                            advertisement_data, rssi)
    -- local ch8 = NSString("CH-8")
    local ch8 = NSString("Foldy Boy")
    local name = peripheral.name
    C.NSLog(NSString("Discovered peripheral: %@"), name)
    if name and name:isEqualToString_(ch8) == YES then
        C.NSLog(NSString("Matched name: %@, stopping scan and connecting"), ch8)
        App.peripheral = peripheral:retain() -- connect will not succeed if peripheral is dropped
        central:stopScan()
        local options = ffi.new("id")        -- null pointer
        central:connectPeripheral_options_(peripheral, options)
    end
end

local function centralManager_didConnectPeripheral_(self, cmd, central, peripheral)
    C.NSLog(NSString("Connected to peripheral: %@"), peripheral.name)
    peripheral.delegate = App.delegate
end

local function centralManager_didFailToConnectPeripheral_error_(self, cmd, centrl, peripheral, error)
    C.NSLog(NSString("Failed to connect to peripheral: %@, Error: %@"), peripheral.name, error)
end

local function makeDelegate()
    local delegate_class = objc.newClass("CentralManagerDelegate")
    objc.addMethod(delegate_class, "centralManagerDidUpdateState:", "v@:@", centralManagerDidUpdateState_)
    objc.addMethod(delegate_class, "centralManager:didDiscoverPeripheral:advertisementData:RSSI:", "v@:@@@@",
        centralManager_didDiscoverPeripheral_advertisementData_RSSI_)
    objc.addMethod(delegate_class, "centralManager:didConnectPeripheral:", "v@:@@", centralManager_didConnectPeripheral_)
    objc.addMethod(delegate_class, "centralManager:didFailToConnectPeripheral:error:", "v@:@@@",
        centralManager_didFailToConnectPeripheral_error_)
    return objc.CentralManagerDelegate:alloc():init()
end


local function main()
    App.delegate = makeDelegate()
    local queue = ffi.cast("id", C._dispatch_main_q)
    local central = objc.CBCentralManager:alloc():initWithDelegate_queue_(App.delegate, queue)

    C.CFRunLoopRun()
end

main()
