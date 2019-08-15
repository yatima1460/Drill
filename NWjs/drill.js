
function addApplication(icon, name, exec, desktopFileDateModifiedString) {
    let results = document.getElementById("results");


    results.innerHTML +=
        "<div class=result>" +
        "<div class=icon>" +
        "<img src=file:///usr/share/icons/hicolor/scalable/apps/" + icon + ".svg>"
        //"<img srcset=file:///usr/share/pixmaps/"+icon+".png>"+
        + "</div>" +
        "<div class=name>" + name + "</div>" +
        "<div class=path>" + exec + "</div>" +
        "<div class=date>" + desktopFileDateModifiedString + "</div>" +
        "</div>";
};


function addFile(icon, name, path, fileDateModifiedString) {
    console.log(name + " addFile");
    let results = document.getElementById("results");

    results.innerHTML +=
        "<div class=result>" +
        "<div class=icon>" +
        "<img src=file:///usr/share/icons/hicolor/scalable/apps/" + icon + ".svg>"
        //"<img srcset=file:///usr/share/pixmaps/"+icon+".png>"+
        + "</div>" +
        "<div class=name>" + name + "</div>" +
        "<div class=path>" + path + "</div>" +
        "<div class=date>" + fileDateModifiedString + "</div>" +
        "</div>";

    console.log(name + " added");
};


var source;

i = 0;
async function echoReadable(readable) {
    const { chunksToLinesAsync, chomp } = require('@rauschma/stringio');
    for await (const line of chunksToLinesAsync(readable)) { // (C)
        console.log('LINE: ' + chomp(line))
        addFile("icon", chomp(line), "path", "date");
        i += 1;
        console.log(i);
      
    }
}


function initPage()
{
    

    console.log("window loaded");




    document.getElementById('logo').addEventListener('click', function (e) {
        console.log("drill logo clicked");
        var win = nw.Window.get();
        //win.open("https://drill.santamorena.me")


        nw.Shell.openExternal('https://drill.software');

    });

    //dhanos.loaded();

    // bind search input to custom Dhanos callback
    let search = document.getElementById("search");

    search.focus();

    search.oninput = function () {
        console.log(search.value);

        var win = nw.Window.get();
        win.setMinimumSize(1920 / 2, 500);

        //const { spawn } = require('child_process');
        //search.value
        //const ls = spawn('Drill-CLI-windows-x86_64-release/drill-cli.exe', []);

       
        const { spawn } = require('child_process');


        source = spawn(process.cwd()+'/Drill-CLI-windows-x86_64-release/drill-cli.exe', [search.value],
            { stdio: ['ignore', 'pipe', process.stderr] }
        ); // (A)

        echoReadable(source.stdout);
        //await echoReadable(source.stdout); // (B)




    };

    // bind ESC to exit Dhanos
    document.onkeydown = function (evt) {
        evt = evt || window.event;
        var isEscape = false;
        if ("key" in evt) {
            isEscape = (evt.key === "Escape" || evt.key === "Esc");
        } else {
            isEscape = (evt.keyCode === 27);
        }
        if (isEscape) {
            console.log("The window will close");
            var win = nw.Window.get();
            win.close();
        }


        if (evt.keyCode == 13) {
            // if (search.value.length == 0)
            //     dhanos.close()
            // else 
            dhanos.return();
        }
    };
}

   
