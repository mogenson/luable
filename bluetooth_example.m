#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import <objc/runtime.h>


@interface BluetoothManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;

- (void)startScanning;

@end

@implementation BluetoothManager

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize the central manager.  We use dispatch_get_main_queue() so that
        // all the delegate callbacks are on the main thread.
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    }

    unsigned int i;
    unsigned int method_count = 0;
    Method * methods = class_copyMethodList(object_getClass(self), &method_count);
    NSLog(@"%d methods", method_count);
    for(i = 0; i < method_count; i++) {
            NSLog(@"Method Name: %s", sel_getName(method_getName(methods[i])));
            NSLog(@"Method Signature: %s", method_getDescription(methods[i])->types);
    }

    free(methods);

    return self;
}

- (void)startScanning {
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        NSLog(@"Bluetooth is powered on. Starting scan...");
        NSArray *services = nil; // Scan for all services (or specify UUIDs if known)
        [self.centralManager scanForPeripheralsWithServices:services options:nil];
    } else {
        NSLog(@"Bluetooth is not powered on.  State: %ld", (long)self.centralManager.state);
        // Handle other states appropriately (e.g., prompt user to turn on Bluetooth)
    }
}


#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        [self startScanning];
    } else {
        NSLog(@"Central Manager state changed: %ld", (long)central.state);
        // Handle other states
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Discovered peripheral: %@", peripheral.name);

    if ([peripheral.name isEqualToString:@"CH-8"]) {
        NSLog(@"Found target peripheral!");
        self.discoveredPeripheral = peripheral;
        [self.centralManager stopScan]; // Stop scanning once the target is found.
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected to peripheral: %@", peripheral.name);
    peripheral.delegate = self; // Important: Set the peripheral's delegate
    [peripheral discoverServices:nil]; // Discover all services
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect to peripheral: %@, Error: %@", peripheral.name, error);
    // Handle connection failure
}


#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering services: %@", error);
        return;
    }

    NSLog(@"Discovered services:");
    for (CBService *service in peripheral.services) {
        NSLog(@"  %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service]; // Discover all characteristics for each service
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering characteristics: %@", error);
        return;
    }

    NSLog(@"Discovered characteristics for service %@:", service.UUID);
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"  %@", characteristic.UUID);

        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"7772E5DB-3868-4112-A1A9-F2669D106BF3"]]) {
            NSLog(@"Found target characteristic!");
            NSData *data = [NSData dataWithBytes: (unsigned char []){ 0x80, 0x80, 0x80, 0x3e, 0x7f } length:5];
            [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
            NSLog(@"Value written to characteristic.");
            break; // Stop searching once we've found the characteristic.
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error writing value to characteristic: %@", error);
    } else {
        NSLog(@"Successfully wrote value to characteristic: %@", characteristic.UUID);
    }
}

// Implement other CBPeripheralDelegate methods as needed (e.g., for notifications)

@end



int main(int argc, const char * argv[]) {
    @autoreleasepool {
        BluetoothManager *manager = [[BluetoothManager alloc] init];

        unsigned int count;
        objc_property_t *properties = class_copyPropertyList([BluetoothManager class], &count);

        NSLog(@"Properties of BluetoothManager:");
        for (unsigned int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            const char *propertyAttributes = property_getAttributes(property);

            NSLog(@"  Name: %s", propertyName);

            // Decode and print property attributes (type, ownership, etc.)
            NSLog(@"    Attributes: %s", propertyAttributes);

            // More detailed attribute decoding (Optional, but useful)
            char *attributeString = strdup(propertyAttributes); // Make a copy for strtok
            char *attribute = strtok(attributeString, ",");

            while (attribute != NULL) {
                NSLog(@"      - %@", [NSString stringWithUTF8String:attribute]);
                attribute = strtok(NULL, ",");
            }
            free(attributeString); // Free the duplicated string
        }

        free(properties); // Important: Free the allocated property list

        CFRunLoopRun();
    }
    return 0;
}
