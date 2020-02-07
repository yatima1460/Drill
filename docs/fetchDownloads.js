

function setLinkIfValid(data, baseURL, element, assetName)
{

  

    for (index = 0; index <  data.assets.length; ++index) {
        const asset = data.assets[index];
        if (asset.name === assetName)
        {
            console.log("file",assetName,"found");
            element.href = baseURL + assetName;
            element.onclick = () => {window.open( element.href)}
            return true;
        }
    }

    for (var i = 0; i < element.childNodes.length; i++) {
        if (element.childNodes[i].className == "download-icon") {

            element.style.display = "none";
            element.childNodes[i].style.display = "none";
            break;
        }        
    }

 
    console.warn("file",assetName,"not found, disabled");
    element.classList.add("disabled");
    element.href = "javascript: void(0)";
    return false;

}



window.onload = function () {
    fetch('https://api.github.com/repos/yatima1460/Drill')
        .then(response => {
            return response.json()
        })
        .then(data => {
            window.title.innerHTML += data.name;
            window.description.innerHTML = data.description;
            window.sourceButton.onclick = function () { window.open(data.html_url) };

        });

    fetch('https://api.github.com/repos/yatima1460/Drill/releases/latest')
        .then(response => {
            return response.json()
        })
        .then(data => {
            if (data.name === undefined)
            {
                //emergency fallback
                window.versionText.innerHTML = "Download here";
                window.versionText.href = "https://github.com/yatima1460/Drill/releases";
                return;
            }
            window.versionText.innerHTML += "v"+data.name;
           
         

            window.versionText.href = data.html_url;
            window.versionText.target = "_blank";

          

            const baseURL = "https://github.com/yatima1460/Drill/releases/download/"+data.name+"/";
            
            // Main buttons
            setLinkIfValid(data, baseURL, window.linuxButton,"Drill-GTK-linux-x86_64-release-"+data.name+".AppImage");
            setLinkIfValid(data, baseURL, window.macButton,"Drill-GTK-osx-x86_64-release-"+data.name+".zip");
            setLinkIfValid(data, baseURL, window.windowsButton,"Drill-GTK-windows-x86_64-release-"+data.name+".zip");

            // Secondary buttons
            setLinkIfValid(data, baseURL, window.windowsCLIZip,"Drill-CLI-windows-x86_64-release-"+data.name+".zip");
            setLinkIfValid(data, baseURL, window.linuxGTKDeb,"Drill-GTK-linux-x86_64-release-"+data.name+".deb");
            setLinkIfValid(data, baseURL, window.linuxCLIDeb,"Drill-CLI-linux-x86_64-release-"+data.name+".deb");
            setLinkIfValid(data, baseURL, window.linuxGTKZip, "Drill-GTK-linux-x86_64-release-"+data.name+".zip");
            setLinkIfValid(data, baseURL, window.linuxCLIZip, "Drill-CLI-linux-x86_64-release-"+data.name+".zip");
            setLinkIfValid(data, baseURL, window.macCLIZip, "Drill-CLI-osx-x86_64-release-"+data.name+".zip");

            window.buttons.style.display = "flex";
        });

};
