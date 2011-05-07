//
//  BADynamicDesignController.h
//  BARTApplication
//
//  Created by Lydia Hellrung on 5/6/11.
//  Copyright 2011 MPI Cognitive and Human Brain Sciences Leipzig. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BADesignElement.h"
#import "../../../../../BARTSerialIOFramework/SerialPort.h"

@interface BADynamicDesignController : NSObject {

	SerialPort *serialPortEyeTrac;
	SerialPort *serialPortTriggerAndButtonBox;
	BADesignElement *designElement;
}

@property (readonly, assign) SerialPort *serialPortEyeTrac;
@property (readonly, assign) SerialPort *serialPortTriggerAndButtonBox;
@property (readonly, assign) BADesignElement *designElement;


-(BOOL) initDesign;

@end
