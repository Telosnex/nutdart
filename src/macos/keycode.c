#include "../keycode.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Carbon/Carbon.h> /* For kVK_ constants, and TIS functions. */
#include <dispatch/dispatch.h> /* For GCD main queue dispatch */

/* Returns string representation of key, if it is printable.
 * Ownership follows the Create Rule; that is, it is the caller's
 * responsibility to release the returned object. */
CFStringRef createStringForKey(CGKeyCode keyCode);

MMKeyCode keyCodeForChar(const char c)
{
	/* OS X does not appear to have a built-in function for this, so instead we
	 * have to write our own. */
	static CFMutableDictionaryRef charToCodeDict = NULL;
	UniChar character = c;
	CFStringRef charStr = NULL;

	/* Generate table of keycodes and characters. */
	if (charToCodeDict == NULL)
	{
		size_t i;
		charToCodeDict = CFDictionaryCreateMutable(kCFAllocatorDefault,
												   128,
												   &kCFCopyStringDictionaryKeyCallBacks,
												   NULL);
		if (charToCodeDict == NULL)
			return UINT16_MAX;

		/* Loop through every keycode (0 - 127) to find its current mapping. */
		for (i = 0; i < 128; ++i)
		{
			CFStringRef string = createStringForKey((CGKeyCode)i);
			if (string != NULL)
			{
				CFDictionaryAddValue(charToCodeDict, string, (const void *)(uintptr_t)i);
				CFRelease(string);
			}
		}
	}

	charStr = CFStringCreateWithCharacters(kCFAllocatorDefault, &character, 1);

	/* Our values may be NULL (0), so we need to use this function.
	 * Use pointer-sized intermediate variable to avoid memory width issues. */
	void *value = NULL;
	CGKeyCode code;
	if (!CFDictionaryGetValueIfPresent(charToCodeDict, charStr,
									   (const void **)&value))
	{
		code = UINT16_MAX; /* Error */
	}
	else
	{
		code = (CGKeyCode)(uintptr_t)value;
	}

	CFRelease(charStr);
	return (MMKeyCode)code;
}

CFStringRef createStringForKey(CGKeyCode keyCode)
{
 __block CFStringRef result = NULL;
 
 // HIToolbox functions must be called on the main thread
 dispatch_sync(dispatch_get_main_queue(), ^{
  TISInputSourceRef currentKeyboard = TISCopyCurrentASCIICapableKeyboardInputSource();
  if (currentKeyboard == NULL) {
   return;
  }
  
  CFDataRef layoutData =
   TISGetInputSourceProperty(currentKeyboard,
           kTISPropertyUnicodeKeyLayoutData);
  if (layoutData == NULL) {
   CFRelease(currentKeyboard);
   return;
  }
  
  const UCKeyboardLayout *keyboardLayout =
   (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
  if (keyboardLayout == NULL) {
   CFRelease(currentKeyboard);
   return;
  }

  UInt32 keysDown = 0;
  UniChar chars[4];
  UniCharCount realLength;

  OSStatus status = UCKeyTranslate(keyboardLayout,
           keyCode,
           kUCKeyActionDisplay,
           0,
           LMGetKbdType(),
           kUCKeyTranslateNoDeadKeysBit,
           &keysDown,
           sizeof(chars) / sizeof(chars[0]),
           &realLength,
           chars);
  
  CFRelease(currentKeyboard);
  
  if (status == noErr && realLength > 0) {
   result = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, realLength);
  }
 });

 return result;
}
