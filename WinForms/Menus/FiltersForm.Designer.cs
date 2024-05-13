namespace WinForms
{
    partial class FiltersForm
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.filtersList = new System.Windows.Forms.ListView();
            this.enabledHeader = new System.Windows.Forms.ColumnHeader();
            this.nameHeader = new System.Windows.Forms.ColumnHeader();
            this.descriptionHeader = new System.Windows.Forms.ColumnHeader();
            this.SuspendLayout();
            // 
            // filtersList
            // 
            this.filtersList.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.filtersList.CheckBoxes = true;
            this.filtersList.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.enabledHeader,
            this.nameHeader,
            this.descriptionHeader});
            this.filtersList.Dock = System.Windows.Forms.DockStyle.Fill;
            this.filtersList.FullRowSelect = true;
            this.filtersList.GridLines = true;
            this.filtersList.Location = new System.Drawing.Point(0, 0);
            this.filtersList.Name = "filtersList";
            this.filtersList.Size = new System.Drawing.Size(800, 450);
            this.filtersList.TabIndex = 2;
            this.filtersList.UseCompatibleStateImageBehavior = false;
            this.filtersList.View = System.Windows.Forms.View.Details;
            this.filtersList.ItemChecked += new System.Windows.Forms.ItemCheckedEventHandler(this.filtersList_ItemChecked);
            // 
            // enabledHeader
            // 
            this.enabledHeader.Text = "";
            // 
            // nameHeader
            // 
            this.nameHeader.Text = "Name";
            // 
            // descriptionHeader
            // 
            this.descriptionHeader.Text = "Description";
            // 
            // FiltersForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(10F, 25F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(800, 450);
            this.Controls.Add(this.filtersList);
            this.DoubleBuffered = true;
            this.Name = "FiltersForm";
            this.ShowIcon = false;
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
            this.Text = "Filters";
            this.Load += new System.EventHandler(this.Filters_Load);
            this.ResumeLayout(false);

        }

        #endregion

        private ListView filtersList;
        private ColumnHeader enabledHeader;
        private ColumnHeader nameHeader;
        private ColumnHeader descriptionHeader;
    }
}