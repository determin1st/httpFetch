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
    var iFetch, a, b;
    ////
    token = {
        access_token:"ya29.GluAB4KA23TaSsoEN6jpNlbBs_5qKqy_3tTNDipIBYOQbNJf0b8KvxQ1-R30zbcbOqzJ5FgIxjZKZbZINu-i0cydvZyoCjRu_pR-MPsjYfC1RYeeJcsSf0UJkS7u",
        token_type:"Bearer",
        expires_in:"3600",
        scope:"profile%20https://www.googleapis.com/auth/userinfo.profile"
    };
    httpFetch({
        url: 'https://www.googleapis.com/auth/userinfo.profile',
        headers: {
            Authorization: 'Bearer '+token.access_token
        }
    }, function(ok, res) {
        debugger;
    });
    return;
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
        // create new httpFetch instance
        iFetch = httpFetch.create({
            baseUrl: '',
        });
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
