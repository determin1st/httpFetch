"use strict";
window.addEventListener('load', function() {
    ////
    // prepare
    var token = {};
    var url  = 'https://accounts.google.com/o/oauth2/v2/auth';
    var data = {
        client_id: '167739649429-tq1c78uvikndmf8sv5c0290rtnrpq771.apps.googleusercontent.com',
        response_type: 'token',
        redirect_uri: 'https://raw.githack.com/determin1st/httpFetch/master/test-2/index.html',
        scope: 'profile'
    };
    var a, b, c;
    ////
    // check token set
    if (a = window.location.hash)
    {
        // parse token
        b = a.substring(1).split('&');
        b.forEach(function(a) {
            a = a.split('=');
            token[a[0]] = a[1];
        });
        debugger;
        // clear location and show document body
        window.location.hash = '';
        document.body.style.display = '';
        // prepare test
        document.querySelector('button').addEventListener('click', function(e) {
        });
    }
    else
    {
        // redirect
        window.location = url+'?client_id='+data.client_id+
            '&response_type='+data.response_type+
            '&redirect_uri='+data.redirect_uri+
            '&scope='+data.scope;
    }
});
