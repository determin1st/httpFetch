"use strict";
window.addEventListener('load', function() {
    ////
    // prepare
    var btn = document.querySelector('button');
    // set handlers
    btn.addEventListener('click', function(e) {
        var a;
        /***/
        httpFetch.get('http://localhost:8081/api/test/sleep')
            .then(function(res) {
                debugger;
                if (res instanceof Error)
                {
                }
                else
                {
                }
        });
        /***
        a = await axios.get('http://localhost:8081/api/test/sleep');
        debugger;
        /***/
    });
});
