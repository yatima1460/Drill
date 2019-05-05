


module FileInfo;

class FileInfo
{
    // HACK fix this goddamn class
    string path = "";
    string name = "";

    bool hidden = false;

    string parent = "";

    bool is_dir = false;
    bool is_file = false;
    string type_str = "";

    long size = -1;
    string psize_str = "-1";
    int date_modified = 0;
    string date_modified_str = "";

    void open_file()
    {
        if (this.is_dir)
        {

            // import subprocess
            // subprocess.Popen(['xdg-open', self.path])
        }
    }
       

    void open_containing_folder()
    {
//  import subprocess
//         subprocess.Popen(['xdg-open', self.parent])
    }
       
}
