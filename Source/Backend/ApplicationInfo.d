module ApplicationInfo;


struct ApplicationInfo
{

    string desktopFileFullPath;

    string name;



    string exec;

    // removed % and splitted by space
    string[] execProcess;

    //string[] execProcessSplitted;

    string icon = "application-x-executable";

    string desktopFileDateModifiedString;



}