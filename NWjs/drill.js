

function addFile(icon, name, path, size, fileDateModifiedString) {
    console.log(name + " addFile");
    let results = document.getElementById("results");

    results.innerHTML +=
        "<div class=result>" +
        "<div class=icon>" +
        "<img src=file:///usr/share/icons/hicolor/scalable/apps/" + icon + ".svg>"
        //"<img srcset=file:///usr/share/pixmaps/"+icon+".png>"+
        + "</div>" +
        "<div class=namepath>"+
        "<div class=name>" + name + "</div>" +
        "<div class=path>" + path + "</div>" +
        "</div>"+
        "<div class=size>" + size + "</div>" +
        "<div class=date>" + fileDateModifiedString + "</div>" +
        
        "</div>";

    console.log(name + " added");
};


var source;


async function echoReadable(readable) {

    console.log('echoReadable')
    const { chunksToLinesAsync, chomp } = require('@rauschma/stringio');

    i = 0;

    
    for await (const line of chunksToLinesAsync(readable)) { // (C)


        hideNoResultsMessage();
        //console.log('LINE: ' + chomp(line))
        const words = chomp(line).split("\t");
        console.log(words)

        const fullpath = words[2].split("/");
        const path = require('path');
        const parent = path.dirname(words[2])
        const name = path.basename(words[2])
        
        addFile("icon", name, parent, words[1],words[0]);
        i += 1;
        if (i >= 20) {

            source.kill();
            break;
        }
        //console.log(i);

    }
}


function shrinkWindow()
{
    const monitor_w = window.screen.width;
    const monitor_h = window.screen.height;
    console.log("available desktop size is: ",monitor_w+"x"+monitor_h);

    var win = nw.Window.get();
    const w = monitor_w / 2;
    const h = Math.trunc(monitor_h / 15);
     
    window.moveTo(monitor_w/2 - w/2, monitor_h/2-h/2);
    win.resizeTo(w, h);
    return win;
}


function showNoResultsMessage()
{
  

    let noresults = document.getElementById("noresults");
    noresults.style.display = "table";
    noresults.style.visibility = "visible"
    // noresults.style["justify-content"] = "center"
    // noresults.style["align-content"] = "center"
    // noresults.style["column"] = "column"
//     display: flex;
//   justify-content: center;
//   align-content: center;
//   flex-direction: column;


    // let noresults = document.getElementById("noresults");
    // noresults.style.display = "flex";

    let results = document.getElementById("results");
    results.style.display = "none";
    
}

function hideNoResultsMessage()
{
    let noresults = document.getElementById("noresults");
    noresults.style.display = "none";

     let results = document.getElementById("results");
    results.style.display = "flex";
     results.style["flex-direction"] = "column";
}

function initPage() {


    console.log("window loaded");

    win = shrinkWindow();
    win.show()
    

    document.getElementById('logo').addEventListener('click', function (e) {
        console.log("drill logo clicked");
        var win = nw.Window.get();
        //win.open("https://drill.santamorena.me")


        nw.Window.open('settings.html', {}, function(win) {
            parentWin.localStorage.setItem('child_open', true);

            win.on('closed', function() {
                parentWin.localStorage.removeItem('child_open');
            });
        });
       // nw.Shell.openExternal('https://drill.software');

    });

    //dhanos.loaded();

    // bind search input to custom Dhanos callback
    let search = document.getElementById("search");

    search.focus();

    search.oninput = function () {
        console.log(search.value);


        var win = nw.Window.get();

        

        

        results.innerHTML = "";
  
        if (search.value.length != 0)
        {
            showNoResultsMessage();

            const monitor_w = window.screen.width;
            const monitor_h = window.screen.height;
            const w = monitor_w / 2;
            const h = Math.trunc((monitor_w/2) / 1.61803398875/1.5);
            console.log("new big size:",w+"x"+h);
            window.moveTo(monitor_w/2 - w/2, monitor_h/2-monitor_h / 30);
            win.resizeTo(w, h);

            
    
            const { spawn } = require('child_process');
            source = spawn(process.cwd() + '/drill-cli', ["-ds",search.value],
                { stdio: ['ignore', 'pipe', process.stderr] }
            ); // (A)
    
            echoReadable(source.stdout);
        }
        else
        {
            console.log("Search input is empty, closing results")
            shrinkWindow()
           
           
        }

       
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


