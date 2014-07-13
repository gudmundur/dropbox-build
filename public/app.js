$(function() {
    $.getJSON("/app", function(apps) {
        console.log(apps);
    });
});
