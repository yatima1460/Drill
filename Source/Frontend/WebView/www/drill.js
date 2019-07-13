
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

window.onload = function() {
    

  console.log("window loaded");

  dhanos.loaded();

  // bind search input to custom Dhanos callback
  let search = document.getElementById("search");

  search.focus();

  search.oninput = function() {
      console.log(search.value)
      dhanos.search(search.value);
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
          dhanos.exit();
      }
  };
};