function getOSByFilename(filename) {

    var re = /(?:\.([^.]+))?$/;
    var ext = re.exec(filename)[1];

    console.log(ext);

    if (ext === "deb"
        || ext === "AppImage"
        || filename.includes("Linux")
        || filename.includes("linux")
    )
        return "Linux";

    if (ext === "exe"
        || ext === "msi"
        || filename.includes("Windows")
        || filename.includes("windows")
    )
        return "Windows";

    if (filename.includes("OSX") 
        || filename.includes("osx")
        || filename.includes("mac")
    )
        return "OSX";

    console.log("Category for file " + filename + " not found");
    return "Source";

}


function createDownloadLink(url, name) {
    return "<div><a class=\"downloadLink\" href=\"" + url + "\">" + name + "</div>";
}


window.onload = function () {

    fetch('https://api.github.com/repos/yatima1460/Drill')
        .then(response => {
            return response.json()
        })
        .then(data => {

            // Set top title
            window.title.innerHTML += data.name;

            // Set description
            window.description.innerHTML = data.description;
        });

    fetch('https://api.github.com/repos/yatima1460/Drill/releases/latest')
        .then(response => {
            return response.json()
        })
        .then(data => {
            if (data.name === undefined) {

                // Emergency fallback if GitHub APIs are broken
                window.versionText.innerHTML = "Download here";
                window.versionText.href = "https://github.com/yatima1460/Drill/releases";
                return;
            }

            // Set version label
            window.versionText.innerHTML += data.name;
            window.versionText.href = data.html_url;
            window.versionText.target = "_blank";

            // Update release description
            this.document.getElementById("releaseDescription").innerHTML += data.body;

            // Sort downloads by download count
            data.assets.sort((a, b) => (a.download_count > b.download_count) ? -1 : 1)

            // Cycle every asset and add it to the correct div by filtering by file name
            for (index = 0; index < data.assets.length; index++) {

                const asset = data.assets[index];

                console.log("file", asset.name, "found");

                let OS = this.getOSByFilename(asset.name);
                this.document.getElementById(OS).innerHTML += createDownloadLink(asset.browser_download_url, asset.name);
            }

            // Hardcoded links
            this.document.getElementById("ArchLinux").innerHTML += "<code>git clone https://github.com/yatima1460/Drill.git --depth 1 --branch latest && cd Drill && makepkg -si</code>"
            this.document.getElementById("ArchLinux").innerHTML += createDownloadLink("https://aur.archlinux.org/pkgbase/drill-search/", "AUR");
            
            this.document.getElementById("Source").innerHTML += createDownloadLink("https://github.com/yatima1460/Drill", "GitHub");
            this.document.getElementById("Source").innerHTML += createDownloadLink("https://github.com/yatima1460/Drill/archive/"+data.name+".tar.gz", "tarball");
            this.document.getElementById("Source").innerHTML += createDownloadLink("https://github.com/yatima1460/Drill/archive/"+data.name+".zip", "zipball");
        });

};
