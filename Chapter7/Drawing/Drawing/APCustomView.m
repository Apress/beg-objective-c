//
//  APCustomView.m
//  Drawing
//
//  Created by Jim Dovey on 2012-07-14.
//  Copyright (c) 2012 Apress Inc. All rights reserved.
//

#import "APCustomView.h"

@implementation APCustomView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (BOOL)acceptsFirstResponder
{
    // YES, so we can draw a focus rect
    return YES;
}

- (void) setLinear: (BOOL) linear
{
    if ( linear == _linear )
        return;
    
    _linear = linear;
    [self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSGraphicsContext * ctx = [NSGraphicsContext currentContext];
    [ctx saveGraphicsState];
    
    // Create a gradient and use it to fill our bounds
    NSGradient * gradient = [[NSGradient alloc] initWithStartingColor: [NSColor whiteColor] endingColor: [NSColor lightGrayColor]];

    if ( self.linear )
    {
        NSRect r = [self bounds];
        
        // fill the background
        [[NSColor whiteColor] setFill];
        NSRectFill([self bounds]);
        
        // the top 40 pixels will be a bar: no border, just a drop shadow in the 40 pixels below it
        r.origin.y = NSMaxY(r) - 80.0;
        r.size.height = 40.0;
        
        // the nice shadow gradient -- this is grayscale, so use a grayscale color space
        NSArray * colors = @[
            [NSColor colorWithCalibratedWhite:0.0 alpha:0.0],
            [NSColor colorWithCalibratedWhite:0.0 alpha:0.1],
            [NSColor colorWithCalibratedWhite:0.0 alpha:0.3]
        ];
        const CGFloat locations[3] = {
            0.0, 0.8, 1.0
        };
        
        gradient = [[NSGradient alloc] initWithColors: colors atLocations: locations colorSpace: [NSColorSpace genericGrayColorSpace]];
        
        // now draw it -- flowing bottom to top (clear to dark)
        [gradient drawInRect: r angle: 90.0];
        
        NSBezierPath *path = [NSBezierPath bezierPath];
        r = NSMakeRect(20.0,20.0,140.0,80.0);
        
        // start at bottom-right and go clockwise
        [path moveToPoint: NSMakePoint(NSMaxX(r),NSMinY(r))];
        [path lineToPoint: r.origin];
        [path lineToPoint: NSMakePoint(NSMinX(r),NSMaxY(r))];
        [path lineToPoint: NSMakePoint(NSMaxX(r),NSMaxY(r))];
        
        // three straight edges drawn, now do a sine-curve for the right edge
        NSPoint leftControlPoint = NSMakePoint(NSMaxX(r)-20.0,NSMidY(r));
        NSPoint rightControlPoint = NSMakePoint(NSMaxX(r)+20.0,NSMidY(r));
        [path curveToPoint: NSMakePoint(NSMaxX(r),NSMinY(r))
             controlPoint1: leftControlPoint
             controlPoint2: rightControlPoint];
        
        // close the path
        [path closePath];
        
        [path setLineWidth: 4.0];
        
        // fill it with a gradient
        gradient = [[NSGradient alloc] initWithStartingColor: [NSColor whiteColor] endingColor: [NSColor lightGrayColor]];
        [gradient drawInBezierPath: path relativeCenterPosition: NSMakePoint(0, 0)];
    }
    else
    {
        [gradient drawInRect: [self bounds] relativeCenterPosition: NSMakePoint(0, 0)];
    }
}

- (NSRect)focusRingMaskBounds
{
    return [self bounds];
}

- (void)drawFocusRingMask
{
    // we fill our bounds, so that's the mask for our focus rect
    [[NSColor blackColor] setFill];
    NSRectFill([self bounds]);
}

@end
