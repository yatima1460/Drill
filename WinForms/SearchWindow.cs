//using Core;
//using Core.Modules;
//using Core.Utils;
//using Module;
using System.Collections;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using WinForms.Menus;

namespace WinForms
{
    public partial class SearchWindow : Form
    {
        public SearchWindow()
        {
            InitializeComponent();
        }


        
        
        // Global state for the UI

        /// <summary>
        /// Modules always kept loaded so user can use checkboxes in the UI
        /// </summary>
        //private Drill.ModulesData drillModulesLoadedInUI;

        /// <summary>
        /// The current search context is kept here so we can stop it
        /// By default an empty struct is created
        /// </summary>
        //private Drill.SearchContext drillSearchData = new Drill.SearchContext();

        /// <summary>
        /// Array storing the results found by the Drill threads
        /// </summary>
        /// 
        private ArrayList resultsBag = ArrayList.Synchronized(new ArrayList());


        FiltersForm filtersForm;



        Dictionary<string, int> extensionIconCache = new Dictionary<string, int>();
        int folderIcon = -1;

        // Init
        private void SearchWindow_Load(object sender, EventArgs e)
        {
            

            //Trace.Listeners.Add(new TextWriterTraceListener());
            Trace.Listeners.Add(new ConsoleTraceListener());


            //drillModulesLoadedInUI = Drill.LoadAllDefaultModules();
            
          


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

            // Ticker for virtual list results
            refreshVirtualListTicker.Enabled = true;
            refreshVirtualListTicker.Interval = 10;
            refreshVirtualListTicker.Start();

           


            fileSearchResults.VirtualMode = true;
            fileSearchResults.RetrieveVirtualItem += SearchResults_RetrieveVirtualItem;

            // Set ListView to virtual mode
            fileSearchResults.View = View.Details;
            fileSearchResults.Scrollable = true;


            // Focus the search box
            fileSearchInput.Select();

            // Load columns on list
            SetupList();
        }

        private void resultsCallback(DrillResult obj)
        {
            resultsBag.Add(obj);
        }

        private ListViewItem CreateListItem(DrillResult drillResult)
        {

            int iconToUse = 0;

            if (!extensionIconCache.ContainsKey(drillResult.FullPath))
            {
                NativeMethods.SHFILEINFO shfi = new NativeMethods.SHFILEINFO();
                IntPtr himl = NativeMethods.SHGetFileInfo(drillResult.FullPath,
                                                             0,
                                                             ref shfi,
                                                             (uint)Marshal.SizeOf(shfi),
                                                             NativeMethods.SHGFI_DISPLAYNAME
                                                               | NativeMethods.SHGFI_SYSICONINDEX
                                                               | NativeMethods.SHGFI_SMALLICON);

                iconToUse = shfi.iIcon;
                extensionIconCache[drillResult.FullPath] = iconToUse;
            }

            iconToUse = extensionIconCache[drillResult.FullPath];
            //Empty "sheet of paper" icon
            //if (!drillResult.IsFolder)
            //{

            //bool valid = false;

            // Check if icon is cached
            //if (drillResult.Extension == ".exe")
            //{
            //    if (!extensionIconCache.ContainsKey(drillResult.FullPath))
            //    {
            //        //try
            //        //{

            //        // If not cached read it and cache it
            //        NativeMethods.SHFILEINFO shfi = new NativeMethods.SHFILEINFO();
            //        IntPtr himl = NativeMethods.SHGetFileInfo(drillResult.FullPath,
            //                                                     0,
            //                                                     ref shfi,
            //                                                     (uint)Marshal.SizeOf(shfi),
            //                                                     NativeMethods.SHGFI_DISPLAYNAME
            //                                                       | NativeMethods.SHGFI_SYSICONINDEX
            //                                                       | NativeMethods.SHGFI_SMALLICON);

            //        if (shfi.iIcon > -1)
            //        {
            //            extensionIconCache[drillResult.FullPath] = shfi.iIcon;

            //        }

            //    }
            //    else
            //    {
            //        iconToUse = extensionIconCache[drillResult.FullPath];
            //    }
            //}
            //else
            //{
            //    if (!extensionIconCache.ContainsKey(drillResult.Extension))
            //    {
            //try
            //{

            // If not cached read it and cache it
            //NativeMethods.SHFILEINFO shfi = new NativeMethods.SHFILEINFO();
            //        IntPtr himl = NativeMethods.SHGetFileInfo(drillResult.FullPath,
            //                                                     0,
            //                                                     ref shfi,
            //                                                     (uint)Marshal.SizeOf(shfi),
            //                                                     NativeMethods.SHGFI_DISPLAYNAME
            //                                                       | NativeMethods.SHGFI_SYSICONINDEX
            //                                                       | NativeMethods.SHGFI_LARGEICON);



            //if (shfi.iIcon > -1)
            //{
            //    extensionIconCache[drillResult.Extension] = shfi.iIcon;

            //}

            //}
            //else
            //{
            //iconToUse = extensionIconCache[drillResult.Extension];
            //}
            //}



            // if (valid)



            //}
            //else
            //{
            //    if (folderIcon == -1)
            //    {
            //        NativeMethods.SHFILEINFO shfi = new NativeMethods.SHFILEINFO();
            //        IntPtr himl = NativeMethods.SHGetFileInfo("C:\\Windows",
            //                                                     0,
            //                                                     ref shfi,
            //                                                     (uint)Marshal.SizeOf(shfi),
            //                                                     NativeMethods.SHGFI_DISPLAYNAME
            //                                                       | NativeMethods.SHGFI_SYSICONINDEX
            //                                                       | NativeMethods.SHGFI_SMALLICON);
            //        folderIcon = shfi.iIcon;

            //    }

            //    iconToUse = folderIcon;
            //}
            
            var item = new ListViewItem(drillResult.BaseName, iconToUse);
            //if (drillResult.Extension == ".exe")
            //if (drillResult.Filter.GetType().Name.Contains("Exact"))
            //    item.Font = new Font(item.Font, FontStyle.Bold);
            item.UseItemStyleForSubItems = false;
            //item.SubItems.Add(DrillResult.FindReason);

            item.SubItems.Add(drillResult.ContainingFolder);//, Color.Aqua, Color.White, item.Font);

            if (!drillResult.IsFolder)
                item.SubItems.Add(StringUtils.BytesToString(drillResult.Size));
            else
                item.SubItems.Add("");

            item.SubItems.Add(drillResult.LastWriteTime.ToString());
            item.SubItems.Add("NO FILTER");
           //item.SubItems.Add(drillResult.Filter.GetName());
           item.Tag = drillResult;

            return item;
        }


        private void SearchResults_RetrieveVirtualItem(object sender, RetrieveVirtualItemEventArgs e)
        {
            try
            {


                DrillResult drillResult;
                //if (virtualCache.ContainsKey(e.ItemIndex))
                //{
                //    DrillResult = virtualCache[e.ItemIndex];
                //}
                //else
                //{
                drillResult = (DrillResult)resultsBag[e.ItemIndex];
                //    virtualCache[e.ItemIndex] = DrillResult;
                //}

                e.Item = CreateListItem(drillResult);
             

            }

            catch (Exception fatalError)
            {
                MessageBox.Show(fatalError.Message);
            }
        }

        private void SetupList()
        {
            // Obtain a handle to the system image list.
            NativeMethods.SHFILEINFO shfi = new NativeMethods.SHFILEINFO();
            IntPtr hSysImgList = NativeMethods.SHGetFileInfo("",
                                                             0,
                                                             ref shfi,
                                                             (uint)Marshal.SizeOf(shfi),
                                                             NativeMethods.SHGFI_SYSICONINDEX
                                                              | NativeMethods.SHGFI_SMALLICON);
            Debug.Assert(hSysImgList != IntPtr.Zero);  // cross our fingers and hope to succeed!

            // Set the ListView control to use that image list.
            NativeMethods.SendMessage(fileSearchResults.Handle,
                                                           NativeMethods.LVM_SETIMAGELIST,
                                                           NativeMethods.LVSIL_SMALL,
                                                           hSysImgList);

            // If the ListView control already had an image list, delete the old one.


            // Set up the ListView control's basic properties.
            // Put it in "Details" mode, create a column so that "Details" mode will work,
            // and set its theme so it will look like the one used by Explorer.

            var screensize = fileSearchResults.Size;

            // Name
            fileSearchResults.Columns[0].Width = (int)(screensize.Width * 0.4f);

            // Folder
            fileSearchResults.Columns[1].Width = (int)(screensize.Width * 0.15f);

            // Size
            fileSearchResults.Columns[2].Width = (int)(screensize.Width * 0.1f);
            fileSearchResults.Columns[2].TextAlign = HorizontalAlignment.Right;

            // Date
            fileSearchResults.Columns[3].Width = (int)(screensize.Width * 0.15f);

            // Filter
            fileSearchResults.Columns[4].Width = (int)(screensize.Width * 0.15f);

            NativeMethods.SetWindowTheme(fileSearchResults.Handle, "Explorer", null);
            //fileSearchResults.Columns.Add("Name", 255 + 100);
            ////searchResults.Columns.Add("Why this result?", 155);
            //fileSearchResults.Columns.Add("Folder", 255);
            //fileSearchResults.Columns.Add("Size", 150).TextAlign = HorizontalAlignment.Right;
            //fileSearchResults.Columns.Add("Date", 150);
        }






        int oldResultsCount = 0;
        bool sortEnabled = false;

        private void RefreshVirtualListCountTick(object sender, EventArgs e)
        {
            int resultsCount = resultsBag.Count;

            // Sort only if results count changed or enabled
            if (sortEnabled && oldResultsCount != resultsCount)
            {
                oldResultsCount = resultsCount;
                resultsBag.Sort();
            }

            // Update virtual list count
            fileSearchResults.VirtualListSize = resultsCount;

            // Update Search tab with found search results
            // 'if' needed to prevent stupid WinForms flickering


            var newText = resultsCount == 0 ? "⚙️ Engine" : "⚙️ Engine(" + resultsCount + ")";
            if (newText != resultsCountToolStripMenuItem.Text)
                resultsCountToolStripMenuItem.Text = resultsCount == 0 ? "⚙️ Engine" : "⚙️ Engine (" + resultsCount + ")";

            exportResultsTocsvToolStripMenuItem.Enabled = resultsCount != 0;


            int maxThreads;
            int none;
            ThreadPool.GetMaxThreads(out maxThreads, out none);
            int availableThreads;
            ThreadPool.GetAvailableThreads(out availableThreads, out none);

            //var crawlersCount = drillContext.GetActiveCrawlersCount();
            //toolStripThreadsCount.Text = "Threads: " + drillContext.GetActiveCrawlersCount();
            

            //int originalRoots = drillContext.GetOriginalNumberOfRoots();

            //if (originalRoots != 0)
            //{
            //    //toolStripDiskScan.Text = "Disk Scan ("+ (originalRoots-crawlersCount) + "/" + originalRoots + "):";
            //    toolStripProgressBar1.Value = (int)((((float)originalRoots - (float)crawlersCount) / ((float)originalRoots)) * 100.0f);
            //}

            //else
            //{
            //    //toolStripDiskScan.Text = "Disk Scan:";
            //    toolStripProgressBar1.Value = 0;
            //}





            //if (resultsCount == 0)
            //{
            //    Text = "Drill";
            //}
            //else
            //{


            //    if (this.WindowState == FormWindowState.Minimized)
            //        NativeMethods.FlashWindowEx(this);

            //}
        }


        private void Window_Closing(object sender, FormClosingEventArgs e)
        {
            Drill.StopAsync(drillSearchData.crawlers);
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
            Clipboard.SetText(StringUtils.BytesToString(((DrillResult)fileSearchResults.FocusedItem.Tag).Size));
        }


        private void copyModifiedDate(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).LastWriteTime.ToString());
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
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).BaseName.Split(".")[0]);
        }

        private void copyNameWithExtension(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).BaseName);
        }

        private void copyContainingFolderFullPath(object sender, EventArgs e)
        {
            Clipboard.SetText(((DrillResult)fileSearchResults.FocusedItem.Tag).ContainingFolder);
        }

        /// <summary>
        /// Resets the UI like when it was started as first time with 0 results
        /// </summary>
        private void ResetUI()
        {
            drivesToolStripMenuItem1.Enabled = true;
            filtersToolStripMenuItem1.Enabled = true;
            heuristicsToolStripMenuItem.Enabled = true;

            resultsBag.Clear();
            // Reset virtual list
            refreshVirtualListTicker.Stop();
            refreshVirtualListTicker.Enabled = false;
            fileSearchResults.VirtualListSize = 0;
            // Clear only the items, dont use .Clear() because it will destroy the columns as well
            fileSearchResults.Items.Clear();
            resultsCountToolStripMenuItem.Text = "⚙️ Engine";
            oldResultsCount = 0;
        }

        #endregion

        private void searchBox_KeyDown(object sender, KeyEventArgs e)
        {
            // Exit when pressing ESC
            if (e.KeyCode == Keys.Escape)
            {
                Drill.StopAsync(drillSearchData.crawlers);
                Close();
            }

            // Open first element when pressing Enter
            if (e.KeyCode == Keys.Enter)
            {
                if (fileSearchResults.Items.Count > 0)
                {
                    fileSearchResults.FocusedItem = fileSearchResults.Items[0];
                    Process.Start("explorer.exe", ((DrillResult)fileSearchResults.FocusedItem.Tag).FullPath);
                }
            }

            if (e.KeyCode == Keys.Down)
            {
                if (fileSearchResults.Items.Count > 0)
                {

                    fileSearchResults.Focus();
                    var lvi = fileSearchResults.Items[0];
                    lvi.Focused = true;
                    //searchResults.FocusedItem = searchResults.Items[0];
                    //e.SuppressKeyPress = true;
                    //searchResults.FocusedItem = searchResults.Items[0];
                }
            }
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

            [DllImport("user32")]
            public static extern IntPtr SendMessage(IntPtr hWnd,
                                                    uint msg,
                                                    uint wParam,
                                                    IntPtr lParam);

            [DllImport("comctl32")]
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

            [DllImport("shell32")]
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
            [DllImport("user32.dll")]
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
            Drill.StopAsync(drillSearchData.crawlers);
            Close();
        }

        private void stopToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Drill.StopAsync(drillSearchData.crawlers);
            drivesToolStripMenuItem1.Enabled = true;
            filtersToolStripMenuItem1.Enabled = true;
            heuristicsToolStripMenuItem.Enabled = true;
        }

   
  

        private void menuStrip_ItemClicked(object sender, ToolStripItemClickedEventArgs e)
        {

        }


        private void drivesToolStripMenuItem1_Click(object sender, EventArgs e)
        {
            var d = new RootsForm(drillModulesLoadedInUI.drives);
            d.Text = drivesToolStripMenuItem1.Text;
            d.ShowDialog(this);
        }

        private void filtersToolStripMenuItem1_Click(object sender, EventArgs e)
        {
            var f = new FiltersForm(drillModulesLoadedInUI.filters);
            f.Text = filtersToolStripMenuItem1.Text;
            f.ShowDialog(this);
        }

        private void heuristicsToolStripMenuItem_Click(object sender, EventArgs e)
        {
            var h = new HeuristicsForm(drillModulesLoadedInUI.heuristics);
            h.Text = heuristicsToolStripMenuItem.Text;
            h.ShowDialog(this);
        }

        private void fileSearchResults_SelectedIndexChanged_1(object sender, EventArgs e)
        {

        }

        private void exportResultsTocsvToolStripMenuItem_Click(object sender, EventArgs e)
        {
            

        }

        private void autoSortingToolStripMenuItem_CheckedChanged(object sender, EventArgs e)
        {
            sortEnabled = autoSortingToolStripMenuItem.Checked;
        }

        private void exportResultsTocsvToolStripMenuItem_Click_1(object sender, EventArgs e)
        {
            try
            {
                SaveFileDialog saveFileDialog = new SaveFileDialog();
                saveFileDialog.CheckPathExists = true;
                saveFileDialog.FileName = "export.csv";

                string sfdname = saveFileDialog.FileName;
                if (saveFileDialog.ShowDialog(this) == DialogResult.OK)
                {
                    var path = Path.GetFullPath(saveFileDialog.FileName);

                    string tsv = "Name\tFolder\tSize\tDate\n";
                    var toExport = resultsBag.Clone();
                    var arr = ((ArrayList)toExport).ToArray();

                    for (int i = 0; i < arr.Length; i++)
                    {
                        try
                        {
                            DrillResult dr = (DrillResult)arr[i];

                            tsv += dr.BaseName + '\t' + dr.ContainingFolder + '\t' + dr.Size + '\t' + dr.LastWriteTime + '\n';
                        }
                        catch (Exception eee)
                        {
                            Trace.TraceError(eee.Message);
                        }
                    }
                   
                    File.WriteAllText(path, tsv);

                    Process.Start("explorer.exe", "/select,\""+ path + "\"");
                }
            }
            catch (Exception ee)
            {
                MessageBox.Show(ee.Message);
            }
           
         
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
            Drill.StopAsync(drillSearchData.crawlers);
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

            drivesToolStripMenuItem1.Enabled = false;
            filtersToolStripMenuItem1.Enabled = false;
            heuristicsToolStripMenuItem.Enabled = false;

            // Start the backend search
            drillSearchData = Drill.StartSearch(drillModulesLoadedInUI, fileSearchInput.Text.Trim(), resultsCallback);

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
    }

}
//string userName = System.Security.Principal.WindowsIdentity.GetCurrent().Name;
