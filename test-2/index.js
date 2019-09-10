"use strict";
window.addEventListener('load', function() {
    ////
    var test = function()
    {
        var url  = 'https://accounts.google.com/o/oauth2/v2/auth';
        var data = {
            client_id: '167739649429-tq1c78uvikndmf8sv5c0290rtnrpq771.apps.googleusercontent.com',
            response_type: 'token',
            redirect_uri: 'https://raw.githack.com/determin1st/httpFetch/master/test-2/index.html',
            scope: 'profile'
        };
        /***
        httpFetch.post(url, data, function(ok, res) {
            debugger;
        });
        /***/
        window.location = url+'?client_id='+data.client_id+
            '&response_type='+data.response_type+
            '&redirect_uri='+data.redirect_uri+
            '&scope='+data.scope;
    }
    document.querySelector('button').addEventListener('click', function(e) {
        test();
    });
    document.body.style.display = '';
    console.log(window.location);
    ////
});
