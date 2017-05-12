/** \file
 * \brief Menu Resources
 *
 * See Copyright Notice in "iup.h"
 */

#import <Cocoa/Cocoa.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <memory.h>
#include <stdarg.h>

#include "iup.h"
#include "iupcbs.h"

#include "iup_object.h"
#include "iup_childtree.h"
#include "iup_attrib.h"
#include "iup_dialog.h"
#include "iup_str.h"
#include "iup_label.h"
#include "iup_drv.h"
#include "iup_drvfont.h"
#include "iup_image.h"
#include "iup_menu.h"

#include "iupcocoa_drv.h"

/*
For a menu bar:

AppleIcon File Edit Window
               ----
			   Copy
 
 In Cocoa:
 NSMenu (menubar)
 -> addItem: NSMenuItem (for Edit, but not named)
    -> setSubmenu: NSMenu ("Edit", this is the thing that sets the name)
       -> addItem: NSMenuItem (for "Paste")
 
 In IUP:
 IupMenu (menubar)
 -> IupSubmenu (this is the part that gets named "Edit")
    -> IupMenu  (for Edit, but this is not named)
       -> IupItem (for "Paste")
 
 Notice that Submenu is an NSMenuItem. And the naming must be done on the NSMenu attached below it, not on the NSMenuItem itself.
 
*/
@interface IupCocoaMenuItemRepresentedObject : NSObject
{
	Ihandle* _ih;
}
- (instancetype) initWithIhandle:(Ihandle*)ih;
- (Ihandle*) ih;
@end

@implementation IupCocoaMenuItemRepresentedObject

- (instancetype) initWithIhandle:(Ihandle*)ih
{
	self = [super init];
	if(nil == self)
	{
		return nil;
	}
	_ih = ih;
	return self;
}

- (Ihandle*) ih
{
	return _ih;
}

- (IBAction) onMenuItemAction:(id)the_sender
{
	Ihandle* ih = [self ih];
	Icallback call_back;
	
	call_back = IupGetCallback(ih, "ACTION");
	if(call_back)
	{
		int ret_val = call_back(ih);
		if(IUP_CLOSE == ret_val)
		{
			IupExitLoop();
			
		}
	}
	
}

@end

@interface IupCocoaMenuDelegate : NSObject<NSMenuDelegate>

// Use for HIGHLIGHT_CB?
//- (void) menu:(NSMenu*)the_menu willHighlightItem:(NSMenuItem*)menu_item;
@end


@implementation IupCocoaMenuDelegate



// Use for HIGHLIGHT_CB?
/*
- (void) menu:(NSMenu*)the_menu willHighlightItem:(NSMenuItem*)menu_item
{
}
*/


@end


int iupdrvMenuPopup(Ihandle* ih, int x, int y)
{
 
	return IUP_NOERROR;
}

int iupdrvMenuGetMenuBarSize(Ihandle* ih)
{
	CGFloat menu_bar_height = [[[NSApplication sharedApplication] mainMenu] menuBarHeight];
	return iupROUND(menu_bar_height);
}

/*
static void cocoaReleaseMenuClass(Iclass* ic)
{
	// Not sure if I should tear this down. Typically apps just quit and leave all this stuff.
	[NSApp setMainMenu:nil];

}
*/



static int cocoaMenuMapMethod(Ihandle* ih)
{
	if(iupMenuIsMenuBar(ih))
	{
		/* top level menu used for MENU attribute in IupDialog (a menu bar) */
		NSLog(@"cocoaMenuMapMethod iupMenuIsMenuBar %@", ih->parent->handle);
#if 0
		NSMenu* the_menu = [[NSMenu alloc] init];
		ih->handle = the_menu;
		
		[NSApp setMainMenu:the_menu];
		NSLog(@"cocoaMenuMapMethod created NSMenu %@", the_menu);
		NSLog(@"cocoaMenuMapMethod setMainMenu");
#else
		NSMenu* main_menu = [NSApp mainMenu];
		
		ih->handle = main_menu;

		// not sure if I should retain it because I don't know if this is going to ever get released, but probably should to obey normal patterns.
		[main_menu retain];
#endif
		


	}
	else
	{
		if(ih->parent)
		{

			NSLog(@"cocoaMenuMapMethod ih->parent %@", ih->parent->handle);
		/* parent is a submenu, it is created here */


			NSMenuItem* parent_menu = (NSMenuItem*)(ih->parent->handle);
			NSString* parent_menu_title = [parent_menu title];
			
			NSMenu* the_menu = [parent_menu submenu];

			// Try searching for an existing menu by this name and only create is not there.
			if(nil == [parent_menu submenu])
			{
				the_menu = [[NSMenu alloc] init];
				ih->handle = the_menu;
				
				[parent_menu setSubmenu:the_menu];
				// In Cocoa, the name (e.g. "Edit") goes on the NSMenu, not the above NSMenuItem.
				// I earlier set the name on the parent (which isn't visible), and now set it on the correct widget.
				// Not sure if I should unset the title on the NSMenuItem afterwards.
				[the_menu setTitle:parent_menu_title];
				NSLog(@"cocoaMenuMapMethod created NSMenu %@", the_menu);
			}
			else
			{
				// Already exists. Let's try reusing the existing one.
				[the_menu retain];
				ih->handle = the_menu;
				
				NSLog(@"cocoaMenuMapMethod reused NSMenu %@", the_menu);

			}
			
			

			NSLog(@"cocoaMenuMapMethod [parent_menu setSubmenu:the_menu]");
		}
		else
		{
			/* top level menu used for IupPopup */

			NSMenu* the_menu = [[NSMenu alloc] init];
			ih->handle = the_menu;

			NSLog(@"else cocoaMenuMapMethod created NSMenu %@", the_menu);

			
			//iupAttribSet(ih, "_IUPWIN_POPUP_MENU", "1");
		}
	}

	
	

	
	return IUP_NOERROR;
}

static void cocoaMenuUnMapMethod(Ihandle* ih)
{
	NSMenu* the_menu = (NSMenu*)ih->handle;
	// do I need to remove it from the parent???
	ih->handle = NULL;
	[the_menu release];
}

void iupdrvMenuInitClass(Iclass* ic)
{

	id app_name = [[NSProcessInfo processInfo] processName];
#if 0
	
	NSBundle* framework_bundle = [NSBundle bundleWithIdentifier:@"br.puc-rio.tecgraf.iup"];

	/* Note: I discovered that some menus use private/magic capabilites which are not accessible through public API.
	 The Services menu and Window are two major examples. They have a extra field in the XIB data as systemMenu="services" and systemMenu="window"
	 The Help and App menu also have systemMenu entries.
	 So the only solution is to use Interface Builder files to provide these.
	 The debate is whether to just target the individual pieces or provide a single monolithic XIB with everything.
	 */
	
	id app_menu = [[[NSMenu alloc] init] autorelease];
	
	id about_menu_item = [[[NSMenuItem alloc] initWithTitle:[[NSLocalizedString(@"About", @"About") stringByAppendingString:@" "] stringByAppendingString:app_name] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""] autorelease];
	id preferences_menu_item = [[[NSMenuItem alloc] initWithTitle:[NSLocalizedString(@"Preferences", @"Preferences") stringByAppendingString:@"…"] action:nil keyEquivalent:@","] autorelease];
//	id services_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Services", @"Services") action:nil keyEquivalent:@""] autorelease];
	//	id services_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Services", @"Services") action:nil keyEquivalent:@""] autorelease];
	NSNib* services_menu_item_nib = [[[NSNib alloc] initWithNibNamed:@"CanonicalServiceMenu" bundle:framework_bundle] autorelease];
	NSArray* top_level_objects = nil;
	id services_menu_item = nil;
	if([services_menu_item_nib instantiateWithOwner:nil topLevelObjects:&top_level_objects])
	{
		for(id current_object in top_level_objects)
		{
			if([current_object isKindOfClass:[NSMenuItem class]])
			{
				services_menu_item = current_object;
				break;
			}
		}
	}
	
	id hide_menu_item = [[[NSMenuItem alloc] initWithTitle:[[NSLocalizedString(@"Hide", @"Hide") stringByAppendingString:@" "] stringByAppendingString:app_name] action:@selector(hide:) keyEquivalent:@"h"] autorelease];
	id hideothers_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Hide Others", @"Hide Others") action:@selector(hideOtherApplications:) keyEquivalent:@"h"] autorelease];
	[hideothers_menu_item setKeyEquivalentModifierMask:NSEventModifierFlagOption|NSEventModifierFlagCommand];
	id showall_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show All", @"Show All") action:@selector(unhideAllApplications:) keyEquivalent:@""] autorelease];
	id quit_title = [[NSLocalizedString(@"Quit", @"Quit") stringByAppendingString:@" "] stringByAppendingString:app_name];
	id quit_menu_item = [[[NSMenuItem alloc] initWithTitle:quit_title action:@selector(terminate:) keyEquivalent:@"q"] autorelease];


	[app_menu addItem:about_menu_item];
	[app_menu addItem:[NSMenuItem separatorItem]];
	[app_menu addItem:preferences_menu_item];
	[app_menu addItem:[NSMenuItem separatorItem]];
	[app_menu addItem:services_menu_item];
	[app_menu addItem:[NSMenuItem separatorItem]];
	[app_menu addItem:hide_menu_item];
	[app_menu addItem:hideothers_menu_item];
	[app_menu addItem:showall_menu_item];
	[app_menu addItem:[NSMenuItem separatorItem]];
	[app_menu addItem:quit_menu_item];
	
//	id services_sub_menu = [[[NSMenu alloc] init] autorelease];
//	[services_menu_item setSubmenu:services_sub_menu];


	id app_menu_category = [[[NSMenuItem alloc] init] autorelease];
	[app_menu_category setSubmenu:app_menu];
	// This is supposed to do nothing. This is a cheat so I can look up this menu item later and try to reuse it.
	[app_menu_category setTitle:@"ApplicationMenu"];
	
	
	
	
	
//	id print_title = [NSLocalizedString(@"Print", @"Print") stringByAppendingString:@"…"];
//	id print_menu_item = [[[NSMenuItem alloc] initWithTitle:print_title action:@selector(print:) keyEquivalent:@"p"] autorelease];
	
	id file_menu = [[[NSMenu alloc] init] autorelease];
	[file_menu setTitle:NSLocalizedString(@"File", @"File")];
	
//	[file_menu addItem:print_menu_item];

	
	
	id file_menu_category = [[[NSMenuItem alloc] init] autorelease];
	[file_menu_category setSubmenu:file_menu];
	// This is supposed to do nothing. This is a cheat so I can look up this menu item later and try to reuse it.
	[file_menu_category setTitle:NSLocalizedString(@"File", @"File")];

	
	
	
	id cut_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Cut", @"Cut") action:@selector(cut:) keyEquivalent:@"x"] autorelease];
	id copy_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", @"Copy") action:@selector(copy:) keyEquivalent:@"c"] autorelease];
	id paste_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Paste", @"Paste") action:@selector(paste:) keyEquivalent:@"v"] autorelease];
	id selectall_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Select All", @"Select All") action:@selector(selectAll:) keyEquivalent:@"a"] autorelease];
	id findroot_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Find", @"Find") action:nil keyEquivalent:@""] autorelease];

	
	id edit_menu = [[[NSMenu alloc] init] autorelease];
	[edit_menu setTitle:NSLocalizedString(@"Edit", @"Edit")];

	[edit_menu addItem:cut_menu_item];
	[edit_menu addItem:copy_menu_item];
	[edit_menu addItem:paste_menu_item];
	[edit_menu addItem:selectall_menu_item];
	[edit_menu addItem:[NSMenuItem separatorItem]];
	[edit_menu addItem:findroot_menu_item];

	

	id find_sub_menu = [[[NSMenu alloc] init] autorelease];
	[find_sub_menu setTitle:NSLocalizedString(@"Find", @"Find")];
	[findroot_menu_item setSubmenu:find_sub_menu];
	
	id find_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Find", @"Find") action:@selector(performFindPanelAction:) keyEquivalent:@"f"] autorelease];
	id findreplace_menu_item = [[[NSMenuItem alloc] initWithTitle:[NSLocalizedString(@"Find and Replace", @"Find and Replace") stringByAppendingString:@"…"] action:@selector(performFindPanelAction:) keyEquivalent:@"f"] autorelease];
	[findreplace_menu_item setKeyEquivalentModifierMask:NSEventModifierFlagOption|NSEventModifierFlagCommand];
	id findnext_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Find Next", @"Find Next") action:@selector(performFindPanelAction:) keyEquivalent:@"g"] autorelease];
	id findprevious_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Find Previous", @"Find Previous") action:@selector(performFindPanelAction:) keyEquivalent:@"G"] autorelease];
	id useselection_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Use Selection for Find", @"Use Selection for Find") action:@selector(performFindPanelAction:) keyEquivalent:@"e"] autorelease];
	id jumpselection_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Jump to Selection", @"Jump to Selection") action:@selector(centerSelectionInVisibleArea:) keyEquivalent:@"j"] autorelease];

	
	
	[find_sub_menu addItem:find_menu_item];
	[find_sub_menu addItem:findreplace_menu_item];
	[find_sub_menu addItem:findnext_menu_item];
	[find_sub_menu addItem:findprevious_menu_item];
	[find_sub_menu addItem:useselection_menu_item];
	[find_sub_menu addItem:jumpselection_menu_item];


	id edit_menu_category = [[[NSMenuItem alloc] init] autorelease];
	[edit_menu_category setSubmenu:edit_menu];
	// This is supposed to do nothing. This is a cheat so I can look up this menu item later and try to reuse it.
	[edit_menu_category setTitle:NSLocalizedString(@"Edit", @"Edit")];

	
/*
	id minimize_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Minimize", @"Minimize") action:@selector(performMiniaturize:) keyEquivalent:@"m"] autorelease];
	id zoom_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom", @"Zoom") action:@selector(performZoom:) keyEquivalent:@""] autorelease];
	id bringallfront_menu_item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Bring All to Front", @"Bring All to Front") action:@selector(arrangeInFront:) keyEquivalent:@""] autorelease];


	id window_menu = [[[NSMenu alloc] init] autorelease];
	[window_menu setTitle:NSLocalizedString(@"Window", @"Window")];
	
	[window_menu addItem:minimize_menu_item];
	[window_menu addItem:zoom_menu_item];
	[window_menu addItem:[NSMenuItem separatorItem]];
	[window_menu addItem:bringallfront_menu_item];

	id window_menu_category = [[[NSMenuItem alloc] init] autorelease];
	[window_menu_category setSubmenu:window_menu];
	// This is supposed to do nothing. This is a cheat so I can look up this menu item later and try to reuse it.
	[window_menu_category setTitle:NSLocalizedString(@"Window", @"Window")];
*/
	NSNib* window_menu_category_nib = [[[NSNib alloc] initWithNibNamed:@"CanonicalWindowMenu" bundle:framework_bundle] autorelease];
	top_level_objects = nil;
	id window_menu_category = nil;
	if([window_menu_category_nib instantiateWithOwner:nil topLevelObjects:&top_level_objects])
	{
		for(id current_object in top_level_objects)
		{
			if([current_object isKindOfClass:[NSMenuItem class]])
			{
				window_menu_category = current_object;
				break;
			}
		}
	}
	// This is supposed to do nothing. This is a cheat so I can look up this menu item later and try to reuse it.
	[window_menu_category setTitle:NSLocalizedString(@"Window", @"Window")];
	
	
	id help_menu_item = [[[NSMenuItem alloc] initWithTitle:[[app_name stringByAppendingString:@" "] stringByAppendingString:NSLocalizedString(@"Help", @"Help")] action:@selector(showHelp:) keyEquivalent:@"?"] autorelease];
	id help_menu = [[[NSMenu alloc] init] autorelease];
	[help_menu setTitle:NSLocalizedString(@"Help", @"Help")];
	
	[help_menu addItem:help_menu_item];

	id help_menu_category = [[[NSMenuItem alloc] init] autorelease];
	[help_menu_category setSubmenu:help_menu];
	// This is supposed to do nothing. This is a cheat so I can look up this menu item later and try to reuse it.
	[help_menu_category setTitle:NSLocalizedString(@"Window", @"Window")];
	
	
	id menu_bar = [[[NSMenu alloc] init] autorelease];
	[NSApp setMainMenu:menu_bar];
	
	[menu_bar addItem:app_menu_category];
	[menu_bar addItem:file_menu_category];
	[menu_bar addItem:edit_menu_category];
	[menu_bar addItem:window_menu_category];
	[menu_bar addItem:help_menu_category];
#else
	NSBundle* framework_bundle = [NSBundle bundleWithIdentifier:@"br.puc-rio.tecgraf.iup"];
	NSNib* main_menu_nib = [[[NSNib alloc] initWithNibNamed:@"CanonicalMainMenu" bundle:framework_bundle] autorelease];

	NSMenu* menu_bar = nil;

	NSArray* top_level_objects = nil;
	if([main_menu_nib instantiateWithOwner:nil topLevelObjects:&top_level_objects])
	{
		for(id current_object in top_level_objects)
		{
			if([current_object isKindOfClass:[NSMenu class]])
			{
				menu_bar = current_object;
				[NSApp setMainMenu:current_object];
				break;
			}
		}
	}
	// Go through the items and replace the hardcoded MacCocoaAppTemplate with the real app name.
	for(NSMenuItem* current_top_item in [menu_bar itemArray])
	{

		{
			NSString* title_string = [current_top_item title];
			NSString* fixed_string = [title_string stringByReplacingOccurrencesOfString:@"MacCocoaAppTemplate" withString:app_name];
			if(![title_string isEqualToString:fixed_string])
			{
				[current_top_item setTitle:fixed_string];
			}
		}
		
		NSMenu* current_menu = [current_top_item submenu];
		// Note: This does not recurse down submenus of the primary submenu
		for(NSMenuItem* current_menu_item in [current_menu itemArray])
		{
			NSString* title_string = [current_menu_item title];
			NSString* fixed_string = [title_string stringByReplacingOccurrencesOfString:@"MacCocoaAppTemplate" withString:app_name];
			if(![title_string isEqualToString:fixed_string])
			{
				[current_menu_item setTitle:fixed_string];
			}
		}
	}

#endif
	
//	ic->Release = cocoaReleaseMenuClass;

	/* Driver Dependent Class functions */
	ic->Map = cocoaMenuMapMethod;
	ic->UnMap = cocoaMenuUnMapMethod;
#if 0

	/* Used by iupdrvMenuGetMenuBarSize */
	iupClassRegisterAttribute(ic, "FONT", NULL, NULL, IUPAF_SAMEASSYSTEM, "DEFAULTFONT", IUPAF_NOT_MAPPED);  /* inherited */
	
	iupClassRegisterAttribute(ic, "BGCOLOR", NULL, iupdrvBaseSetBgColorAttrib, NULL, NULL, IUPAF_DEFAULT);

#endif
}




static int cocoaItemSetTitleAttrib(Ihandle* ih, const char* value)
{
//	char *str;
	
	/* check if the submenu handle was created in winSubmenuAddToParent */
/*
	if (ih->handle == (InativeHandle*)-1)
		return 1;
*/
	NSMenuItem* menu_item = (NSMenuItem*)ih->handle;

	NSString* ns_string = nil;
	if(!value)
	{
		ns_string = @"";
	}
	else
	{
		ns_string = [NSString stringWithUTF8String:value];

	}
	
	// Mnemonic is not actually supported on Mac. Maybe it does something on GNUStep?
	// However it does seem to strip the & from being displayed in the menu, so it is useful.
	[menu_item setTitleWithMnemonic:ns_string];
	//[menu_item setTitle:ns_string];

	
	// Try to extract the Mnemonic
	
	
	NSRange search_result_range = [ns_string rangeOfString:@"&"];
	if(NSNotFound != search_result_range.location)
	{
		NSRange character_range = NSMakeRange(search_result_range.location+1, 1);
		
		// Make sure the & isn't at the end of the string
		if(character_range.location + character_range.length <= [ns_string length])
		{
			NSString* mnemonic_char = [ns_string substringWithRange:character_range];
			// Drat. If the user is doing something like "&Print", uppercase P makes you press CMD-SHIFT-p. Most likely they just wanted CMD-p
			// Make lowercase to avoid this, but we need a better system to allow specifying command characters in case they did want SHIFT
			mnemonic_char = [mnemonic_char lowercaseString];
			[menu_item setKeyEquivalent:mnemonic_char];
		}


	}
	
	
	
	
	return 1;
}



static int cocoaItemMapMethod(Ihandle* ih)
{

	if(!ih->parent)
	{
		NSLog(@"IUP_ERROR cocoaItemMapMethod !ih->parent");
		return IUP_ERROR;
	}
	
	
	

	
	if (iupMenuIsMenuBar(ih))
	{
		/* top level menu used for MENU attribute in IupDialog (a menu bar) */
		
		NSLog(@"cocoaItemMapMethod iupMenuIsMenuBar %@", ih->parent->handle);
		
	}
	else
	{
		if(ih->parent)
		{
			/* parent is a submenu, it is created here */
			NSLog(@"cocoaItemMapMethod ih->parent %@", ih->parent->handle);
			
		}
		else
		{
			NSLog(@"cocoaItemMapMethod else");
		}
	}
	
	
	
	NSMenu* parent_menu = (NSMenu*)(ih->parent->handle);
	const char* c_title = IupGetAttribute(ih, "TITLE");
	NSString* ns_string = nil;
	NSMenuItem* menu_item = nil;
	if(!c_title)
	{
		ns_string = @"";
	}
	else
	{
		ns_string = [NSString stringWithUTF8String:c_title];
		
	}
	// search through parent to see if this item already exists
	for(NSMenuItem* current_menu_item in [parent_menu itemArray])
	{
		if([[current_menu_item title] isEqualToString:ns_string])
		{
			menu_item = current_menu_item;
			break;
		}
	}
	
	if(nil == menu_item)
	{
		// create new item
		menu_item = [[NSMenuItem alloc] init];
		ih->handle = menu_item;
		[parent_menu addItem:menu_item];
		
		// RepresentedObject is to handle the callbacks
		IupCocoaMenuItemRepresentedObject* represented_object = [[IupCocoaMenuItemRepresentedObject alloc] initWithIhandle:ih];
		[menu_item setRepresentedObject:represented_object];
		[represented_object release];
		[menu_item setTarget:represented_object];
		[menu_item setAction:@selector(onMenuItemAction:)];
	}
	else
	{
		ih->handle = menu_item;
		[menu_item retain];
		
		// For built-in XIB menu items, we may not have setup the represented object stuff, so do that now.
		if([menu_item representedObject] == nil)
		{
			// RepresentedObject is to handle the callbacks
			IupCocoaMenuItemRepresentedObject* represented_object = [[IupCocoaMenuItemRepresentedObject alloc] initWithIhandle:ih];
			[menu_item setRepresentedObject:represented_object];
			[represented_object release];
			[menu_item setTarget:represented_object];
			[menu_item setAction:@selector(onMenuItemAction:)];
		}
		
	}
	
	

	return IUP_NOERROR;
}

static void cocoaItemUnMapMethod(Ihandle* ih)
{
	NSMenuItem* menu_item = (NSMenuItem*)ih->handle;
	// do I need to remove it from the parent???
	ih->handle = NULL;
	[menu_item release];
}


void iupdrvItemInitClass(Iclass* ic)
{
  /* Driver Dependent Class functions */
  ic->Map = cocoaItemMapMethod;
  ic->UnMap = cocoaItemUnMapMethod;
#if 0

	/* Common */
	iupClassRegisterAttribute(ic, "FONT", NULL, iupdrvSetFontAttrib, IUPAF_SAMEASSYSTEM, "DEFAULTFONT", IUPAF_NOT_MAPPED);  /* inherited */
	
	/* Visual */
	iupClassRegisterAttribute(ic, "ACTIVE", iupBaseGetActiveAttrib, iupBaseSetActiveAttrib, IUPAF_SAMEASSYSTEM, "YES", IUPAF_DEFAULT);
	iupClassRegisterAttribute(ic, "BGCOLOR", NULL, iupdrvBaseSetBgColorAttrib, IUPAF_SAMEASSYSTEM, "DLGBGCOLOR", IUPAF_DEFAULT);
	
	/* IupItem only */
	iupClassRegisterAttribute(ic, "VALUE", gtkItemGetValueAttrib, gtkItemSetValueAttrib, NULL, NULL, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
#endif
	iupClassRegisterAttribute(ic, "TITLE", NULL, cocoaItemSetTitleAttrib, NULL, NULL, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
#if 0
	iupClassRegisterAttribute(ic, "TITLEIMAGE", NULL, gtkItemSetTitleImageAttrib, NULL, NULL, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute(ic, "IMAGE", NULL, gtkItemSetImageAttrib, NULL, NULL, IUPAF_IHANDLENAME|IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	iupClassRegisterAttribute(ic, "IMPRESS", NULL, gtkItemSetImpressAttrib, NULL, NULL, IUPAF_IHANDLENAME|IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
	



  /* IupItem GTK and Motif only */
  iupClassRegisterAttribute(ic, "HIDEMARK", NULL, NULL, NULL, NULL, IUPAF_NOT_MAPPED);
#endif
}


static int cocoaSubmenuSetTitleAttrib(Ihandle* ih, const char* value)
{
	//	char *str;
	
	/* check if the submenu handle was created in winSubmenuAddToParent */
	/*
	 if (ih->handle == (InativeHandle*)-1)
		return 1;
	 */
	
#if 0
	NSMenu* the_menu = (NSMenu*)ih->handle;
	
	NSString* ns_string = nil;
	if(!value)
	{
		ns_string = @"";
	}
	else
	{
		ns_string = [NSString stringWithUTF8String:value];
		
	}
	
	[the_menu setTitle:ns_string];
#else

	
	
	NSMenuItem* menu_item = (NSMenuItem*)ih->handle;
	
	
	NSString* ns_string = nil;
	if(!value)
	{
		ns_string = @"";
	}
	else
	{
		ns_string = [NSString stringWithUTF8String:value];
		
	}
	
	[menu_item setTitle:ns_string];
#endif
	
	return 1;
}


static int cocoaSubmenuMapMethod(Ihandle* ih)
{
	if(!ih->parent)
	{
		NSLog(@"IUP_ERROR cocoaSubmenuMapMethod !ih->parent");
		return IUP_ERROR;
	}
	
	
	if (iupMenuIsMenuBar(ih->parent))
	{
		/* top level menu used for MENU attribute in IupDialog (a menu bar) */
		
		NSLog(@"cocoaSubmenuMapMethod iupMenuIsMenuBar %@", ih->parent->handle);
		
	}
	else
	{
		if(ih->parent)
		{
			/* parent is a submenu, it is created here */
			NSLog(@"cocoaSubmenuMapMethod ih->parent %@", ih->parent->handle);
			
		}
		else
		{
			NSLog(@"cocoaSubmenuMapMethod else");
		}
	}
	
	
	
	
	NSObject* parent_object = (NSObject*)ih->parent->handle;
	if([parent_object isKindOfClass:[NSMenuItem class]])
	{
		/* parent is a submenu, it is created here */
		NSMenu* the_menu = [[NSMenu alloc] init];
		ih->handle = the_menu;
		
		NSMenuItem* parent_menu = (NSMenuItem*)(ih->parent->handle);
		[parent_menu setSubmenu:the_menu];
		
		
		NSLog(@"cocoaSubmenuMapMethod iupMenuIsMenuBar %@", ih->parent->handle);
		NSLog(@"cocoaSubmenuMapMethod created NSMenu %@", the_menu);
		NSLog(@"[parent_menu setSubmenu:the_menu]");

		
		
	}
	else if([parent_object isKindOfClass:[NSMenu class]])
	{
		

		
#if 0
		NSMenu* the_menu = [[NSMenu alloc] init];
		ih->handle = the_menu;
		
			NSMenu* parent_menu = (NSMenu*)(ih->parent->handle);
			NSMenuItem* replacement_parent_menu_item = [[NSMenuItem alloc] initWithTitle:[parent_menu title] action:nil keyEquivalent:@""];
			[parent_menu release];
			ih->parent->handle = replacement_parent_menu_item;
#else
		
		NSMenu* parent_menu = (NSMenu*)(ih->parent->handle);
		NSArray* list_of_menu_items = [parent_menu itemArray];
//		NSInteger number_of_items = [parent_menu numberOfItems];
		NSMenuItem* found_menu_item = nil;
		
		const char* c_title = IupGetAttribute(ih, "TITLE");
		NSString* ns_string = nil;
		if(!c_title)
		{
			ns_string = @"";
		}
		else
		{
			ns_string = [NSString stringWithUTF8String:c_title];
			
		}
		
		for(NSMenuItem* menu_item in list_of_menu_items)
		{
			NSString* menu_item_title = [menu_item title];
			if([menu_item_title isEqualToString:ns_string])
			{
				found_menu_item = menu_item;
				break;
			}
		}
		
		if(found_menu_item)
		{
			NSLog(@"found menu item for Submenu");
			ih->handle = found_menu_item;
			[found_menu_item retain];
			
		}
		else
		{
			//		NSMenuItem* menu_item_for_submenu = [[NSMenuItem alloc] initWithTitle:[parent_menu title] action:nil keyEquivalent:@""];
//			NSMenuItem* menu_item_for_submenu = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(onMenuItemAction:) keyEquivalent:@""];
			NSMenuItem* menu_item_for_submenu = [[NSMenuItem alloc] init];
			
			
			/* 
			Okay, now we're going to get tricky.
			Cocoa has strong conventions about what should be in the menu and where.
			Currently I'm operating on the assumption that we are going to pre-populate a default menu for IUP and the user is going to add (and maybe remove) items.
			So we need to search through the existing menu and determine where things go.
			Current assumption: All normal menu categories are already in the menu. So if the user adds a new one, we must put it in the right place.
			The Apple Human User Interface Guidelines (HIG) state that new menu entries appear between the View and Window items.
			View is also sometimes optional, so for robustness, we should scan for Window and insert right before Window. 
			(This also handles the case where user entries have already been added since we will add after those entries which is expected behavior.)
			*/
			NSInteger index_to_insert_at = -1; // start at -1 because we are 1 slot before our stopping marker
			BOOL found_window_slot = NO;
			for(NSMenuItem* current_menu_item in [parent_menu itemArray])
			{
//				NSLog(@"current_menu_item.title %@", [current_menu_item title]);
				index_to_insert_at = index_to_insert_at + 1;
				if(([[current_menu_item title] isEqualToString:NSLocalizedString(@"Window", @"Window")]) || ([[current_menu_item title] isEqualToString:@"Window"]))
				{
					found_window_slot = YES;
					break;
				}
			}
			
			if(found_window_slot)
			{
				[parent_menu insertItem:menu_item_for_submenu atIndex:index_to_insert_at];
			}
			else
			{
				NSLog(@"Warning: Did not find Window menu to insert category in");
				[parent_menu addItem:menu_item_for_submenu];
			}
			
			ih->handle = menu_item_for_submenu;
//			[menu_item_for_submenu setTitle:ns_string];
			[menu_item_for_submenu setTitleWithMnemonic:ns_string];

			/*
			// RepresentedObject is to handle the callbacks
			IupCocoaMenuItemRepresentedObject* represented_object = [[IupCocoaMenuItemRepresentedObject alloc] initWithIhandle:ih];
			[menu_item_for_submenu setRepresentedObject:represented_object];
			[represented_object release];
			[menu_item_for_submenu setTarget:represented_object];
			[menu_item setAction:@selector(onMenuItemAction:)];
*/

			
			NSLog(@"cocoaSubmenuMapMethod parent_menu %@", parent_menu);
			NSLog(@"cocoaSubmenuMapMethod replacement_parent_menu_item %@", menu_item_for_submenu);
			NSLog(@"[parent_menu setSubmenu:the_menu]");
		
		
		}
		//[replacement_parent_menu_item setSubmenu:the_menu];
		
		
#endif
		
		
		
		NSLog(@"NSMenu swap");
		//NSCAssert(0==1, @"NSMenu");
		
		
//		return iupBaseTypeVoidMapMethod(ih);

		
		return IUP_NOERROR;
	}
	else
	{
		NSLog(@"What menu thing is this?");
		NSCAssert(0==1, @"What is this?");
		return IUP_ERROR;

	}

	
	return IUP_NOERROR;
}

static void cocoaSubmenuUnMapMethod(Ihandle* ih)
{
	NSMenuItem* menu_item = (NSMenuItem*)ih->handle;
	// do I need to remove it from the parent???
	ih->handle = NULL;
	[menu_item release];
}



void iupdrvSubmenuInitClass(Iclass* ic)
{
  /* Driver Dependent Class functions */
  ic->Map = cocoaSubmenuMapMethod;
  ic->UnMap = cocoaSubmenuUnMapMethod;
#if 0

	/* Common */
	iupClassRegisterAttribute(ic, "FONT", NULL, iupdrvSetFontAttrib, IUPAF_SAMEASSYSTEM, "DEFAULTFONT", IUPAF_NOT_MAPPED);  /* inherited */
	
	/* Visual */
	iupClassRegisterAttribute(ic, "ACTIVE", iupBaseGetActiveAttrib, iupBaseSetActiveAttrib, IUPAF_SAMEASSYSTEM, "YES", IUPAF_DEFAULT);
	iupClassRegisterAttribute(ic, "BGCOLOR", NULL, iupdrvBaseSetBgColorAttrib, IUPAF_SAMEASSYSTEM, "DLGBGCOLOR", IUPAF_DEFAULT);
	
	/* IupSubmenu only */
#endif
	iupClassRegisterAttribute(ic, "TITLE", NULL, cocoaSubmenuSetTitleAttrib, NULL, NULL, IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
#if 0
	iupClassRegisterAttribute(ic, "IMAGE", NULL, gtkSubmenuSetImageAttrib, NULL, NULL, IUPAF_IHANDLENAME|IUPAF_NO_DEFAULTVALUE|IUPAF_NO_INHERIT);
#endif
}


static int cocoaSeparatorMapMethod(Ihandle* ih)
{
#if 0
	int pos;
	
	if (!ih->parent)
		return IUP_ERROR;
	
	ih->handle = gtk_separator_menu_item_new();
	if (!ih->handle)
		return IUP_ERROR;
	
	ih->serial = iupMenuGetChildId(ih);
	
	pos = IupGetChildPos(ih->parent, ih);
	gtk_menu_shell_insert((GtkMenuShell*)ih->parent->handle, ih->handle, pos);
	gtk_widget_show(ih->handle);
#endif
	return IUP_NOERROR;
}

static void cocoaSeparatorUnMapMethod(Ihandle* ih)
{

}

void iupdrvSeparatorInitClass(Iclass* ic)
{
#if 1
  /* Driver Dependent Class functions */
  ic->Map = cocoaSeparatorMapMethod;
  ic->UnMap = cocoaSeparatorUnMapMethod;
#endif
	
}
