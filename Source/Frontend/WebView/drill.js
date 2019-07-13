window.onload = function() {
    let search = document.getElementById("search");
    search.oninput = function() {
        console.log(search.value)
      };
};