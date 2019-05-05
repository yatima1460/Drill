/*
 * This file is part of gir-to-d.
 *
 * gir-to-d is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, either version 3
 * of the License, or (at your option) any later version.
 *
 * gir-to-d is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with gir-to-d.  If not, see <http://www.gnu.org/licenses/>.
 */

module gtd.GlibTypes;

enum string[string] glibTypes = [
	"volatile": "",
	"G_CONST_RETURN": "",
	"gint": "int",
	"guint": "uint",
	"gboolean": "bool",
	"gpointer": "void*",
	"gconstpointer": "void*",
	"gchar": "char",
	"guchar": "char",
	"gshort": "short",
	"gushort": "ushort",
	"gint8": "byte",
	"guint8": "ubyte",
	"gint16": "short",
	"guint16": "ushort",
	"gint32": "int",
	"gint64": "long",
	"guint32": "uint",
	"guint64": "ulong",
	"guintptr": "size_t",
	"gfloat": "float",
	"gdouble": "double",
	"goffset": "long",
	"gsize": "size_t",
	"gssize": "ptrdiff_t",
	"va_list": "void*",
	"unichar": "dchar",
	"unichar2": "wchar",
	"uchar": "ubyte",
	"XID": "uint",

	"gunichar": "dchar",
	"gunichar2": "wchar",

	"time_t": "uint",
	"uid_t": "uid_t",

	"alias": "alias_",
	"align": "align_",
	"body": "body_",
	"continue": "continue_",
	"debug": "debug_",
	"default": "default_",
	"delete": "delete_",
	"export": "export_",
	"foreach": "foreach_",
	"function": "function_",
	"Function": "Function_",
	"in": "in_",
	"instance": "instance_",
	"interface": "interface_",
	"module": "module_",
	"out": "out_",
	"package": "package_",
	"ref": "ref_",
	"scope": "scope_",
	"string": "string_",
	"switch": "switch_",
	"union": "union_",
	"version": "version_",
	"byte": "byte_",
	"shared": "shared_",

	"GLIB_SYSDEF_POLLIN": "=1",
	"GLIB_SYSDEF_POLLOUT": "=4",
	"GLIB_SYSDEF_POLLPRI": "=2",
	"GLIB_SYSDEF_POLLHUP": "=16",
	"GLIB_SYSDEF_POLLERR": "=8",
	"GLIB_SYSDEF_POLLNVAL": "=32",
];

/**
 * Set some defaults for the basic libraries.
 */
enum string[][string] defaultLookupText = [
	"Atk": [
		"struct: Implementor",
		"interface: Implementor",
		"merge: ImplementorIface"
	],
	"cairo": [
		"struct: Context",
		"class: Context",
		"struct: Surface",
		"class: Surface",
		"struct: Matrix",
		"class: Matrix",
		"struct: Pattern",
		"class: Pattern",
		"struct: Region",
		"class: Region",
		"struct: FontOptions",
		"class: FontOption",
		"struct: FontFace",
		"class: FontFace",
		"struct: ScaledFont",
		"class: ScaledFont"
	],
	"Gdk": [
		"struct: Atom",
		"namespace:",
		"struct: Monitor",
		"class: MonitorG",
		"struct: Rectangle",
		"noCode: get_type",
		"namespace:"
	],
	"GLib": [
		"struct: Array",
		"class: ArrayG",
		"struct: ByteArray",
		"class: ByteArray",
		"struct: Error",
		"class: ErrorG",
		"struct: HashTable",
		"class: HashTable",
		"struct: List",
		"class: ListG",
		"struct: SList",
		"class: ListSG",
		"struct: MarkupParseContext",
		"class: SimpleXML",
		"struct: PtrArray",
		"class: PtrArray",
		"struct: Scanner",
		"class: ScannerG",
		"struct: String",
		"class: StringG",
		"struct: Tree",
		"class: BBTree"
	],
	"GModule": [
		"wrap: glib"
	],
	"Pango": [
		"struct: AttrList",
		"class: PgAttributeList"
	],
	"Gst": [
		"wrap: gstreamer"
	]
];

