
function addApplication(icon,name,exec,desktopFileDateModifiedString)
{
    let results = document.getElementById("results");


    results.innerHTML += 
    "<div class=result>"+
    "<div class=icon>"+
    "<img src=file:///usr/share/icons/hicolor/scalable/apps/"+icon+".svg>"
    //"<img srcset=file:///usr/share/pixmaps/"+icon+".png>"+
    +"</div>"+
    "<div class=name>"+name+"</div>"+
    "<div class=path>"+exec+"</div>"+
    "<div class=date>"+desktopFileDateModifiedString+"</div>"+
    "</div>";
};


function addFile(icon,name,path,fileDateModifiedString)
{
    console.log(name + " addFile");
    let results = document.getElementById("results");

    results.innerHTML += 
    "<div class=result>"+
    "<div class=icon>"+
    "<img src=file:///usr/share/icons/hicolor/scalable/apps/"+icon+".svg>"
    //"<img srcset=file:///usr/share/pixmaps/"+icon+".png>"+
    +"</div>"+
    "<div class=name>"+name+"</div>"+
    "<div class=path>"+path+"</div>"+
    "<div class=date>"+fileDateModifiedString+"</div>"+
    "</div>";

    console.log(name + " added");
};

window.onload = function() {
    

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

  search.oninput = function() {
      console.log(search.value);

      var win = nw.Window.get();
      win.setMinimumSize(1920/2,500);

      const { spawn } = require('child_process');
      //search.value
      //const ls = spawn('Drill-CLI-windows-x86_64-release/drill-cli.exe', []);

      var exec = require('child_process').exec;
      function execute(command, callback){
          exec(command, function(error, stdout, stderr){ callback(stdout); });
      };

      execute(process.cwd()+"/Drill-CLI-windows-x86_64-release/drill-cli.exe "+search.value, function(name)
      {
       // let search = document.getElementById("search");
        //search.value = name;

        addFile("icon",name,"path","date");
        //   console.log(name);
        // execute("git config --global user.email", function(email){
        //     callback(console.log({ name: name.replace("\n", ""), email: email.replace("\n", "") }));
        // });
      });

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


      if(evt.keyCode  == 13)
        {
            // if (search.value.length == 0)
            //     dhanos.close()
            // else 
            dhanos.return();
        }
  };
};