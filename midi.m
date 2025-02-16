#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

void MyMIDIInputCallback(const MIDIPacketList *pktList, void *refCon, void *conn) {
    for (uint32_t i = 0; i < pktList->numPackets; ++i) {
        const MIDIPacket *packet = &pktList->packet[i];

        NSLog(@"Received MIDI packet:");
        NSLog(@"  Timestamp: %lld", packet->timeStamp);
        NSLog(@"  Length: %hu", packet->length);
        NSLog(@"  Data:");

        NSMutableString *dataString = [NSMutableString string];
        for (int j = 0; j < packet->length; ++j) {
            [dataString appendFormat:@"%02X ", packet->data[j]];
        }
        NSLog(@"    %@", dataString);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        // Initialize Core MIDI
        MIDIClientRef client = 0;
        OSStatus err = MIDIClientCreate(CFSTR("My MIDI Client"), NULL, NULL, &client);
        if (err != noErr) {
            NSLog(@"Error creating MIDI client: %d", err);
            return 1;
        }

        // Create a MIDI input port
        MIDIPortRef inputPort = 0;
        err = MIDIInputPortCreate(client, CFSTR("My MIDI Input Port"), MyMIDIInputCallback, NULL, &inputPort);
        if (err != noErr) {
            NSLog(@"Error creating MIDI input port: %d", err);
            return 1;
        }

        // Get the number of MIDI sources
        ItemCount numSources = MIDIGetNumberOfSources();
        if (numSources == 0) {
            NSLog(@"No MIDI sources found.");
            return 1;
        }

        // Connect to the first available MIDI source (you might want to let the user choose)
        MIDIEndpointRef source = MIDIGetSource(0); // Index 0 for the first source

        if (source) {
            err = MIDIPortConnectSource(inputPort, source, NULL);
            if (err != noErr) {
                NSLog(@"Error connecting to MIDI source: %d", err);
                return 1;
            } else {
                NSLog(@"Connected to MIDI source.");
            }
        } else {
            NSLog(@"Invalid MIDI source.");
            return 1;
        }


        // Keep the program running to receive MIDI data (you might want to use a run loop or dispatch queue)
        NSLog(@"Listening for MIDI data... (Press Ctrl+C to stop)");
        while (YES) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }


        // In a real application, you would disconnect and dispose of the MIDI objects when done.
        // For this example, we're just letting the program run indefinitely until Ctrl+C is pressed.
        // MIDIInputPortDisconnectSource(inputPort, source);
        // MIDIObjectDispose(inputPort);
        // MIDIObjectDispose(client);

    }
    return 0;
}
