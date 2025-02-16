#!/usr/bin/env luajit

local objc = require("objc")
local cf = require("cf")
objc.loadFramework("Foundation")
objc.loadFramework("CoreBluetooth")
objc.loadFramework("CoreMIDI")

local ffi = require("ffi")
local C = ffi.C

ffi.cdef([[
struct dispatch_queue_s _dispatch_main_q; // global from dispatch/queue.h
void CFRunLoopRun(void);
void NSLog(id, ...);
]])

-- CoreMIDI
ffi.cdef([[
typedef CFIndex ItemCount;
typedef uint32_t MIDIObjectRef;
typedef MIDIObjectRef MIDIClientRef;
typedef MIDIObjectRef MIDIPortRef;
typedef MIDIObjectRef MIDIEndpointRef;
typedef struct MIDINotification MIDINotification;
typedef struct MIDIPacketList MIDIPacketList;
typedef void (*MIDINotifyProc)(const MIDINotification *message, void *refCon);
typedef void (*MIDIReadProc)(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);
OSStatus MIDIClientCreate(CFStringRef name, MIDINotifyProc notifyProc, void *notifyRefCon, MIDIClientRef *outClient);
OSStatus MIDIInputPortCreate(MIDIClientRef client, CFStringRef portName, MIDIReadProc readProc, void *refCon, MIDIPortRef *outPort);
ItemCount MIDIGetNumberOfSources(void);
MIDIEndpointRef MIDIGetSource(ItemCount sourceIndex0);
OSStatus MIDIPortConnectSource(MIDIPortRef port, MIDIEndpointRef source, void *connRefCon);
]])

-- utilities
local function NSString(str)
    return objc.NSString:stringWithUTF8String(str)
end

-- constants
local CBManagerStatePoweredOn = ffi.new("NSInteger", 5)
local CBCharacteristicWriteWithoutResponse = ffi.new("NSInteger", 1)
local YES = ffi.new("BOOL", 1)
local MidiUuid = objc.CBUUID:UUIDWithString(NSString("7772E5DB-3868-4112-A1A9-F2669D106BF3"))
--local PeripheralName = NSString("CH-8")
local PeripheralName = NSString("Foldy Boy")

-- globals
local App = {
    delegate = nil,
    peripheral = nil,
    characteristic = nil,
}

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
    local name = peripheral.name
    C.NSLog(NSString("Discovered peripheral: %@"), name)
    if name and name:isEqualToString(PeripheralName) == YES then
        C.NSLog(NSString("Matched name: %@, stopping scan and connecting"), PeripheralName)
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

local function didDisconnectPeripheral(sefl, cmd, central, peripheral)
    C.NSLog(NSString("Disconnected from peripheral: %@"), peripheral.name)
    os.exit()
end

local function didFailToConnectPeripheral(self, cmd, central, peripheral, error)
    C.NSLog(NSString("Failed to connect to peripheral: %@, Error: %@"), peripheral.name, error)
    os.exit()
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
        peripheral:discoverCharacteristics_forService(nil, service)
    end
end

local function didDiscoverCharacteristics(self, cmd, peripheral, service, error)
    if objc.ptr(error) then
        C.NSLog(NSString("Error discovering characteristics: %@"), error)
        return
    end

    C.NSLog(NSString("Discovered characteristics for service %@"), service.UUID)
    local characteristics = service.characteristics
    for i = 0, tonumber(characteristics.count) - 1 do
        local characteristic = characteristics:objectAtIndex(i)
        C.NSLog(NSString("  %@"), characteristic.UUID)
        if characteristic.UUID:isEqual(MidiUuid) == YES then
            C.NSLog(NSString("Found MIDI characteristic"))
            App.characteristic = characteristic:retain()
            local bytes = ffi.cast("const void*", ffi.new("uint8_t[5]", { 0x80, 0x80, 0x80, 0x3e, 0x7f }))
            local length = ffi.new("NSUInteger", 5)
            local data = objc.NSData:dataWithBytes_length(bytes, length)
            C.NSLog(NSString("Writing %@ to characteristic %@"), data, characteristic)
            peripheral:writeValue_forCharacteristic_type(data, characteristic, CBCharacteristicWriteWithoutResponse)
            break
        end
    end
end

local function makeDelegate()
    local delegate_class = objc.newClass("CentralManagerDelegate")
    delegate_class:addMethod("centralManagerDidUpdateState:", "v@:@", didUpdateState)
    delegate_class:addMethod("centralManager:didDiscoverPeripheral:advertisementData:RSSI:", "v@:@@@@",
        didDiscoverPeripheral)
    delegate_class:addMethod("centralManager:didConnectPeripheral:", "v@:@@", didConnectPeripheral)
    delegate_class:addMethod("centralManager:didDisconnectPeripheral:error:", "v@:@@@", didDisconnectPeripheral)
    delegate_class:addMethod("centralManager:didFailToConnectPeripheral:error:", "v@:@@@",
        didFailToConnectPeripheral)
    delegate_class:addMethod("peripheral:didDiscoverServices:", "v@:@@", didDiscoverServices)
    delegate_class:addMethod("peripheral:didDiscoverCharacteristicsForService:error:", "v@:@@@",
        didDiscoverCharacteristics)
    return objc.CentralManagerDelegate:alloc():init()
end

local function midi_input_callback(packet_list, ref_conn, conn)
    print("midi_input_callback called")
end

local function main()
    -- App.delegate = makeDelegate()
    -- local queue = ffi.cast("id", C._dispatch_main_q)
    -- local central = objc.CBCentralManager:alloc():initWithDelegate_queue(App.delegate, queue)

    if tonumber(C.MIDIGetNumberOfSources()) == 0 then
        print("No MIDI input sources")
        return
    end

    local midi_client = ffi.new("MIDIClientRef[1]", 0)
    local client_name = cf.CFString("LuaClient")
    assert(tonumber(C.MIDIClientCreate(client_name, nil, nil, midi_client)) == 0)

    local midi_port = ffi.new("MIDIPortRef[1]", 0)
    local port_name = cf.CFString("LuaPort")
    local callback = ffi.cast("MIDIReadProc", midi_input_callback)
    assert(tonumber(C.MIDIInputPortCreate(midi_client[0], port_name, callback, nil, midi_port)) == 0)

    local midi_source = C.MIDIGetSource(0)
    if midi_source == 0 then
        print("Invalid MIDI source")
        return
    end

    assert(tonumber(C.MIDIPortConnectSource(midi_port[0], midi_source, nil)) == 0)

    cf.CFRunLoopRun()
end

main()
