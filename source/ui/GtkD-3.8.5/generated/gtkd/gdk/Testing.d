/*
 * This file is part of gtkD.
 *
 * gtkD is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version, with
 * some exceptions, please read the COPYING file.
 *
 * gtkD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with gtkD; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
 */

// generated automatically - do not change
// find conversion definition on APILookup.txt
// implement new conversion functionalities on the wrap.utils pakage


module gdk.Testing;

private import gdk.Window;
private import gdk.c.functions;
public  import gdk.c.types;
public  import gtkc.gdktypes;


/** */
public struct Testing
{

	/**
	 * Retrieves a pixel from @window to force the windowing
	 * system to carry out any pending rendering commands.
	 *
	 * This function is intended to be used to synchronize with rendering
	 * pipelines, to benchmark windowing system rendering operations.
	 *
	 * Params:
	 *     window = a mapped #GdkWindow
	 *
	 * Since: 2.14
	 */
	public static void testRenderSync(Window window)
	{
		gdk_test_render_sync((window is null) ? null : window.getWindowStruct());
	}

	/**
	 * This function is intended to be used in GTK+ test programs.
	 * It will warp the mouse pointer to the given (@x,@y) coordinates
	 * within @window and simulate a button press or release event.
	 * Because the mouse pointer needs to be warped to the target
	 * location, use of this function outside of test programs that
	 * run in their own virtual windowing system (e.g. Xvfb) is not
	 * recommended.
	 *
	 * Also, gdk_test_simulate_button() is a fairly low level function,
	 * for most testing purposes, gtk_test_widget_click() is the right
	 * function to call which will generate a button press event followed
	 * by its accompanying button release event.
	 *
	 * Params:
	 *     window = a #GdkWindow to simulate a button event for
	 *     x = x coordinate within @window for the button event
	 *     y = y coordinate within @window for the button event
	 *     button = Number of the pointer button for the event, usually 1, 2 or 3
	 *     modifiers = Keyboard modifiers the event is setup with
	 *     buttonPressrelease = either %GDK_BUTTON_PRESS or %GDK_BUTTON_RELEASE
	 *
	 * Returns: whether all actions necessary for a button event simulation
	 *     were carried out successfully
	 *
	 * Since: 2.14
	 */
	public static bool testSimulateButton(Window window, int x, int y, uint button, GdkModifierType modifiers, GdkEventType buttonPressrelease)
	{
		return gdk_test_simulate_button((window is null) ? null : window.getWindowStruct(), x, y, button, modifiers, buttonPressrelease) != 0;
	}

	/**
	 * This function is intended to be used in GTK+ test programs.
	 * If (@x,@y) are > (-1,-1), it will warp the mouse pointer to
	 * the given (@x,@y) coordinates within @window and simulate a
	 * key press or release event.
	 *
	 * When the mouse pointer is warped to the target location, use
	 * of this function outside of test programs that run in their
	 * own virtual windowing system (e.g. Xvfb) is not recommended.
	 * If (@x,@y) are passed as (-1,-1), the mouse pointer will not
	 * be warped and @window origin will be used as mouse pointer
	 * location for the event.
	 *
	 * Also, gdk_test_simulate_key() is a fairly low level function,
	 * for most testing purposes, gtk_test_widget_send_key() is the
	 * right function to call which will generate a key press event
	 * followed by its accompanying key release event.
	 *
	 * Params:
	 *     window = a #GdkWindow to simulate a key event for
	 *     x = x coordinate within @window for the key event
	 *     y = y coordinate within @window for the key event
	 *     keyval = A GDK keyboard value
	 *     modifiers = Keyboard modifiers the event is setup with
	 *     keyPressrelease = either %GDK_KEY_PRESS or %GDK_KEY_RELEASE
	 *
	 * Returns: whether all actions necessary for a key event simulation
	 *     were carried out successfully
	 *
	 * Since: 2.14
	 */
	public static bool testSimulateKey(Window window, int x, int y, uint keyval, GdkModifierType modifiers, GdkEventType keyPressrelease)
	{
		return gdk_test_simulate_key((window is null) ? null : window.getWindowStruct(), x, y, keyval, modifiers, keyPressrelease) != 0;
	}
}
