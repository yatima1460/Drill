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


module gtk.Misc;

private import gtk.Widget;
private import gtk.c.functions;
public  import gtk.c.types;
public  import gtkc.gtktypes;


/**
 * The #GtkMisc widget is an abstract widget which is not useful itself, but
 * is used to derive subclasses which have alignment and padding attributes.
 * 
 * The horizontal and vertical padding attributes allows extra space to be
 * added around the widget.
 * 
 * The horizontal and vertical alignment attributes enable the widget to be
 * positioned within its allocated area. Note that if the widget is added to
 * a container in such a way that it expands automatically to fill its
 * allocated area, the alignment settings will not alter the widget's position.
 * 
 * Note that the desired effect can in most cases be achieved by using the
 * #GtkWidget:halign, #GtkWidget:valign and #GtkWidget:margin properties
 * on the child widget, so GtkMisc should not be used in new code. To reflect
 * this fact, all #GtkMisc API has been deprecated.
 */
public class Misc : Widget
{
	/** the main Gtk struct */
	protected GtkMisc* gtkMisc;

	/** Get the main Gtk struct */
	public GtkMisc* getMiscStruct(bool transferOwnership = false)
	{
		if (transferOwnership)
			ownedRef = false;
		return gtkMisc;
	}

	/** the main Gtk struct as a void* */
	protected override void* getStruct()
	{
		return cast(void*)gtkMisc;
	}

	/**
	 * Sets our main struct and passes it to the parent class.
	 */
	public this (GtkMisc* gtkMisc, bool ownedRef = false)
	{
		this.gtkMisc = gtkMisc;
		super(cast(GtkWidget*)gtkMisc, ownedRef);
	}


	/** */
	public static GType getType()
	{
		return gtk_misc_get_type();
	}

	/**
	 * Gets the X and Y alignment of the widget within its allocation.
	 * See gtk_misc_set_alignment().
	 *
	 * Deprecated: Use #GtkWidget alignment and margin properties.
	 *
	 * Params:
	 *     xalign = location to store X alignment of @misc, or %NULL
	 *     yalign = location to store Y alignment of @misc, or %NULL
	 */
	public void getAlignment(out float xalign, out float yalign)
	{
		gtk_misc_get_alignment(gtkMisc, &xalign, &yalign);
	}

	/**
	 * Gets the padding in the X and Y directions of the widget.
	 * See gtk_misc_set_padding().
	 *
	 * Deprecated: Use #GtkWidget alignment and margin properties.
	 *
	 * Params:
	 *     xpad = location to store padding in the X
	 *         direction, or %NULL
	 *     ypad = location to store padding in the Y
	 *         direction, or %NULL
	 */
	public void getPadding(out int xpad, out int ypad)
	{
		gtk_misc_get_padding(gtkMisc, &xpad, &ypad);
	}

	/**
	 * Sets the alignment of the widget.
	 *
	 * Deprecated: Use #GtkWidget's alignment (#GtkWidget:halign and #GtkWidget:valign) and margin properties or #GtkLabel's #GtkLabel:xalign and #GtkLabel:yalign properties.
	 *
	 * Params:
	 *     xalign = the horizontal alignment, from 0 (left) to 1 (right).
	 *     yalign = the vertical alignment, from 0 (top) to 1 (bottom).
	 */
	public void setAlignment(float xalign, float yalign)
	{
		gtk_misc_set_alignment(gtkMisc, xalign, yalign);
	}

	/**
	 * Sets the amount of space to add around the widget.
	 *
	 * Deprecated: Use #GtkWidget alignment and margin properties.
	 *
	 * Params:
	 *     xpad = the amount of space to add on the left and right of the widget,
	 *         in pixels.
	 *     ypad = the amount of space to add on the top and bottom of the widget,
	 *         in pixels.
	 */
	public void setPadding(int xpad, int ypad)
	{
		gtk_misc_set_padding(gtkMisc, xpad, ypad);
	}
}
