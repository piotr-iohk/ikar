function showIt(id) {
  var elements = document.getElementsByClassName("displ_details");

  for (var i = 0; i < elements.length; i++) {
    elements[i].style.display = "none"
  }
  
  document.getElementById(id).style.display = "inline";
}