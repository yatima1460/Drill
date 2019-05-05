/*
 * This file is part of gtkD.
 *
 * gtkD is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
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

/*****************************************************************************

    Authors: Frank Benoit <keinfarbton@googlemail.com>
             muntyan #gtk+

    This demo shows a table with key/value pairs. The values can be edited.
    There are two types of values: strings and bools. Dependent of the type,
    either a CellRendererText or CellRendererToggle is used to show and edit
    the value.

    This is done by connecting the visibility of a CellRenderer to a
    ListStore column.

    2018-03-29: ref to issiue #231
    Added colors in first column GdkColor & RGBA.
    This tests ListStore storing more complex attribute, than simple GType.
    Jakub Zdroik <jakub.zdroik@gmail.com>

*****************************************************************************/
module Drill;

import gtk.Main;
import gdk.Event;
import gtk.Window;
import gtk.Widget;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.Entry;
import gtk.Box;
import gtk.TreeViewColumn;
import gtk.CellRendererText;
import gtk.CellRendererToggle;
import gtk.ListStore;
import gtk.EditableIF;
import gdk.RGBA;
import gdk.Color;

import pango.PgFontDescription;
import std.stdio;

import FileInfo : FileInfo;

enum Column
{
    TYPE,
    NAME,
    PATH,
    DATE_MODIFIED
}


class DrillWindow : Window
{

    ListStore store;
    string search_string;

    void appendRecord(FileInfo fi)
    {
        auto it = store.createIter();

        store.setValue(it, Column.TYPE, fi.type_str);
        store.setValue(it, Column.NAME, fi.name);
        store.setValue(it, Column.PATH, fi.parent);
        store.setValue(it, Column.DATE_MODIFIED, fi.date_modified_str);
    }


    private void searchChanged(EditableIF ei)
    {
        writeln("Wrote input:"~ei.getChars(0,-1));
        this.search_string = ei.getChars(0,-1);
    }


	public this()
	{
		super("Drill");

        store = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING]);

        auto window = new Window("Drill");
        window.setDefaultSize(800, 450);
        window.setResizable(true);
        window.setPosition(GtkWindowPosition.CENTER);
        if (!window.setIconFromFile("assets/icon.png"))
        {
            window.setIconName("search");
        }

        auto tv = new TreeView();

        Box v = new Box(GtkOrientation.VERTICAL, 8);
        window.add(v);

        Entry search_input = new Entry();
        search_input.addOnChanged(&searchChanged);

        // create first column with text renderer
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle("Type");
        tv.appendColumn(column);

        CellRendererText cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.TYPE);

        // create second column with two renderers
        column = new TreeViewColumn();
        column.setTitle("Name");
        tv.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.NAME);

        column = new TreeViewColumn();
        column.setTitle("Path");
        tv.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.PATH);

        column = new TreeViewColumn();
        column.setTitle("Date Modified");
        tv.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.DATE_MODIFIED);

    // change value in store on toggle event
    // cell_bool.addOnToggled(delegate void(string p, CellRendererToggle) {
    //     auto path = new TreePath(p);
    //     auto it = new TreeIter(store, path);
    //     store.setValue(it, COLUMN_BOOL, it.getValueInt(COLUMN_BOOL) ? 0 : 1);

    //     auto val = store.getValue(it, COLUMN_TEXT_FONT_DESCRIPTION);

    //     import gobject.Type;

    //     writeln(Type.isA(PgFontDescription.getType(), GType.BOXED));
    //     writeln(PgFontDescription.getType(), " ", val.gType);

    //     auto font = val.get!PgFontDescription();

    //     writeln(font.getFamily());
    // });

    // change the text in the store on end of edit
    // cell_text.addOnEdited(delegate void(string p, string v, CellRendererText cell) {
    //     auto path = new TreePath(p);
    //     auto it = new TreeIter(store, path);
    //     store.setValue(it, COLUMN_TEXT, v);
    // });

    v.packStart(search_input, false, false, 0);
    v.packStart(tv, true, true, 0);

    tv.setModel(store);
    window.showAll();

    // fill store with data
    FileInfo fi = new FileInfo();
    fi.type_str = "Folder";
    fi.name = "OwO";
    fi.path = "/";
    fi.date_modified_str = "0";

    appendRecord(fi);

    window.addOnDelete(delegate bool(Event event, Widget widget) {
        widget.destroy();
        Main.quit();
        return false;
    });

   
    }
}






void main(string[] args)
{
     Main.init(args);
    DrillWindow d = new DrillWindow();
     Main.run();
    //d.show();
}

