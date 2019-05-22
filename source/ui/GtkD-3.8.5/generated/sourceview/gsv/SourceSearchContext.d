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


module gsv.SourceSearchContext;

private import gio.AsyncResultIF;
private import gio.Cancellable;
private import glib.ConstructionException;
private import glib.ErrorG;
private import glib.GException;
private import glib.MemorySlice;
private import glib.Str;
private import gobject.ObjectG;
private import gsv.SourceBuffer;
private import gsv.SourceSearchSettings;
private import gsv.SourceStyle;
private import gsv.c.functions;
public  import gsv.c.types;
public  import gsvc.gsvtypes;
private import gtk.TextIter;


/** */
public class SourceSearchContext : ObjectG
{
	/** the main Gtk struct */
	protected GtkSourceSearchContext* gtkSourceSearchContext;

	/** Get the main Gtk struct */
	public GtkSourceSearchContext* getSourceSearchContextStruct(bool transferOwnership = false)
	{
		if (transferOwnership)
			ownedRef = false;
		return gtkSourceSearchContext;
	}

	/** the main Gtk struct as a void* */
	protected override void* getStruct()
	{
		return cast(void*)gtkSourceSearchContext;
	}

	/**
	 * Sets our main struct and passes it to the parent class.
	 */
	public this (GtkSourceSearchContext* gtkSourceSearchContext, bool ownedRef = false)
	{
		this.gtkSourceSearchContext = gtkSourceSearchContext;
		super(cast(GObject*)gtkSourceSearchContext, ownedRef);
	}


	/** */
	public static GType getType()
	{
		return gtk_source_search_context_get_type();
	}

	/**
	 * Creates a new search context, associated with @buffer, and customized with
	 * @settings. If @settings is %NULL, a new #GtkSourceSearchSettings object will
	 * be created, that you can retrieve with
	 * gtk_source_search_context_get_settings().
	 *
	 * Params:
	 *     buffer = a #GtkSourceBuffer.
	 *     settings = a #GtkSourceSearchSettings, or %NULL.
	 *
	 * Returns: a new search context.
	 *
	 * Since: 3.10
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
	public this(SourceBuffer buffer, SourceSearchSettings settings)
	{
		auto p = gtk_source_search_context_new((buffer is null) ? null : buffer.getSourceBufferStruct(), (settings is null) ? null : settings.getSourceSearchSettingsStruct());

		if(p is null)
		{
			throw new ConstructionException("null returned by new");
		}

		this(cast(GtkSourceSearchContext*) p, true);
	}

	/**
	 * Synchronous backward search. It is recommended to use the asynchronous
	 * functions instead, to not block the user interface. However, if you are sure
	 * that the @buffer is small, this function is more convenient to use.
	 *
	 * Deprecated: Use gtk_source_search_context_backward2() instead.
	 *
	 * Params:
	 *     iter = start of search.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.10
	 */
	public bool backward(TextIter iter, out TextIter matchStart, out TextIter matchEnd)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();

		auto p = gtk_source_search_context_backward(gtkSourceSearchContext, (iter is null) ? null : iter.getTextIterStruct(), outmatchStart, outmatchEnd) != 0;

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);

		return p;
	}

	/**
	 * Synchronous backward search. It is recommended to use the asynchronous
	 * functions instead, to not block the user interface. However, if you are sure
	 * that the @buffer is small, this function is more convenient to use.
	 *
	 * The difference with gtk_source_search_context_backward() is that the
	 * @has_wrapped_around out parameter has been added for convenience.
	 *
	 * If the #GtkSourceSearchSettings:wrap-around property is %FALSE, this function
	 * doesn't try to wrap around.
	 *
	 * The @has_wrapped_around out parameter is set independently of whether a match
	 * is found. So if this function returns %FALSE, @has_wrapped_around will have
	 * the same value as the #GtkSourceSearchSettings:wrap-around property.
	 *
	 * Params:
	 *     iter = start of search.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *     hasWrappedAround = return location to know whether the
	 *         search has wrapped around, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.22
	 */
	public bool backward2(TextIter iter, out TextIter matchStart, out TextIter matchEnd, out bool hasWrappedAround)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();
		int outhasWrappedAround;

		auto p = gtk_source_search_context_backward2(gtkSourceSearchContext, (iter is null) ? null : iter.getTextIterStruct(), outmatchStart, outmatchEnd, &outhasWrappedAround) != 0;

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);
		hasWrappedAround = (outhasWrappedAround == 1);

		return p;
	}

	/**
	 * The asynchronous version of gtk_source_search_context_backward2().
	 *
	 * See the documentation of gtk_source_search_context_backward2() for more
	 * details.
	 *
	 * See the #GAsyncResult documentation to know how to use this function.
	 *
	 * If the operation is cancelled, the @callback will only be called if
	 * @cancellable was not %NULL. gtk_source_search_context_backward_async() takes
	 * ownership of @cancellable, so you can unref it after calling this function.
	 *
	 * Params:
	 *     iter = start of search.
	 *     cancellable = a #GCancellable, or %NULL.
	 *     callback = a #GAsyncReadyCallback to call when the operation is finished.
	 *     userData = the data to pass to the @callback function.
	 *
	 * Since: 3.10
	 */
	public void backwardAsync(TextIter iter, Cancellable cancellable, GAsyncReadyCallback callback, void* userData)
	{
		gtk_source_search_context_backward_async(gtkSourceSearchContext, (iter is null) ? null : iter.getTextIterStruct(), (cancellable is null) ? null : cancellable.getCancellableStruct(), callback, userData);
	}

	/**
	 * Finishes a backward search started with
	 * gtk_source_search_context_backward_async().
	 *
	 * Deprecated: Use gtk_source_search_context_backward_finish2() instead.
	 *
	 * Params:
	 *     result = a #GAsyncResult.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.10
	 *
	 * Throws: GException on failure.
	 */
	public bool backwardFinish(AsyncResultIF result, out TextIter matchStart, out TextIter matchEnd)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();
		GError* err = null;

		auto p = gtk_source_search_context_backward_finish(gtkSourceSearchContext, (result is null) ? null : result.getAsyncResultStruct(), outmatchStart, outmatchEnd, &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);

		return p;
	}

	/**
	 * Finishes a backward search started with
	 * gtk_source_search_context_backward_async().
	 *
	 * See the documentation of gtk_source_search_context_backward2() for more
	 * details.
	 *
	 * Params:
	 *     result = a #GAsyncResult.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *     hasWrappedAround = return location to know whether the
	 *         search has wrapped around, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.22
	 *
	 * Throws: GException on failure.
	 */
	public bool backwardFinish2(AsyncResultIF result, out TextIter matchStart, out TextIter matchEnd, out bool hasWrappedAround)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();
		int outhasWrappedAround;
		GError* err = null;

		auto p = gtk_source_search_context_backward_finish2(gtkSourceSearchContext, (result is null) ? null : result.getAsyncResultStruct(), outmatchStart, outmatchEnd, &outhasWrappedAround, &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);
		hasWrappedAround = (outhasWrappedAround == 1);

		return p;
	}

	/**
	 * Synchronous forward search. It is recommended to use the asynchronous
	 * functions instead, to not block the user interface. However, if you are sure
	 * that the @buffer is small, this function is more convenient to use.
	 *
	 * Deprecated: Use gtk_source_search_context_forward2() instead.
	 *
	 * Params:
	 *     iter = start of search.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.10
	 */
	public bool forward(TextIter iter, out TextIter matchStart, out TextIter matchEnd)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();

		auto p = gtk_source_search_context_forward(gtkSourceSearchContext, (iter is null) ? null : iter.getTextIterStruct(), outmatchStart, outmatchEnd) != 0;

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);

		return p;
	}

	/**
	 * Synchronous forward search. It is recommended to use the asynchronous
	 * functions instead, to not block the user interface. However, if you are sure
	 * that the @buffer is small, this function is more convenient to use.
	 *
	 * The difference with gtk_source_search_context_forward() is that the
	 * @has_wrapped_around out parameter has been added for convenience.
	 *
	 * If the #GtkSourceSearchSettings:wrap-around property is %FALSE, this function
	 * doesn't try to wrap around.
	 *
	 * The @has_wrapped_around out parameter is set independently of whether a match
	 * is found. So if this function returns %FALSE, @has_wrapped_around will have
	 * the same value as the #GtkSourceSearchSettings:wrap-around property.
	 *
	 * Params:
	 *     iter = start of search.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *     hasWrappedAround = return location to know whether the
	 *         search has wrapped around, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.22
	 */
	public bool forward2(TextIter iter, out TextIter matchStart, out TextIter matchEnd, out bool hasWrappedAround)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();
		int outhasWrappedAround;

		auto p = gtk_source_search_context_forward2(gtkSourceSearchContext, (iter is null) ? null : iter.getTextIterStruct(), outmatchStart, outmatchEnd, &outhasWrappedAround) != 0;

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);
		hasWrappedAround = (outhasWrappedAround == 1);

		return p;
	}

	/**
	 * The asynchronous version of gtk_source_search_context_forward2().
	 *
	 * See the documentation of gtk_source_search_context_forward2() for more
	 * details.
	 *
	 * See the #GAsyncResult documentation to know how to use this function.
	 *
	 * If the operation is cancelled, the @callback will only be called if
	 * @cancellable was not %NULL. gtk_source_search_context_forward_async() takes
	 * ownership of @cancellable, so you can unref it after calling this function.
	 *
	 * Params:
	 *     iter = start of search.
	 *     cancellable = a #GCancellable, or %NULL.
	 *     callback = a #GAsyncReadyCallback to call when the operation is finished.
	 *     userData = the data to pass to the @callback function.
	 *
	 * Since: 3.10
	 */
	public void forwardAsync(TextIter iter, Cancellable cancellable, GAsyncReadyCallback callback, void* userData)
	{
		gtk_source_search_context_forward_async(gtkSourceSearchContext, (iter is null) ? null : iter.getTextIterStruct(), (cancellable is null) ? null : cancellable.getCancellableStruct(), callback, userData);
	}

	/**
	 * Finishes a forward search started with
	 * gtk_source_search_context_forward_async().
	 *
	 * Deprecated: Use gtk_source_search_context_forward_finish2() instead.
	 *
	 * Params:
	 *     result = a #GAsyncResult.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.10
	 *
	 * Throws: GException on failure.
	 */
	public bool forwardFinish(AsyncResultIF result, out TextIter matchStart, out TextIter matchEnd)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();
		GError* err = null;

		auto p = gtk_source_search_context_forward_finish(gtkSourceSearchContext, (result is null) ? null : result.getAsyncResultStruct(), outmatchStart, outmatchEnd, &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);

		return p;
	}

	/**
	 * Finishes a forward search started with
	 * gtk_source_search_context_forward_async().
	 *
	 * See the documentation of gtk_source_search_context_forward2() for more
	 * details.
	 *
	 * Params:
	 *     result = a #GAsyncResult.
	 *     matchStart = return location for start of match, or %NULL.
	 *     matchEnd = return location for end of match, or %NULL.
	 *     hasWrappedAround = return location to know whether the
	 *         search has wrapped around, or %NULL.
	 *
	 * Returns: whether a match was found.
	 *
	 * Since: 3.22
	 *
	 * Throws: GException on failure.
	 */
	public bool forwardFinish2(AsyncResultIF result, out TextIter matchStart, out TextIter matchEnd, out bool hasWrappedAround)
	{
		GtkTextIter* outmatchStart = sliceNew!GtkTextIter();
		GtkTextIter* outmatchEnd = sliceNew!GtkTextIter();
		int outhasWrappedAround;
		GError* err = null;

		auto p = gtk_source_search_context_forward_finish2(gtkSourceSearchContext, (result is null) ? null : result.getAsyncResultStruct(), outmatchStart, outmatchEnd, &outhasWrappedAround, &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		matchStart = ObjectG.getDObject!(TextIter)(outmatchStart, true);
		matchEnd = ObjectG.getDObject!(TextIter)(outmatchEnd, true);
		hasWrappedAround = (outhasWrappedAround == 1);

		return p;
	}

	/**
	 * Returns: the associated buffer.
	 *
	 * Since: 3.10
	 */
	public SourceBuffer getBuffer()
	{
		auto p = gtk_source_search_context_get_buffer(gtkSourceSearchContext);

		if(p is null)
		{
			return null;
		}

		return ObjectG.getDObject!(SourceBuffer)(cast(GtkSourceBuffer*) p);
	}

	/**
	 * Returns: whether to highlight the search occurrences.
	 *
	 * Since: 3.10
	 */
	public bool getHighlight()
	{
		return gtk_source_search_context_get_highlight(gtkSourceSearchContext) != 0;
	}

	/**
	 * Returns: the #GtkSourceStyle to apply on search matches.
	 *
	 * Since: 3.16
	 */
	public SourceStyle getMatchStyle()
	{
		auto p = gtk_source_search_context_get_match_style(gtkSourceSearchContext);

		if(p is null)
		{
			return null;
		}

		return ObjectG.getDObject!(SourceStyle)(cast(GtkSourceStyle*) p);
	}

	/**
	 * Gets the position of a search occurrence. If the buffer is not already fully
	 * scanned, the position may be unknown, and -1 is returned. If 0 is returned,
	 * it means that this part of the buffer has already been scanned, and that
	 * @match_start and @match_end don't delimit an occurrence.
	 *
	 * Params:
	 *     matchStart = the start of the occurrence.
	 *     matchEnd = the end of the occurrence.
	 *
	 * Returns: the position of the search occurrence. The first occurrence has the
	 *     position 1 (not 0). Returns 0 if @match_start and @match_end don't delimit
	 *     an occurrence. Returns -1 if the position is not yet known.
	 *
	 * Since: 3.10
	 */
	public int getOccurrencePosition(TextIter matchStart, TextIter matchEnd)
	{
		return gtk_source_search_context_get_occurrence_position(gtkSourceSearchContext, (matchStart is null) ? null : matchStart.getTextIterStruct(), (matchEnd is null) ? null : matchEnd.getTextIterStruct());
	}

	/**
	 * Gets the total number of search occurrences. If the buffer is not already
	 * fully scanned, the total number of occurrences is unknown, and -1 is
	 * returned.
	 *
	 * Returns: the total number of search occurrences, or -1 if unknown.
	 *
	 * Since: 3.10
	 */
	public int getOccurrencesCount()
	{
		return gtk_source_search_context_get_occurrences_count(gtkSourceSearchContext);
	}

	/**
	 * Regular expression patterns must follow certain rules. If
	 * #GtkSourceSearchSettings:search-text breaks a rule, the error can be retrieved
	 * with this function. The error domain is #G_REGEX_ERROR.
	 *
	 * Free the return value with g_error_free().
	 *
	 * Returns: the #GError, or %NULL if the pattern is valid.
	 *
	 * Since: 3.10
	 */
	public ErrorG getRegexError()
	{
		auto p = gtk_source_search_context_get_regex_error(gtkSourceSearchContext);

		if(p is null)
		{
			return null;
		}

		return new ErrorG(cast(GError*) p, true);
	}

	/**
	 * Returns: the search settings.
	 *
	 * Since: 3.10
	 */
	public SourceSearchSettings getSettings()
	{
		auto p = gtk_source_search_context_get_settings(gtkSourceSearchContext);

		if(p is null)
		{
			return null;
		}

		return ObjectG.getDObject!(SourceSearchSettings)(cast(GtkSourceSearchSettings*) p);
	}

	/**
	 * Replaces a search match by another text. If @match_start and @match_end
	 * doesn't correspond to a search match, %FALSE is returned.
	 *
	 * For a regular expression replacement, you can check if @replace is valid by
	 * calling g_regex_check_replacement(). The @replace text can contain
	 * backreferences; read the g_regex_replace() documentation for more details.
	 *
	 * Deprecated: Use gtk_source_search_context_replace2() instead.
	 *
	 * Params:
	 *     matchStart = the start of the match to replace.
	 *     matchEnd = the end of the match to replace.
	 *     replace = the replacement text.
	 *     replaceLength = the length of @replace in bytes, or -1.
	 *
	 * Returns: whether the match has been replaced.
	 *
	 * Since: 3.10
	 *
	 * Throws: GException on failure.
	 */
	public bool replace(TextIter matchStart, TextIter matchEnd, string replace, int replaceLength)
	{
		GError* err = null;

		auto p = gtk_source_search_context_replace(gtkSourceSearchContext, (matchStart is null) ? null : matchStart.getTextIterStruct(), (matchEnd is null) ? null : matchEnd.getTextIterStruct(), Str.toStringz(replace), replaceLength, &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		return p;
	}

	/**
	 * Replaces a search match by another text. If @match_start and @match_end
	 * doesn't correspond to a search match, %FALSE is returned.
	 *
	 * Unlike with gtk_source_search_context_replace(), the @match_start and
	 * @match_end iters are revalidated to point to the replacement text boundaries.
	 *
	 * For a regular expression replacement, you can check if @replace is valid by
	 * calling g_regex_check_replacement(). The @replace text can contain
	 * backreferences; read the g_regex_replace() documentation for more details.
	 *
	 * Params:
	 *     matchStart = the start of the match to replace.
	 *     matchEnd = the end of the match to replace.
	 *     replace = the replacement text.
	 *     replaceLength = the length of @replace in bytes, or -1.
	 *
	 * Returns: whether the match has been replaced.
	 *
	 * Since: 3.22
	 *
	 * Throws: GException on failure.
	 */
	public bool replace2(TextIter matchStart, TextIter matchEnd, string replace, int replaceLength)
	{
		GError* err = null;

		auto p = gtk_source_search_context_replace2(gtkSourceSearchContext, (matchStart is null) ? null : matchStart.getTextIterStruct(), (matchEnd is null) ? null : matchEnd.getTextIterStruct(), Str.toStringz(replace), replaceLength, &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		return p;
	}

	/**
	 * Replaces all search matches by another text. It is a synchronous function, so
	 * it can block the user interface.
	 *
	 * For a regular expression replacement, you can check if @replace is valid by
	 * calling g_regex_check_replacement(). The @replace text can contain
	 * backreferences; read the g_regex_replace() documentation for more details.
	 *
	 * Params:
	 *     replace = the replacement text.
	 *     replaceLength = the length of @replace in bytes, or -1.
	 *
	 * Returns: the number of replaced matches.
	 *
	 * Since: 3.10
	 *
	 * Throws: GException on failure.
	 */
	public uint replaceAll(string replace, int replaceLength)
	{
		GError* err = null;

		auto p = gtk_source_search_context_replace_all(gtkSourceSearchContext, Str.toStringz(replace), replaceLength, &err);

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		return p;
	}

	/**
	 * Enables or disables the search occurrences highlighting.
	 *
	 * Params:
	 *     highlight = the setting.
	 *
	 * Since: 3.10
	 */
	public void setHighlight(bool highlight)
	{
		gtk_source_search_context_set_highlight(gtkSourceSearchContext, highlight);
	}

	/**
	 * Set the style to apply on search matches. If @match_style is %NULL, default
	 * theme's scheme 'match-style' will be used.
	 * To enable or disable the search highlighting, use
	 * gtk_source_search_context_set_highlight().
	 *
	 * Params:
	 *     matchStyle = a #GtkSourceStyle, or %NULL.
	 *
	 * Since: 3.16
	 */
	public void setMatchStyle(SourceStyle matchStyle)
	{
		gtk_source_search_context_set_match_style(gtkSourceSearchContext, (matchStyle is null) ? null : matchStyle.getSourceStyleStruct());
	}

	/**
	 * Associate a #GtkSourceSearchSettings with the search context. If @settings is
	 * %NULL, a new one will be created.
	 *
	 * The search context holds a reference to @settings.
	 *
	 * Deprecated: The #GtkSourceSearchContext:settings property will become a
	 * construct-only property in a future version. Create a new
	 * #GtkSourceSearchContext instead, or change the #GtkSourceSearchSettings
	 * properties. When the #GtkSourceSearchContext:settings property will become
	 * construct-only, it will be possible to simplify some code that needed to
	 * listen to the notify::settings signal.
	 *
	 * Params:
	 *     settings = the new #GtkSourceSearchSettings, or %NULL.
	 *
	 * Since: 3.10
	 */
	public void setSettings(SourceSearchSettings settings)
	{
		gtk_source_search_context_set_settings(gtkSourceSearchContext, (settings is null) ? null : settings.getSourceSearchSettingsStruct());
	}
}
