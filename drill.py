#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# https://github.com/yatima1460/drill
#
# License: GPLv2
#   See the LICENSE file for more information
#
# Credits:
#   Federico Santamorena, Main Developer
#
#
# FIXME: update list when new results found
# FIXME: remove duplicates if symbolic links make a mess
# FIXME: root folders of threads do not appear in search?
# FIXME: sorting is messy
# FIXME: it seems tkinter misses some double clicks when the mainloop takes too much time
# FIXME: right clicking while hovering a row should select it and open the containing folder
# 
#
# User
#
# TODO: AppImage/Snap/Flatpak
# TODO: folders actual size
# TODO: tmp cache index file to speedup boot time
# TODO: metadata searching (mp3, etc...)
# TODO: ESC to close
# TODO: alternate row colors
# TODO: threaded search in index to remove hangs
# TODO: drag and drop (is this even possible with tkinter?)
# TODO: switch to GTK3?
# TODO: memoization
# TODO:  percentage of crawling
# TODO: help in gui (maybe later when more search ways available)
#
# Developer
#
# TODO: NVM could benefit when multiple threads are run for the same disk?
# TODO: statistics to check which are the black hole folders (time crawling inside?)
# TODO: publish to apt
# TODO: remove the print statements and replace them with a log library?
# TODO: cat /proc/mounts for starting the threads
# TODO: cli-version?
# TODO: threadpool?
# TODO: code cleanup: private fields with __ etc
# TODO: add documentation and comments
# TODO: fix the messy imports
# TODO: CASE_INSENSITIVE flag
# TODO: WINDOW_CENTERED flag
# TODO: dump NTFS partition file index?
# TODO: dump ext4 partition file index?

################
#####CONFIG#####
################

VERSION = "v0.1.1"

# nice 16:9 ratio and is a good res for laptops with 1366x768 low res
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 450

# how many items are added to the table every frame
# decrease this if the UI lags
# 100 works well on an old 8-core AMD CPU
UI_BUFFER_SIZE = 100

# TO IMPLEMENT:
CASE_INSENSITIVE = True
WINDOW_CENTERED = True
# threads will be stopped when this is reached
MEMORY_CUTOFF = 1073741824  # 1GB of RAM


################
################
################

def direntry_ok(direntry):
    # HACK: remove these branch predictions, this is very ugly and temporary

    # possibly add Windows.old to this list?
    bad_matches = ["node_modules", "Windows", "$Recycle.Bin", "$RECYCLE.BIN"]
    bad_fuzzies = ["WindowsApps", "site-packages", "android-ndk", "android-sdk",
                   "npm-cache"]
    bad_paths = ["ZeroNet-master/data", "go/src", "/snap/"]

    # catch empty dir
    if direntry.name is None:
        return False

    # ignore hidden dirs
    if direntry.name[0] == ".":
        return False

    # ignore exact matches
    if direntry.name in bad_matches:
        return False

    # ignore bad fuzzies
    for bad_fuzzy in bad_fuzzies:
        if bad_fuzzy in direntry.name:
            return False

    # ignore bad paths
    for bad_path in bad_paths:
        if bad_path in direntry.path:
            return False

    # ignore snap directory
    # if "home" in direntry.path and "snap" == direntry.name:
    #     return False
    return True


################
################
################


import sys

if sys.version_info >= (3, 0):
    import importlib
    import tkinter as tk
    import tkinter.font as tkFont
    import tkinter.ttk as ttk
    # HACK: fix me
    from tkinter import *
    # from tkinter import messagebox, BOTH, BOTTOM, LEFT, NO, RIGHT, TOP, YES, W, X, Tk, Frame, Label, StringVar, Entry
    from queue import Queue

    import psutil
    import datetime
    import os
    import threading
    import time
    import re
    from threading import Thread

    if os.supports_follow_symlinks:
        os.follow_symlinks = False
else:
    import tkMessageBox

    tkMessageBox.showerror("Python 3", "You need Python 3!")
    exit(1)


def sortby(tree, col, descending):
    """sort tree contents when a column header is clicked on"""
    # grab values to sort
    data = [(tree.set(child, col), child) for child in tree.get_children('')]
    # if the data to be sorted is numeric change to float
    # data =  change_numeric(data)
    # now sort the data in place
    data.sort(reverse=descending)
    for ix, item in enumerate(data):
        tree.move(item[1], '', ix)
    # switch the heading so it will sort in the opposite direction
    tree.heading(col, command=lambda col=col: sortby(
        tree, col, int(not descending)))


class FileInfo:
    # HACK fix this goddamn class
    path = ""
    name = ""

    hidden = False

    parent = ""

    is_dir = False
    is_file = False
    type_str = ""

    size = -1
    size_str = "-1"
    time_modified = 0
    time_modified_str = ""

    def open_file(self):
        if self.is_dir:
            import subprocess
            subprocess.Popen(['xdg-open', self.path])

    def open_containing_folder(self):
        import subprocess
        subprocess.Popen(['xdg-open', self.parent])


def de_emojify(inputString):
    # HACK: is there even a fix for this?
    '''
    Still sad for the need to use this function
    Emojis breaks Python Tkinter
    '''
    return inputString.encode('UTF-8', 'ignore').decode('UTF-8')


def size_to_human_readable(num, suffix='B'):
    for unit in ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)


class Crawler(Thread):
    current_depth = 0

    def __init__(self, root, index, excludes=[]):
        Thread.__init__(self)
        self.root = root
        self.queue = [root]
        self.index = index
        self.running = True
        self.excludes = excludes

    def stop_async(self):
        self.running = False

    def get_index(self):
        i = self.index
        self.index = []
        return i

    def __repr__(self):
        return "Thread(\"" + self.root + "\")"

    def __str__(self):
        return self.root

    def join(self):
        super().join(1000)
        print("Thread for \"" + self.root + "\" was stopped cleanly")

    def get_current_depth(self):
        return self.current_depth

    def run(self):
        print(repr(self), " started")
        print(repr(self), " will ignore: ", self.excludes)
        while len(self.queue):
            next_queue = []
            for parent in self.queue:
                # generic exceptions seems faster than branch prediction with if os.access(parent, os.R_OK):
                try:
                    for direntry in os.scandir(parent):
                        def do():

                            fi = FileInfo()

                            
                            txt = "The rain in Spain"
                            for rule in self.excludes:
                                x = re.search(rule, direntry.path)
                                if x != None:
                                    return
                            self.current_depth = direntry.path.count("/")
                            fi.hidden = direntry.name[0] == "."
                            fi.name = de_emojify(direntry.name)
                            fi.path = direntry.path
                            stats = direntry.stat()
                            fi.time_modified = stats.st_mtime
                            fi.size = stats.st_size
                            fi.parent = parent
                            fi.is_file = direntry.is_file()
                            fi.is_dir = direntry.is_dir()
                            fi.type_str = ["Folder", "File"][fi.is_file]
                            fi.size_str = size_to_human_readable(fi.size)

                            # TODO: this is ugly:
                            fi.time_modified_str = datetime.datetime.utcfromtimestamp(
                                int(fi.time_modified)).isoformat().replace("T", " ")

                            # if the file is a directory and we have read access append it to the queue scan
                            # TODO: use st_mode inside direntry instead of os.access
                            if direntry.is_dir() and os.access(direntry.path, os.R_OK):
                                if direntry.path in self.excludes:
                                    print(repr(self), direntry.path, " ignored ")
                                else:
                                    next_queue.append(fi.path)
                            self.index.append(fi)

                        def dont():
                            return

                        # prevents branch prediction
                        [dont, do][self.running]()

                except Exception as e:
                    print(e, file=sys.stderr)
            self.queue = next_queue
        if len(self.queue) == 0:  # HACK: prevents that this line is printed when stopping the thread?
            print("Thread for \"" + self.root + "\" finished its job")


class ResultsView(ttk.Treeview):
    '''
    The results widget shows the results and manages the crawlers
    '''

    # The columns of the results window
    MULTICOLUMN_HEADERS = ['Type', 'Name', 'Path', "Size", "Date Modified"]
    search_value = ""
    threads = []
    index = []
    list_dirty = False
    ui_buffer = Queue()

    def __init__(self, master=None, blocklist=[], **kw):
        # style = ttk.Style()
        # style.element_create("Custom.Treeheading.border", "from", "default")
        # style.layout("Custom.Treeview.Heading", [
        #     ("Custom.Treeheading.cell", {'sticky': 'nswe'}),
        #     ("Custom.Treeheading.border", {'sticky':'nswe', 'children': [
        #         ("Custom.Treeheading.padding", {'sticky':'nswe', 'children': [
        #             ("Custom.Treeheading.image", {'side':'right', 'sticky':''}),
        #             ("Custom.Treeheading.text", {'sticky':'we'})
        #         ]})
        #     ]}),
        # ])
        # style.configure("Custom.Treeview.Heading", background="lightgrey", foreground="black", relief="flat")
        # style.map("Custom.Treeview.Heading", relief=[('active','sunken'),('pressed','sunken')])
        #
        # style="Custom.Treeview",
        super().__init__(selectmode="browse", master=master, columns=self.MULTICOLUMN_HEADERS, show="headings", **kw)
        self.bind("<Button-1>", func=self.list_leftclick)
        self.bind("<Double-1>", self.list_doubleleftclick)

        self.bind("<Button-3>", func=self.list_rightclick)
        # self.bind("<<TreeviewSelect>>", func=self.treeviewselect)
        # self.bind("<<TreeviewOpen>>", func=self.treeviewopen)
        # self.bind("<<TreeviewClose>>", func=self.treeviewclose)
        # self.tag_bind("File", sequence=None, callback=print("OwO"))
        # self.bind('<FocusOut>', lambda e: self.selection())

        #
        self.bind("<Return>", self.list_doubleleftclick)
        # self.bind("<Spacebar>", self.list_doubleclick  )
        # t = Crawler("/etc",self.index)

        partitions = psutil.disk_partitions()
        mountpoints = list(map(lambda x: x.mountpoint, partitions))
        
        print("Mountpoints to scan: ", mountpoints)
        for mountpoint in mountpoints:
            print("Starting thread for: ", mountpoint)
            crawler_exclusion_list = blocklist[:]
            cp_mountpoints = mountpoints[:]
            cp_mountpoints.remove(mountpoint)
            cp_mountpoints = list(map(lambda x: "^"+x+"$",cp_mountpoints))
            crawler_exclusion_list += cp_mountpoints
            assert mountpoint not in crawler_exclusion_list, "crawler mountpoint can't be excluded"
            t = Crawler(mountpoint, self.index, excludes=crawler_exclusion_list)

            t.start()
            self.threads.append(t)

    def mark_dirty(self):
        self.list_dirty = True

    # def read_crawlers(self):
    #     for thread in self.threads:
    #         thread_index = thread.get_index()
    #         self.index += thread_index

    def stop_crawlers_async(self):
        for thread in self.threads:
            thread.stop_async()

    def get_average_crawlers_depth(self):
        s = 0.0
        for thread in self.threads:
            s += thread.get_current_depth()
        return round(s / len(self.threads), 2)

    def __len__(self):
        '''
        Returns how many items are being shown
        '''
        return len(self.get_children())

    def index_count(self):
        return len(self.index)

    def set_search_value(self, value):
        if value != self.search_value:
            self.search_value = value
            self.list_dirty = True

    def update_view(self):
        if self.list_dirty:
            self.search_value = self.search_value.lower().strip()
            if len(self.search_value) != 0:
                print("search activated for value:", self.search_value)

                # clear the previous UI buffer that adds the results of
                # the previous search to the UI

                self.ui_buffer.queue.clear()
                print("ui_buffer cleared")
                # fileinfo_filtered = []

                # clear the UI list
                self.delete(*self.get_children())
                print("UI cleared")

                # search the results
                # and add them to the UI buffer
                print("results search started...")
                # results_count = 0

                tokens = self.search_value.split(" ")
                for fileinfo in self.index:
                    all_ok = True
                    for token in tokens:
                        if token not in fileinfo.name.lower():
                            all_ok = False
                            break
                    if all_ok:
                        self.ui_buffer.put((fileinfo.type_str, fileinfo.name, fileinfo.parent,
                                            fileinfo.size_str, fileinfo.time_modified_str,))

                        # results_count += 1
                print("results found", self.ui_buffer.qsize())

                # update the found label count
                # found_label.configure(text=ui_buffer.qsize())

                # list is now ok no need to do anything else
                self.list_dirty = False

            else:
                # if search is empty string just clear everything
                # self.found_label.configure(text="0")
                self.ui_buffer.queue.clear()
                self.delete(*self.get_children())

        # if there are elements to add to the UI from a previous search add them
        # this is done to prevent UI hanging
        try:
            # if ui_buffer.qsize() != 0:
            for i in range(0, UI_BUFFER_SIZE):
                self.insert('', END, open=False, values=self.ui_buffer.get_nowait())


        except Exception as e:
            pass

    def list_doubleleftclick(self, event):
        item = self.selection()
        if item is not None:
            import platform
            item = self.item(item, "values")
            path = os.path.join(item[2], item[1])
            osname = platform.system()
            if osname == "Linux":
                import gi
                gi.require_version("Gtk", "3.0")
                from gi.repository import Gtk, Gdk
                screen = Gdk.get_default_root_window().get_screen()
                success = Gtk.show_uri(screen,"file:///"+path, Gdk.CURRENT_TIME)
                return
            if osname == "Windows":
                os.startfile(path)
                return
            if osname == "Darwin":
                import subprocess
                subprocess.call(['open', path])
                return

    def list_leftclick(self, event):
        print("list_leftclick")
        self.focus()
        # self.s = self.after(1000,self.list_realleftclick,event)
        # return 'break'
        # print(event)
        # return 'break'
        # pass

    def list_realleftclick(self, event):
        print("list_realleftclick")

    def list_rightclick(self, event):
        item = self.selection()
        import subprocess
        if item is not None:
            item = self.item(item, "values")
            # TODO: messagebox if error from xdg-open
            subprocess.Popen(['xdg-open', item[2]])
        return
        menu = tk.Menu(event.widget)
        menu.add_command(label="Open folder", command="")
        menu.add_command(label="Open", command="")
        # menu.add_command(label="Cut", command="self.text.storeobj['Cut']")
        # menu.add_command(label="Paste", command="elf.text.storeobj['Paste']")
        # menu.add_separator()
        # menu.add_command(label="Select All", command="self.text.storeobj['SelectAll']")
        # menu.add_separator()
        menu.tk_popup(event.x_root, event.y_root)
        print("right click", event)

    def treeviewselect(self, event):
        print("treeviewselect")
        return 'break'
        pass

    def treeviewopen(self, event):
        print("treeviewopen")
        return "break"

    def treeviewclose(self, event):
        print("treeviewclose")
        return "break"


class Drill:
    TITLE = "Drill " + VERSION
    GITHUB_URL = "https://github.com/yatima1460/drill"

    def __init__(self, *args, **kwargs):
        print("Drill %s - Federico Santamorena" % VERSION)
        print(self.GITHUB_URL)

        with open("blocklists/global.txt",'r') as f:
            self.blocklist = f.read().splitlines()

        self.process = psutil.Process(os.getpid())
        self.running = True
        self.create_window()

    def search_callback(self, sv):
        self.multicolumn_tree.set_search_value(sv.get())

    def github_open(self):
        import webbrowser
        webbrowser.open(self.GITHUB_URL)

    def create_window(self):
        self.window = Tk()
        self.window.title(self.TITLE)
        # imgicon = PhotoImage(file=os.path.join(os.getcwd(),'folder.gif'))
        # self.window.tk.call('wm', 'iconphoto', self.window._w, imgicon)
        ICON_NAME = "icon.png"
        if os.path.isfile(ICON_NAME):
            self.window.tk.call('wm', 'iconphoto', self.window._w, tk.PhotoImage(file=ICON_NAME))

        # center the window
        ws = self.window.winfo_screenwidth()
        hs = self.window.winfo_screenheight()
        x = (ws / 2) - (WINDOW_WIDTH / 2)
        y = (hs / 2) - (WINDOW_HEIGHT / 2)
        self.window.geometry('%dx%d+%d+%d' %
                             (WINDOW_WIDTH, WINDOW_HEIGHT, x, y))

        bottom_widgets_group = Frame(self.window, bd=1, relief="sunken", )

        self.found_label = Label(bottom_widgets_group, text="0")
        self.indexed_label = Label(bottom_widgets_group, text="0")
        self.memory_usage_label = Label(bottom_widgets_group, text="Memory used: (pip3 install psutil)")
        self.uibuffer_label = Label(bottom_widgets_group, text="0")
        self.active_threads = Label(bottom_widgets_group, text="0")
        self.average_depth_label = Label(bottom_widgets_group, text="0")
        self.github_button = Button(bottom_widgets_group, text="GitHub", relief="raise", command=self.github_open)

        sv = StringVar()
        sv.trace("w", lambda name, index, mode, sv=sv: self.search_callback(sv))

        search_input_field = Entry(self.window, textvariable=sv)
        search_input_field.pack(side=TOP, fill=X, anchor=W, expand=NO)

        container = ttk.Frame()
        container.pack(fill='both', expand=True)

        # create a treeview with dual scrollbars
        self.multicolumn_tree = ResultsView(blocklist=self.blocklist)

        # self.multicolumn_tree.bind("<Button-3>", list_rightclick)
        vertical_scrollbar = ttk.Scrollbar(orient="vertical", command=self.multicolumn_tree.yview)
        horizontal_scrollbar = ttk.Scrollbar(orient="horizontal",
                                             command=self.multicolumn_tree.xview)
        self.multicolumn_tree.configure(
            yscrollcommand=vertical_scrollbar.set, xscrollcommand=horizontal_scrollbar.set)
        self.multicolumn_tree.grid(column=0, row=0, sticky='nsew', in_=container)
        vertical_scrollbar.grid(column=1, row=0, sticky='ns', in_=container)
        horizontal_scrollbar.grid(column=0, row=1, sticky='ew', in_=container)

        container.grid_columnconfigure(0, weight=1)
        container.grid_rowconfigure(0, weight=1)

        # add the columns
        for col in self.multicolumn_tree.MULTICOLUMN_HEADERS:
            # add the header and bind the sort command
            self.multicolumn_tree.heading(col, text=col.title(
            ), command=lambda c=col: sortby(self.multicolumn_tree, c, 0))
            # adjust the column's width to the header string
            self.multicolumn_tree.column(
                col, width=tkFont.Font().measure(col.title()))

        self.found_label.pack(side=LEFT, fill=BOTH)
        self.indexed_label.pack(side=LEFT, fill=BOTH)

        self.memory_usage_label.pack(side=LEFT, expand=NO)
        self.uibuffer_label.pack(side=LEFT, expand=NO)
        self.active_threads.pack(side=LEFT, expand=NO)
        self.average_depth_label.pack(side=LEFT, expand=NO)
        self.github_button.pack(side=RIGHT, expand=NO)

        bottom_widgets_group.pack(side=BOTTOM, fill=BOTH)
        search_input_field.focus()
        self.window.protocol("WM_DELETE_WINDOW", self.on_closing)
        self.window.after(10, self.mainloop)  # HACK: if ms is too small it seems tkinter misses some double clicks
        self.window.mainloop()

    def on_closing(self):
        self.running = False
        self.multicolumn_tree.stop_crawlers_async()
        self.window.destroy()
        for thread in self.multicolumn_tree.threads:
            print("Waiting for thread", thread, "to stop...")
            thread.join()
        exit(0)

    def mainloop(self):
        # update bottom labels
        ram_used = self.process.memory_info().rss
        self.memory_usage_label.configure(text="Memory used: " + str(ram_used // (2 ** 20)) + "MB")

        self.uibuffer_label.configure(text="UI_Buffer: " + str(self.multicolumn_tree.ui_buffer.qsize()))
        self.active_threads.configure(
            text="Active Threads: " + str(len(list(filter(lambda x: x.isAlive(), self.multicolumn_tree.threads)))))
        self.indexed_label.configure(text="Files indexed: " + str(self.multicolumn_tree.index_count()))
        self.found_label.configure(text="Files Shown: " + str(len(self.multicolumn_tree.get_children())))
        self.average_depth_label.configure(
            text="Average Crawlers Folder Depth: " + str(self.multicolumn_tree.get_average_crawlers_depth()))

        # add results to UI
        self.multicolumn_tree.update_view()
        self.window.after(100, self.mainloop)


if __name__ == "__main__":
    Drill()
