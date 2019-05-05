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

module gtd.GirVersion;

import std.array;
import std.conv;
import std.format;

struct GirVersion
{
	uint major;
	uint minor;
	uint micro;

	this(string _version)
	{
		parse(_version);
	}

	this(uint major, uint minor, uint micro = 0)
	{
		this.major = major;
		this.minor = minor;
		this.micro = micro;
	}

	void parse(string _version)
	{
		string[] parts = split(_version, ".");

		if ( parts.length >= 1 && !parts[0].empty )
			major = to!uint(parts[0]);
		if ( parts.length >= 2 && !parts[1].empty )
			minor = to!uint(parts[1]);
		if ( parts.length >= 3 && !parts[2].empty )
			micro = to!uint(parts[2]);
	}

	string toString() const
	{
		return format("%s.%s.%s", major, minor, micro);
	}

	void toString(scope void delegate(const(char)[]) sink) const
    {
		sink(to!string(major));
		sink(".");
		sink(to!string(minor));
		sink(".");
		sink(to!string(micro));
	}

	bool opEquals()(auto ref const GirVersion _version) const
	{
		if ( major != _version.major )
			return false;
		else if ( minor != _version.minor )
			return false;
		else if ( micro != _version.micro )
			return false;

		return true;
	}

	bool opEquals()(auto ref string _version) const
	{
		string[] parts = split(_version, ".");

		if ( parts.length >= 1 && !parts[0].empty )
		{
			uint maj = to!uint(parts[0]);

			if ( major != maj )
				return false;
		}
		if ( parts.length >= 2 && !parts[1].empty )
		{
			uint min = to!uint(parts[1]);

			if ( minor != min )
				return false;
		}
		if ( parts.length >= 3 && !parts[2].empty )
		{
			uint mic = to!uint(parts[2]);

			if ( micro != mic )
				return false;
		}

		return true;
	}

	int opCmp()(auto ref const GirVersion _version) const
	{
		if ( major != _version.major )
			return major - _version.major;
		else if ( minor != _version.minor )
			return minor - _version.minor;

		return micro - _version.micro;
	}

	int opCmp()(auto ref string _version) const
	{
		string[] parts = split(_version, ".");

		if ( parts.length >= 1 && !parts[0].empty )
		{
			uint maj = to!uint(parts[0]);

			if ( major != maj )
				return major - maj;
		}
		if ( parts.length >= 2 && !parts[1].empty )
		{
			uint min = to!uint(parts[1]);

			if ( minor != min )
				return minor - min;
		}
		if ( parts.length >= 3 && !parts[2].empty )
		{
			uint mic = to!uint(parts[2]);

			return micro - mic;
		}

		return 0;
	}
}

unittest
{
	auto v1 = GirVersion("1.2.3");
	auto v2 = GirVersion(2, 3);

	assert(v1.minor == 2);
	assert(v1 < v2);
	assert(v2 == GirVersion("2.3"));
	assert(v2 > GirVersion("1.2.3"));

	assert(v2 == "2.3");
	assert(v2 > "1.1.2");
	assert(v2 < "3.4");
	assert(v2 >= "2.3");
}
