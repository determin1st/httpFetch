"use strict";
window.addEventListener('load', function() {
    ////
    // prepare
    var token = {}, a, b;
    var b1  = document.querySelector('button.b1');
    var b2  = document.querySelector('button.b2');
    var h1  = document.querySelector('h1');
    var img = document.querySelector('img');
    // check
    if (a = window.location.hash)
    {
        // parse token
        b = a.substring(1).split('&');
        b.forEach(function(a) {
            a = a.split('=');
            token[a[0]] = a[1];
        });
        // clear location
        window.location.hash = '';
        // done
        setTimeout(function() {
            h1.innerText = '';
            b2.classList.remove('hidden');
        }, 1000);
    }
    else
    {
        // done
        setTimeout(function() {
            h1.innerText = '';
            b1.classList.remove('hidden');
        }, 1000);
    }
    // set handlers
    b1.addEventListener('click', function(e) {
        ////
        // auth redirect
        var url  = 'https://accounts.google.com/o/oauth2/v2/auth';
        var data = {
            client_id: '167739649429-tq1c78uvikndmf8sv5c0290rtnrpq771.apps.googleusercontent.com',
            response_type: 'token',
            redirect_uri: 'https://raw.githack.com/determin1st/httpFetch/master/test-2/index.html',
            //scope: 'profile%20https://www.googleapis.com/auth/drive'
            scope: 'profile'
        };
        window.location = url+'?client_id='+data.client_id+
            '&response_type='+data.response_type+
            '&redirect_uri='+data.redirect_uri+
            '&scope='+data.scope;
    });
    b2.addEventListener('click', function(e) {
        ////
        // prepare
        img.classList.remove('exist');
        img.src = '';
        h1.innerText = 'fetching..';
        b2.disabled = true;
        ////
        // send request
        httpFetch({
            //url: 'https://www.googleapis.com/drive/v3/files',
            url: 'https://www.googleapis.com/oauth2/v1/userinfo',
            headers: {
                Authorization: 'Bearer '+token.access_token
            }
        }, function(ok, res) {
            if (ok)
            {
                h1.innerText = res.name;
                if (res.picture)
                {
                    img.src = res.picture;
                    img.classList.add('exist');
                }
            }
            else
            {
                h1.innerText = 'error';
                console.log(res);
            }
            b2.disabled = false;
        });
    });
});
