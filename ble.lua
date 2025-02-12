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

local function didUpdateState(self, cmd, central)
    local state = central.state
    C.NSLog(NSString("Central state %d"), state)
    if (state == CBManagerStatePoweredOn) then
        C.NSLog(NSString("Central manager powered on, starting scan"))
        central:scanForPeripheralsWithServices_options(nil, nil)
    end
end

local function didDiscoverPeripheral(self, cmd, central, peripheral,
                                     advertisement_data, rssi)
    -- local ch8 = NSString("CH-8")
    local ch8 = NSString("Foldy Boy")
    local name = peripheral.name
    C.NSLog(NSString("Discovered peripheral: %@"), name)
    if name and name:isEqualToString(ch8) == YES then
        C.NSLog(NSString("Matched name: %@, stopping scan and connecting"), ch8)
        App.peripheral = peripheral:retain() -- connect will not succeed if peripheral is dropped
        central:stopScan()
        central:connectPeripheral_options(peripheral, nil)
    end
end

local function didConnectPeripheral(self, cmd, central, peripheral)
    C.NSLog(NSString("Connected to peripheral: %@"), peripheral.name)
    peripheral.delegate = App.delegate
    peripheral:discoverServices(nil)
end

local function didFailToConnectPeripheral(self, cmd, central, peripheral, error)
    C.NSLog(NSString("Failed to connect to peripheral: %@, Error: %@"), peripheral.name, error)
end

local function didDiscoverServices(self, cmd, peripheral, error)
    if objc.ptr(error) then
        C.NSLog(NSString("Error discovering services: %@"), error)
        return
    end

    C.NSLog(NSString("Discovered services:"))
    local services = peripheral.services -- NSArray<CBService*>*
    for i = 0, tonumber(services.count) - 1 do
        local service = services:objectAtIndex(i)
        C.NSLog(NSString("  %@"), service.UUID)
    end
end

local function makeDelegate()
    local delegate_class = objc.newClass("CentralManagerDelegate")
    delegate_class:addMethod("centralManagerDidUpdateState:", "v@:@", didUpdateState)
    delegate_class:addMethod("centralManager:didDiscoverPeripheral:advertisementData:RSSI:", "v@:@@@@",
        didDiscoverPeripheral)
    delegate_class:addMethod("centralManager:didConnectPeripheral:", "v@:@@", didConnectPeripheral)
    delegate_class:addMethod("centralManager:didFailToConnectPeripheral:error:", "v@:@@@",
        didFailToConnectPeripheral)
    delegate_class:addMethod("peripheral:didDiscoverServices:", "v@:@@", didDiscoverServices)
    return objc.CentralManagerDelegate:alloc():init()
end


local function main()
    App.delegate = makeDelegate()
    local queue = ffi.cast("id", C._dispatch_main_q)
    local central = objc.CBCentralManager:alloc():initWithDelegate_queue(App.delegate, queue)

    C.CFRunLoopRun()
end

main()
