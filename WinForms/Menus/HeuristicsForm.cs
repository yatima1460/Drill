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

namespace WinForms
{
    public partial class HeuristicsForm : Form
    {
        //readonly List<Heuristic> Heuristics;
        public HeuristicsForm(/*List<Heuristic> heuristics*/)
        {
            //this.Heuristics = heuristics;
            InitializeComponent();
        }

        private void heuristicsList_ItemChecked(object sender, ItemCheckedEventArgs e)
        {
            //Heuristic f = (Heuristic)e.Item.Tag;

            //f.Enabled = e.Item.Checked;
        }

        private void HeuristicsForm_Load(object sender, EventArgs e)
        {
            //foreach (var item in Heuristics)
            //{
            //    ListViewItem listViewItem = new ListViewItem();
            //    listViewItem.Tag = item;
            //    listViewItem.Checked = item.Enabled;
            //    listViewItem.SubItems.Add(item.GetName());
            //    listViewItem.SubItems.Add(item.GetDescription());
            //    heuristicsList.Items.Add(listViewItem);
            //}
            //heuristicsList.AutoResizeColumns(ColumnHeaderAutoResizeStyle.ColumnContent);


        }
    }
}
