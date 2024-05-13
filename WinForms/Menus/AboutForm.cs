using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace WinForms.Menus
{
    public partial class AboutForm : Form
    {
        public AboutForm()
        {
            InitializeComponent();
        }

        private void websiteLink_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = websiteLink.Text,
                UseShellExecute = true
            });
        }

        private void emailLink_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "mailto:" + emailLink.Text,
                UseShellExecute = true
            });
        }

        private void AboutForm_Load(object sender, EventArgs e)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            if (assembly != null)
            {
                AssemblyName name = assembly.GetName();
                if (name != null)
                {
                    Version? version = name.Version;
                    if (version != null)
                    {
                        versionNumber.Text = version.ToString();
                    }
                    
                }
                
            }
           
        }
    }
}
