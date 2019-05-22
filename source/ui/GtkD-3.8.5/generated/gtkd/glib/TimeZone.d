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


module glib.TimeZone;

private import glib.ConstructionException;
private import glib.Str;
private import glib.c.functions;
public  import glib.c.types;
public  import gtkc.glibtypes;
private import gtkd.Loader;


/**
 * #GTimeZone is an opaque structure whose members cannot be accessed
 * directly.
 *
 * Since: 2.26
 */
public class TimeZone
{
	/** the main Gtk struct */
	protected GTimeZone* gTimeZone;
	protected bool ownedRef;

	/** Get the main Gtk struct */
	public GTimeZone* getTimeZoneStruct(bool transferOwnership = false)
	{
		if (transferOwnership)
			ownedRef = false;
		return gTimeZone;
	}

	/** the main Gtk struct as a void* */
	protected void* getStruct()
	{
		return cast(void*)gTimeZone;
	}

	/**
	 * Sets our main struct and passes it to the parent class.
	 */
	public this (GTimeZone* gTimeZone, bool ownedRef = false)
	{
		this.gTimeZone = gTimeZone;
		this.ownedRef = ownedRef;
	}

	~this ()
	{
		if ( Linker.isLoaded(LIBRARY_GLIB) && ownedRef )
			g_time_zone_unref(gTimeZone);
	}


	/**
	 * Creates a #GTimeZone corresponding to @identifier.
	 *
	 * @identifier can either be an RFC3339/ISO 8601 time offset or
	 * something that would pass as a valid value for the `TZ` environment
	 * variable (including %NULL).
	 *
	 * In Windows, @identifier can also be the unlocalized name of a time
	 * zone for standard time, for example "Pacific Standard Time".
	 *
	 * Valid RFC3339 time offsets are `"Z"` (for UTC) or
	 * `"±hh:mm"`.  ISO 8601 additionally specifies
	 * `"±hhmm"` and `"±hh"`.  Offsets are
	 * time values to be added to Coordinated Universal Time (UTC) to get
	 * the local time.
	 *
	 * In UNIX, the `TZ` environment variable typically corresponds
	 * to the name of a file in the zoneinfo database, or string in
	 * "std offset [dst [offset],start[/time],end[/time]]" (POSIX) format.
	 * There  are  no spaces in the specification. The name of standard
	 * and daylight savings time zone must be three or more alphabetic
	 * characters. Offsets are time values to be added to local time to
	 * get Coordinated Universal Time (UTC) and should be
	 * `"[±]hh[[:]mm[:ss]]"`.  Dates are either
	 * `"Jn"` (Julian day with n between 1 and 365, leap
	 * years not counted), `"n"` (zero-based Julian day
	 * with n between 0 and 365) or `"Mm.w.d"` (day d
	 * (0 <= d <= 6) of week w (1 <= w <= 5) of month m (1 <= m <= 12), day
	 * 0 is a Sunday).  Times are in local wall clock time, the default is
	 * 02:00:00.
	 *
	 * In Windows, the "tzn[+|–]hh[:mm[:ss]][dzn]" format is used, but also
	 * accepts POSIX format.  The Windows format uses US rules for all time
	 * zones; daylight savings time is 60 minutes behind the standard time
	 * with date and time of change taken from Pacific Standard Time.
	 * Offsets are time values to be added to the local time to get
	 * Coordinated Universal Time (UTC).
	 *
	 * g_time_zone_new_local() calls this function with the value of the
	 * `TZ` environment variable. This function itself is independent of
	 * the value of `TZ`, but if @identifier is %NULL then `/etc/localtime`
	 * will be consulted to discover the correct time zone on UNIX and the
	 * registry will be consulted or GetTimeZoneInformation() will be used
	 * to get the local time zone on Windows.
	 *
	 * If intervals are not available, only time zone rules from `TZ`
	 * environment variable or other means, then they will be computed
	 * from year 1900 to 2037.  If the maximum year for the rules is
	 * available and it is greater than 2037, then it will followed
	 * instead.
	 *
	 * See
	 * [RFC3339 §5.6](http://tools.ietf.org/html/rfc3339#section-5.6)
	 * for a precise definition of valid RFC3339 time offsets
	 * (the `time-offset` expansion) and ISO 8601 for the
	 * full list of valid time offsets.  See
	 * [The GNU C Library manual](http://www.gnu.org/s/libc/manual/html_node/TZ-Variable.html)
	 * for an explanation of the possible
	 * values of the `TZ` environment variable. See
	 * [Microsoft Time Zone Index Values](http://msdn.microsoft.com/en-us/library/ms912391%28v=winembedded.11%29.aspx)
	 * for the list of time zones on Windows.
	 *
	 * You should release the return value by calling g_time_zone_unref()
	 * when you are done with it.
	 *
	 * Params:
	 *     identifier = a timezone identifier
	 *
	 * Returns: the requested timezone
	 *
	 * Since: 2.26
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
	public this(string identifier)
	{
		auto p = g_time_zone_new(Str.toStringz(identifier));

		if(p is null)
		{
			throw new ConstructionException("null returned by new");
		}

		this(cast(GTimeZone*) p);
	}

	/**
	 * Finds an interval within @tz that corresponds to the given @time_,
	 * possibly adjusting @time_ if required to fit into an interval.
	 * The meaning of @time_ depends on @type.
	 *
	 * This function is similar to g_time_zone_find_interval(), with the
	 * difference that it always succeeds (by making the adjustments
	 * described below).
	 *
	 * In any of the cases where g_time_zone_find_interval() succeeds then
	 * this function returns the same value, without modifying @time_.
	 *
	 * This function may, however, modify @time_ in order to deal with
	 * non-existent times.  If the non-existent local @time_ of 02:30 were
	 * requested on March 14th 2010 in Toronto then this function would
	 * adjust @time_ to be 03:00 and return the interval containing the
	 * adjusted time.
	 *
	 * Params:
	 *     type = the #GTimeType of @time_
	 *     time = a pointer to a number of seconds since January 1, 1970
	 *
	 * Returns: the interval containing @time_, never -1
	 *
	 * Since: 2.26
	 */
	public int adjustTime(GTimeType type, long* time)
	{
		return g_time_zone_adjust_time(gTimeZone, type, time);
	}

	/**
	 * Finds an the interval within @tz that corresponds to the given @time_.
	 * The meaning of @time_ depends on @type.
	 *
	 * If @type is %G_TIME_TYPE_UNIVERSAL then this function will always
	 * succeed (since universal time is monotonic and continuous).
	 *
	 * Otherwise @time_ is treated as local time.  The distinction between
	 * %G_TIME_TYPE_STANDARD and %G_TIME_TYPE_DAYLIGHT is ignored except in
	 * the case that the given @time_ is ambiguous.  In Toronto, for example,
	 * 01:30 on November 7th 2010 occurred twice (once inside of daylight
	 * savings time and the next, an hour later, outside of daylight savings
	 * time).  In this case, the different value of @type would result in a
	 * different interval being returned.
	 *
	 * It is still possible for this function to fail.  In Toronto, for
	 * example, 02:00 on March 14th 2010 does not exist (due to the leap
	 * forward to begin daylight savings time).  -1 is returned in that
	 * case.
	 *
	 * Params:
	 *     type = the #GTimeType of @time_
	 *     time = a number of seconds since January 1, 1970
	 *
	 * Returns: the interval containing @time_, or -1 in case of failure
	 *
	 * Since: 2.26
	 */
	public int findInterval(GTimeType type, long time)
	{
		return g_time_zone_find_interval(gTimeZone, type, time);
	}

	/**
	 * Determines the time zone abbreviation to be used during a particular
	 * @interval of time in the time zone @tz.
	 *
	 * For example, in Toronto this is currently "EST" during the winter
	 * months and "EDT" during the summer months when daylight savings time
	 * is in effect.
	 *
	 * Params:
	 *     interval = an interval within the timezone
	 *
	 * Returns: the time zone abbreviation, which belongs to @tz
	 *
	 * Since: 2.26
	 */
	public string getAbbreviation(int interval)
	{
		return Str.toString(g_time_zone_get_abbreviation(gTimeZone, interval));
	}

	/**
	 * Determines the offset to UTC in effect during a particular @interval
	 * of time in the time zone @tz.
	 *
	 * The offset is the number of seconds that you add to UTC time to
	 * arrive at local time for @tz (ie: negative numbers for time zones
	 * west of GMT, positive numbers for east).
	 *
	 * Params:
	 *     interval = an interval within the timezone
	 *
	 * Returns: the number of seconds that should be added to UTC to get the
	 *     local time in @tz
	 *
	 * Since: 2.26
	 */
	public int getOffset(int interval)
	{
		return g_time_zone_get_offset(gTimeZone, interval);
	}

	/**
	 * Determines if daylight savings time is in effect during a particular
	 * @interval of time in the time zone @tz.
	 *
	 * Params:
	 *     interval = an interval within the timezone
	 *
	 * Returns: %TRUE if daylight savings time is in effect
	 *
	 * Since: 2.26
	 */
	public bool isDst(int interval)
	{
		return g_time_zone_is_dst(gTimeZone, interval) != 0;
	}

	alias doref = ref_;
	/**
	 * Increases the reference count on @tz.
	 *
	 * Returns: a new reference to @tz.
	 *
	 * Since: 2.26
	 */
	public TimeZone ref_()
	{
		auto p = g_time_zone_ref(gTimeZone);

		if(p is null)
		{
			return null;
		}

		return new TimeZone(cast(GTimeZone*) p, true);
	}

	/**
	 * Decreases the reference count on @tz.
	 *
	 * Since: 2.26
	 */
	public void unref()
	{
		g_time_zone_unref(gTimeZone);
	}
}
