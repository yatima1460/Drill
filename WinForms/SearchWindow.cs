//using Core;
//using Core.Modules;
//using Core.Utils;
//using Module;
using System.Collections;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using WinForms.Menus;
using Drill.Core;

namespace WinForms
{
    public partial class SearchWindow : Form
    {
        public SearchWindow()
        {
            InitializeComponent();
        }

        private const string menuSearchString = "🔍 Search";

        Search drillSearch = new("");


        private readonly List<FileSystemInfo> resultsBag = new(100);


        Dictionary<string, int> extensionIconCache = new(100);

        int oldResultsCount = 0;
        bool sortEnabled = false;



        private void SearchWindow_Load(object sender, EventArgs e)
        {
            Trace.Listeners.Add(new ConsoleTraceListener());

            // Center the actual form
            Rectangle screenSize = Screen.FromControl(this).Bounds;
            Size = new Size(screenSize.Width / 2, screenSize.Height / 2);
            Left = screenSize.Width / 4;

#if DEBUG
            Text = "Drill (DEBUG)";
#endif

            // Enable double buffered ListView (prevents flickering)
            MethodInfo? method = typeof(Control).GetMethod("SetStyle", BindingFlags.Instance | BindingFlags.NonPublic);
            if (method != null)
                method.Invoke(fileSearchResults, new object[] { ControlStyles.OptimizedDoubleBuffer, true });
            else Debug.WriteLine("WARNING: disabled double buffering because method info is null");

            // Disable sorting in ListView
            fileSearchResults.ListViewItemSorter = null;

            // Timer to pop results
            refreshVirtualListTicker.Enabled = true;
            refreshVirtualListTicker.Interval = 10;
            refreshVirtualListTicker.Start();

            // List that holds the results
            fileSearchResults.VirtualMode = true;
            fileSearchResults.RetrieveVirtualItem += SearchResults_RetrieveVirtualItem;
            fileSearchResults.View = View.Details;
            fileSearchResults.Scrollable = true;

            // Focus the search box
            fileSearchInput.Select();

            // Load columns on list
            // Obtain a handle to the system image list.
            NativeMethods.SHFILEINFO shfi = new();
            IntPtr hSysImgList = NativeMethods.SHGetFileInfo("", 0, ref shfi, (uint)Marshal.SizeOf(shfi), NativeMethods.SHGFI_SYSICONINDEX | NativeMethods.SHGFI_SMALLICON);
            Debug.Assert(hSysImgList != IntPtr.Zero);  // cross our fingers and hope to succeed!

            // Set the ListView control to use that image list.
            NativeMethods.SendMessage(fileSearchResults.Handle, NativeMethods.LVM_SETIMAGELIST, NativeMethods.LVSIL_SMALL, hSysImgList);

            // If the ListView control already had an image list, delete the old one.


            // Set up the ListView control's basic properties.
            // Put it in "Details" mode, create a column so that "Details" mode will work,
            // and set its theme so it will look like the one used by Explorer.

            ResultsAutoSizeColumns();

            // TODO: figure out what this does exactly
            // When this is removed the window becomes unstable if minimized and then reopened
            if (fileSearchResults.Handle.ToInt32() != 0)
                _ = NativeMethods.SetWindowTheme(fileSearchResults.Handle, "Explorer", null);
        }


        private ListViewItem CreateListItem(DrillResult drillResult)
        {
            if (!extensionIconCache.TryGetValue(drillResult.FullPath, out int iconToUse))
            {
                NativeMethods.SHFILEINFO shfi = new();
                _ = NativeMethods.SHGetFileInfo(
                    drillResult.FullPath,
                    0,
                    ref shfi,
                    (uint)Marshal.SizeOf(shfi),
                    NativeMethods.SHGFI_DISPLAYNAME | NativeMethods.SHGFI_SYSICONINDEX | NativeMethods.SHGFI_SMALLICON
                );

                iconToUse = shfi.iIcon;
                extensionIconCache[drillResult.FullPath] = iconToUse;
            }

            ListViewItem item = new()
            {
                Text = drillResult.Name,
                ImageIndex = iconToUse,
                UseItemStyleForSubItems = false
            };

            item.SubItems.Add(drillResult.Path);
            item.SubItems.Add(drillResult.Size);
            item.SubItems.Add(drillResult.Date);

            item.Tag = drillResult;

            return item;
        }

        Dictionary<FileSystemInfo, DrillResult> itemsCache = new();

        private void SearchResults_RetrieveVirtualItem(object sender, RetrieveVirtualItemEventArgs e)
        {
            try
            {
                FileSystemInfo sub = resultsBag[e.ItemIndex];

                if (itemsCache.TryGetValue(sub, out DrillResult value))
                {
                    e.Item = CreateListItem(value);
                    return;
                }

                DrillResult drillResult;

                bool isDirectory = (sub.Attributes & FileAttributes.Directory) == FileAttributes.Directory;

                if (isDirectory)
                {
                    drillResult = new()
                    {
                        Name = sub.Name,
                        FullPath = sub.FullName,
                        Path = Path.GetDirectoryName(sub.FullName),
                        Date = sub.LastWriteTime.ToShortDateString() + " " + sub.LastWriteTime.ToShortTimeString(),
                        Size = string.Empty,
                        // TODO: different icon for .app on Mac
                        Icon = "📁"
                    };
                }
                else
                {
                    drillResult = new()
                    {
                        Name = sub.Name,
                        FullPath = sub.FullName,
                        Path = Path.GetDirectoryName(sub.FullName),
                        Date = sub.LastWriteTime.ToShortDateString() + " " + sub.LastWriteTime.ToShortTimeString(),
                        Size = StringUtils.GetHumanReadableSize(((FileInfo)sub).Length),
                        Icon = ExtensionIcon.GetIcon(sub.Extension.ToLower())
                    };
                }

                e.Item = CreateListItem(drillResult);

                itemsCache.Add(sub, drillResult);

                e.Item = CreateListItem(drillResult);
            }
            catch (Exception fatalError)
            {
                MessageBox.Show(fatalError.Message);
            }
        }


        private void RefreshVirtualListCountTick(object sender, EventArgs e)
        {
            int resultsCount = resultsBag.Count;

            var results = drillSearch.PopResults(5);
            foreach (var item in results)
            {
                resultsBag.Add(item);
            }

            // Sort only if results count changed or enabled
            if (sortEnabled && oldResultsCount != resultsCount)
            {
                oldResultsCount = resultsCount;
                resultsBag.Sort();
            }

            // Flash the minimized window icon if new results
            //if (oldResultsCount != resultsCount && this.WindowState == FormWindowState.Minimized)
            //    NativeMethods.FlashWindowEx(this);

            // Update virtual list count
            fileSearchResults.VirtualListSize = resultsCount;

            // Update Search tab with found search results
            // 'if' needed to prevent stupid WinForms flickering
            var newText = resultsCount == 0 ? menuSearchString : menuSearchString + "(" + resultsCount + ")";
            if (newText != resultsCountToolStripMenuItem.Text)
                resultsCountToolStripMenuItem.Text = newText;

            exportResultsTocsvToolStripMenuItem.Enabled = resultsCount != 0;
        }


        private void Window_Closing(object sender, FormClosingEventArgs e)
        {
            var ee = drillSearch.Stop();
            if (ee != null)
                MessageBox.Show(ee.Message);
        }

        private void searchResults_MouseClick(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Right)
            {
                if (fileSearchResults.FocusedItem.Bounds.Contains(e.Location))
                {

                    contextMenuRightClickFile.Show(Cursor.Position);

                }
            }
        }

        private void searchResults_MouseDoubleClick(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                if (fileSearchResults.FocusedItem.Bounds.Contains(e.Location))
                {

                    Process.Start("explorer.exe", ((DrillResult)fileSearchResults.FocusedItem.Tag).FullPath);
                }
            }
        }




        #region ContextMenu


        private void open_Click(object sender, EventArgs e)
        {
            Process.Start("explorer.exe", ((DrillResult)fileSearchResults.FocusedItem.Tag).FullPath);
        }

        private void openContainingFolder_Click(object sender, EventArgs e)
        {
            Process.Start("explorer.exe", string.Format("/select,\"{0}\"", ((DrillResult)fileSearchResults.FocusedItem.Tag).FullPath));
        }


        private void copySize(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).Size);
        }


        private void copyModifiedDate(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).Date);
        }

        private void copyFullPath(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).FullPath);
        }

        private void copyFile(object sender, EventArgs e)
        {
            System.Collections.Specialized.StringCollection FileCollection = new System.Collections.Specialized.StringCollection();
            FileCollection.Add(((DrillResult)fileSearchResults.FocusedItem.Tag).FullPath);
            Clipboard.SetFileDropList(FileCollection);
        }

        private void copyName(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).Name.Split(".")[0]);
        }

        private void copyNameWithExtension(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).Name);
        }

        private void copyContainingFolderFullPath(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).Path);
        }

        /// <summary>
        /// Resets the UI like when it was started as first time with 0 results
        /// </summary>
        private void ResetUI()
        {
            resultsBag.Clear();

            // Reset virtual list
            refreshVirtualListTicker.Stop();
            refreshVirtualListTicker.Enabled = false;
            fileSearchResults.VirtualListSize = 0;
            resultsCountToolStripMenuItem.Text = menuSearchString;
            oldResultsCount = -1;
        }

        #endregion

        private void searchBox_KeyDown(object sender, KeyEventArgs e)
        {
            // Exit when pressing ESC
            if (e.KeyCode == Keys.Escape)
            {
                drillSearch.Stop();
                Close();
            }

            // FIXME: Open first element when pressing Enter
            //if (e.KeyCode == Keys.Enter)
            //{
            //    if (fileSearchResults.Items.Count > 0)
            //    {
            //        fileSearchResults.FocusedItem = fileSearchResults.Items[0];
            //        Process.Start("explorer.exe", ((DrillResult)fileSearchResults.FocusedItem.Tag).FullPath);
            //    }
            //}

            // FIXME: can go down with arrow keys no mouse needed
            //if (e.KeyCode == Keys.Down)
            //{
            //    if (fileSearchResults.Items.Count > 0)
            //    {

            //        fileSearchResults.Focus();
            //        var lvi = fileSearchResults.Items[0];
            //        lvi.Focused = true;
            //        //searchResults.FocusedItem = searchResults.Items[0];
            //        //e.SuppressKeyPress = true;
            //        //searchResults.FocusedItem = searchResults.Items[0];
            //    }
            //}
        }








        internal static class NativeMethods
        {
            public const uint LVM_FIRST = 0x1000;
            public const uint LVM_GETIMAGELIST = (LVM_FIRST + 2);
            public const uint LVM_SETIMAGELIST = (LVM_FIRST + 3);

            public const uint LVSIL_NORMAL = 0;
            public const uint LVSIL_SMALL = 1;
            public const uint LVSIL_STATE = 2;
            public const uint LVSIL_GROUPHEADER = 3;

            [DllImport("user32", CharSet = CharSet.Unicode)]
            public static extern IntPtr SendMessage(IntPtr hWnd,
                                                    uint msg,
                                                    uint wParam,
                                                    IntPtr lParam);

            [DllImport("comctl32", CharSet = CharSet.Unicode)]
            public static extern bool ImageList_Destroy(IntPtr hImageList);

            public const uint SHGFI_DISPLAYNAME = 0x200;
            public const uint SHGFI_ICON = 0x100;
            public const uint SHGFI_LARGEICON = 0x0;
            public const uint SHGFI_SMALLICON = 0x1;
            public const uint SHGFI_SYSICONINDEX = 0x4000;

            [StructLayout(LayoutKind.Sequential)]
            public struct SHFILEINFO
            {
                public IntPtr hIcon;
                public int iIcon;
                public uint dwAttributes;
                [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260 /* MAX_PATH */)]
                public string szDisplayName;
                [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
                public string szTypeName;
            };

            [DllImport("shell32", CharSet = CharSet.Unicode)]
            public static extern IntPtr SHGetFileInfo(string pszPath,
                                                      uint dwFileAttributes,
                                                      ref SHFILEINFO psfi,
                                                      uint cbSizeFileInfo,
                                                      uint uFlags);

            [DllImport("uxtheme", CharSet = CharSet.Unicode)]
            public static extern int SetWindowTheme(IntPtr hWnd,
                                                    string pszSubAppName,
                                                    string pszSubIdList);

            // To support flashing.
            [DllImport("user32.dll", CharSet = CharSet.Unicode)]
            [return: MarshalAs(UnmanagedType.Bool)]
            static extern bool FlashWindowEx(ref FLASHWINFO pwfi);

            //Flash both the window caption and taskbar button.
            //This is equivalent to setting the FLASHW_CAPTION | FLASHW_TRAY flags. 
            public const UInt32 FLASHW_ALL = 3;

            // Flash continuously until the window comes to the foreground. 
            public const UInt32 FLASHW_TIMERNOFG = 12;

            [StructLayout(LayoutKind.Sequential)]
            public struct FLASHWINFO
            {
                public UInt32 cbSize;
                public IntPtr hwnd;
                public UInt32 dwFlags;
                public UInt32 uCount;
                public UInt32 dwTimeout;
            }

            // Do the flashing - this does not involve a raincoat.
            public static bool FlashWindowEx(Form form)
            {
                IntPtr hWnd = form.Handle;
                FLASHWINFO fInfo = new FLASHWINFO();

                fInfo.cbSize = Convert.ToUInt32(Marshal.SizeOf(fInfo));
                fInfo.hwnd = hWnd;
                fInfo.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;
                fInfo.uCount = UInt32.MaxValue;
                fInfo.dwTimeout = 0;

                return FlashWindowEx(ref fInfo);
            }
        }



        private void exitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            drillSearch.Stop();
            Close();
        }

        private void stopToolStripMenuItem_Click(object sender, EventArgs e)
        {
            drillSearch.Stop();
            //drivesToolStripMenuItem1.Enabled = true;
            //filtersToolStripMenuItem1.Enabled = true;
            //heuristicsToolStripMenuItem.Enabled = true;
        }




        private void menuStrip_ItemClicked(object sender, ToolStripItemClickedEventArgs e)
        {

        }



        private void fileSearchResults_SelectedIndexChanged_1(object sender, EventArgs e)
        {

        }

        private void autoSortingToolStripMenuItem_CheckedChanged(object sender, EventArgs e)
        {
            sortEnabled = autoSortingToolStripMenuItem.Checked;
        }


        private void aboutToolStripMenuItem_Click(object sender, EventArgs e)
        {
            AboutForm aboutBox = new AboutForm();
            aboutBox.ShowDialog(this);
        }

        private void searchToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }

        private void searchStringChangedTimer_Tick(object sender, EventArgs e)
        {
            drillSearch.Stop();
            ResetUI();

            // If user deletes all text in the search box there is nothing else to do
            if (fileSearchInput.Text.Trim().Length == 0)
            {
                return;
            }

            // Start the timer to update the ListView with results
            refreshVirtualListTicker.Enabled = true;
            refreshVirtualListTicker.Interval = 10;
            refreshVirtualListTicker.Start();

            //drivesToolStripMenuItem1.Enabled = false;
            //filtersToolStripMenuItem1.Enabled = false;
            //heuristicsToolStripMenuItem.Enabled = false;

            var searchString = fileSearchInput.Text.Trim();

            // Start the backend search
            drillSearch = new Search(searchString);
            drillSearch.StartAsync((x) =>
            {
                // TODO: dispatcher Winforms
            });
            searchStringChangedTimer.Stop();
        }


        private void searchBox_TextChanged(object sender, EventArgs e)
        {
            if (searchStringChangedTimer.Enabled)
            {
                searchStringChangedTimer.Stop();
            }
            searchStringChangedTimer.Start();
        }

        private void openWithToolStripMenuItem_Click(object sender, EventArgs e)
        {
            DrillResult dr = (DrillResult)fileSearchResults.FocusedItem.Tag;
            ShellHelper.OpenAs(this.Handle, dr.FullPath);
        }

        private void exportResultsTocsvToolStripMenuItem_Click_2(object sender, EventArgs e)
        {
            //try
            //{
            //    SaveFileDialog saveFileDialog = new SaveFileDialog();
            //    saveFileDialog.CheckPathExists = true;
            //    saveFileDialog.FileName = "export.tsv";

            //    string sfdname = saveFileDialog.FileName;
            //    if (saveFileDialog.ShowDialog(this) == DialogResult.OK)
            //    {
            //        var path = Path.GetFullPath(saveFileDialog.FileName);

            //        string tsv = "Name\tFolder\tSize\tDate\n";
            //        var toExport = resultsBag[..];
            //        var arr = ((List<DrillResult>)toExport).ToArray();

            //        for (int i = 0; i < arr.Length; i++)
            //        {
            //            try
            //            {
            //                DrillResult dr = (DrillResult)arr[i];

            //                tsv += dr.Name + '\t' + dr.Path + '\t' + dr.Size + '\t' + dr.Date + '\n';
            //            }
            //            catch (Exception eee)
            //            {
            //                Trace.TraceError(eee.Message);
            //            }
            //        }

            //        File.WriteAllText(path, tsv);

            //        Process.Start("explorer.exe", "/select,\"" + path + "\"");
            //    }
            //}
            //catch (Exception ee)
            //{
            //    MessageBox.Show(ee.Message);
            //}
        }

        private void ResultsAutoSizeColumns()
        {
            var screensize = fileSearchResults.Size;

            // Name
            fileSearchResults.Columns[0].Width = (int)(screensize.Width * 0.5f);

            // Folder
            fileSearchResults.Columns[1].Width = (int)(screensize.Width * 0.2f);

            // Size
            fileSearchResults.Columns[2].Width = (int)(screensize.Width * 0.1f);
            fileSearchResults.Columns[2].TextAlign = HorizontalAlignment.Right;

            // Date
            fileSearchResults.Columns[3].Width = (int)(screensize.Width * 0.2f);
        }

        private void fileSearchResults_Resize(object sender, EventArgs e)
        {
            ResultsAutoSizeColumns();
        }
    }

}
