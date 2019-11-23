





// // Remove the tray
// tray.remove();
// tray = null;

// nw.Window.open('drill.html', {}, 
//     function(win) 
//     {
        
      
//         //win.setPosition("center");
//         // win.width = 1920/2;
//         // win.height = 1080/2;
      
        

//     }
// );



// // Create an empty context menu
// var menu = new nw.Menu();

// // Add some items with label
// menu.append(new nw.MenuItem({
//   label: 'Item A',
//   click: function(){
//     alert('You have clicked at "Item A"');
//   }
// }));
// menu.append(new nw.MenuItem({ label: 'Item B' }));
// menu.append(new nw.MenuItem({ type: 'separator' }));
// menu.append(new nw.MenuItem({ label: 'Item C' }));

// // Hooks the "contextmenu" event
// document.body.addEventListener('contextmenu', function(ev) {
//     // Prevent showing default context menu
//     ev.preventDefault();
//     // Popup the native context menu at place you click
//     menu.popup(ev.x, ev.y);
  
//     return false;
//   }, false);
  