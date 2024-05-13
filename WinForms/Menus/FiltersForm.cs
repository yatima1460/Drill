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
    public partial class FiltersForm : Form
    {
        //public List<Filter> filters;

        public FiltersForm(/*List<Filter> filters*/)
        {
            //this.filters = filters;
            InitializeComponent();
        }

        private void Filters_Load(object sender, EventArgs e)
        {
            //foreach (var item in filters)
            //{
            //    ListViewItem listViewItem = new ListViewItem();
            //    listViewItem.Tag = item;
            //    listViewItem.Checked = item.Enabled;
            //    listViewItem.SubItems.Add(item.GetName());
            //    listViewItem.SubItems.Add(item.GetDescription());
            //    filtersList.Items.Add(listViewItem);
            //}
            //filtersList.AutoResizeColumns(ColumnHeaderAutoResizeStyle.ColumnContent);

        }

        private void filtersList_ItemChecked(object sender, ItemCheckedEventArgs e)
        {
            //Filter f = (Filter)e.Item.Tag;

            //f.Enabled = e.Item.Checked;
        }
    }
}
