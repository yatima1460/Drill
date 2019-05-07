module Drill.SearchEntry;



import gtk.Entry;



class SearchEntry : Entry
{

    this ()
    {
        setIconFromIconName(GtkEntryIconPosition.SECONDARY,"search");
    }

}