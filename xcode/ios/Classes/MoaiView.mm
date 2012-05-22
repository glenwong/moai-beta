//----------------------------------------------------------------//
// Copyright (c) 2010-2011 Zipline Games, Inc. 
// All Rights Reserved. 
// http://getmoai.com
//----------------------------------------------------------------//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

//extern "C" {
//	#include <lua.h>
//	#include <lauxlib.h>
//	#include <lualib.h>
//}

#import <aku/AKU-iphone.h>
#import <aku/AKU-luaext.h>
#import <aku/AKU-audiosampler.h>
#import <lua-headers/moai_lua.h>

#ifdef USE_UNTZ
#import <aku/AKU-untz.h>
#endif

#ifdef USE_FMOD_EX
#include <aku/AKU-fmod-ex.h>
#endif

#import "LocationObserver.h"
#import "MoaiView.h"
#import "ParticlePresets.h"

namespace MoaiInputDeviceID {
	enum {
		DEVICE,
		TOTAL,
	};
}

namespace MoaiInputDeviceSensorID {
	enum {
		COMPASS,
		LEVEL,
		LOCATION,
		TOUCH,
		TOTAL,
	};
}

//================================================================//
// MoaiView ()
//================================================================//
@interface MoaiView ()

	//----------------------------------------------------------------//
	-( void )	handleTouches		:( NSSet* )touches :( BOOL )down;
	-( void )	onUpdateAnim;
	-( void )	onUpdateHeading		:( LocationObserver* )observer;
	-( void )	onUpdateLocation	:( LocationObserver* )observer;
	-( void )	startAnimation;
	-( void )	stopAnimation;

@end

//================================================================//
// MoaiView
//================================================================//
@implementation MoaiView

	//----------------------------------------------------------------//
	-( void ) accelerometer:( UIAccelerometer* )acel didAccelerate:( UIAcceleration* )acceleration {
		( void )acel;
		
		AKUEnqueueLevelEvent (
			MoaiInputDeviceID::DEVICE,
			MoaiInputDeviceSensorID::LEVEL,
			( float )acceleration.x,
			( float )acceleration.y,
			( float )acceleration.z
		);
	}

	//----------------------------------------------------------------//
	-( void ) dealloc {
	
		AKUDeleteContext ( mContext );
		
		[ super dealloc ];
	}

	//----------------------------------------------------------------//
	-( void ) drawView {
						
		[ self beginDrawing ];
		
		AKUSetContext ( mAku );
        AKUSetViewSize ( mWidth, mHeight );
		AKURender ();

		[ self endDrawing ];
	}
	
	//----------------------------------------------------------------//
	-( void ) handleTouches :( NSSet* )touches :( BOOL )down {
	
		for ( UITouch* touch in touches ) {
			
			CGPoint p = [ touch locationInView:self ];
			
			AKUEnqueueTouchEvent (
				MoaiInputDeviceID::DEVICE,
				MoaiInputDeviceSensorID::TOUCH,
				( int )touch, // use the address of the touch as a unique id
				down,
				p.x * [[ UIScreen mainScreen ] scale ],
				p.y * [[ UIScreen mainScreen ] scale ]
			);
		}
	}
	
	//----------------------------------------------------------------//
	-( id )init {
		
		self = [ super init ];
		if ( self ) {
		}
		return self;
	}

	//----------------------------------------------------------------//
	-( id ) initWithCoder:( NSCoder* )encoder {
	
		self = [ super initWithCoder:encoder ];
		if ( self ) {
		}
		return self;
	}
	
	//----------------------------------------------------------------//
	-( id ) initWithFrame :( CGRect )frame {
	
		self = [ super initWithFrame:frame ];
		if ( self ) {
		}
		return self;
	}
	
	//----------------------------------------------------------------//
	-( void ) moaiInit :( UIApplication* )application {
	
		mAku = AKUCreateContext ();
		AKUSetUserdata ( self );
		
		AKUExtLoadLuasql ();
		AKUExtLoadLuacurl ();
		AKUExtLoadLuacrypto ();
		AKUExtLoadLuasocket ();
        AKUExtLoadLuamsgpack();
		
#ifdef USE_UNTZ
		AKUUntzInit ();
#endif
        
#ifdef USE_FMOD_EX
        AKUFmodExInit ();
#endif
        
		AKUAudioSamplerInit ();
        
		AKUSetInputConfigurationName ( "iPhone" );

		AKUReserveInputDevices			( MoaiInputDeviceID::TOTAL );
		AKUSetInputDevice				( MoaiInputDeviceID::DEVICE, "device" );
		
		AKUReserveInputDeviceSensors	( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::TOTAL );
		AKUSetInputDeviceCompass		( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::COMPASS,		"compass" );
		AKUSetInputDeviceLevel			( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::LEVEL,		"level" );
		AKUSetInputDeviceLocation		( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::LOCATION,		"location" );
		AKUSetInputDeviceTouch			( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::TOUCH,		"touch" );
		
		CGRect screenRect = [[ UIScreen mainScreen ] bounds ];
		CGFloat scale = [[ UIScreen mainScreen ] scale ];
		CGFloat screenWidth = screenRect.size.width * scale;
		CGFloat screenHeight = screenRect.size.height * scale;
		
		AKUSetScreenSize ( screenWidth, screenHeight );
		
		AKUSetDefaultFrameBuffer ( mFramebuffer );
		AKUDetectGfxContext ();
		
		mAnimInterval = 1; // 1 for 60fps, 2 for 30fps
		
		mLocationObserver = [[[ LocationObserver alloc ] init ] autorelease ];
		
		[ mLocationObserver setHeadingDelegate:self :@selector ( onUpdateHeading: )];
		[ mLocationObserver setLocationDelegate:self :@selector ( onUpdateLocation: )];
		
		UIAccelerometer* accel = [ UIAccelerometer sharedAccelerometer ];
		accel.delegate = self;
		accel.updateInterval = mAnimInterval / 60;
		
		// init aku
		AKUIphoneInit ( application );
		AKURunBytecode ( moai_lua, moai_lua_SIZE );
		
		// add in the particle presets
		ParticlePresets ();
	}
	
	//----------------------------------------------------------------//
	-( void ) onUpdateAnim {
		
		[ self openContext ];
		AKUSetContext ( mAku );
		AKUUpdate ();
		
		[ self drawView ];
	}
	
	//----------------------------------------------------------------//
	-( void ) onUpdateHeading :( LocationObserver* )observer {
	
		AKUEnqueueCompassEvent (
			MoaiInputDeviceID::DEVICE,
			MoaiInputDeviceSensorID::COMPASS,
			( float )[ observer heading ]
		);
	}
	
	//----------------------------------------------------------------//
	-( void ) onUpdateLocation :( LocationObserver* )observer {
	
		AKUEnqueueLocationEvent (
			MoaiInputDeviceID::DEVICE,
			MoaiInputDeviceSensorID::LOCATION,
			[ observer longitude ],
			[ observer latitude ],
			[ observer altitude ],
			( float )[ observer hAccuracy ],
			( float )[ observer vAccuracy ],
			( float )[ observer speed ]
		);
	}
	
	//----------------------------------------------------------------//
	-( void ) pause :( BOOL )paused {
	
		if ( paused ) {
			AKUPause ( YES );
			[ self stopAnimation ];
		}
		else {
			[ self startAnimation ];
			AKUPause ( NO );
		}
	}
	
	//----------------------------------------------------------------//
	-( void ) run :( NSString* )filename {
	
		AKUSetContext ( mAku );
		AKURunScript ([ filename UTF8String ]);
	}
	
	//----------------------------------------------------------------//
	-( void ) startAnimation {
		
		if ( !mDisplayLink ) {
			CADisplayLink* aDisplayLink = [[ UIScreen mainScreen ] displayLinkWithTarget:self selector:@selector( onUpdateAnim )];
			[ aDisplayLink setFrameInterval:mAnimInterval ];
			[ aDisplayLink addToRunLoop:[ NSRunLoop currentRunLoop ] forMode:NSDefaultRunLoopMode ];
			mDisplayLink = aDisplayLink;
		}
	}

	//----------------------------------------------------------------//
	-( void ) stopAnimation {
		
        [ mDisplayLink invalidate ];
        mDisplayLink = nil;
	}
	
	//----------------------------------------------------------------//
	-( void )touchesBegan:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )event;
		
		[ self handleTouches :touches :YES ];
	}
	
	//----------------------------------------------------------------//
	-( void )touchesCancelled:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )touches;
		( void )event;
		
		AKUEnqueueTouchEventCancel ( MoaiInputDeviceID::DEVICE, MoaiInputDeviceSensorID::TOUCH );
	}
	
	//----------------------------------------------------------------//
	-( void )touchesEnded:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )event;
		
		[ self handleTouches :touches :NO ];
	}

	//----------------------------------------------------------------//
	-( void )touchesMoved:( NSSet* )touches withEvent:( UIEvent* )event {
		( void )event;
		
		[ self handleTouches :touches :YES ];
	}
	
@end