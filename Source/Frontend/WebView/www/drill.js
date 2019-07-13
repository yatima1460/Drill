


window.onload = function() {
    

  console.log("window loaded");
  dhanos.loaded("a");

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