# luable
Read MIDI from a CoreMidi port and write it to a BLE characteristic, using LuaJIT and the FFI extension. No build step or compilation necessary. MacOS only.

This program opens the first available MIDI input port. It assumes only one keyboard is connected to the computer.

Next, it scans for a BLE peripheral by name. The name is currently hardcoded to "CH-8" for a Teenage Engineering Choir doll. The default pairing code is 000000.

![Teenage Engineering Choir doll](https://teenage.engineering/_img/636bb6605334794ec4ee5dfa_512.png)

Then, MIDI notes from the keyboard are written to the MIDI characteristic on the BLE peripheral. Pressing Ctrl-C exits the program.

# testing

https://github.com/user-attachments/assets/8219edde-8101-43e6-8b7d-77f26bde1b01

## objc

Use the LuaJIT FFI extension to dispatch messages to the CoreBluetooth Framework, using the Objective-C [runtime API](https://developer.apple.com/documentation/objectivec/objective-c_runtime?language=objc). Create a custom class and instance for the CBCentralManager and CBPeripehral delegate.

## cf

Use the LuaJIT FFI extension to wrap the CoreFoundation Framework C API for string creation and runloop management.

## ble

Main application entry point.
