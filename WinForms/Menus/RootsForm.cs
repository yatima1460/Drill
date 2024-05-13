//using Core.Modules;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
//using static Core.Drill;

namespace WinForms
{
    public partial class RootsForm : Form
    {
        //private List<Root> drives;

        public RootsForm(/*List<Root> disk*/)
        {
            //this.drives = disk;
            InitializeComponent();
        }

        private void drivesForm_Load(object sender, EventArgs e)
        {
           
            //foreach (var item in drives)
            //{
            //    ListViewItem listViewItem = new ListViewItem();
            //    listViewItem.Tag = item;
            //    listViewItem.Checked = item.Enabled;
            //    listViewItem.SubItems.Add(item.FullPath);
            //    //listViewItem.SubItems.Add(item.DriveInfo.VolumeLabel);
            //    //listViewItem.SubItems.Add(item.DriveInfo.DriveFormat);
            //    //listViewItem.SubItems.Add(item.DriveInfo.DriveType.ToString());
            //    drivesList.Items.Add(listViewItem);
            //}

        }

        private void drivesList_ItemChecked(object sender, ItemCheckedEventArgs e)
        {
            //Root f = (Root)e.Item.Tag;

            //f.Enabled = e.Item.Checked;
        }
    }
}
