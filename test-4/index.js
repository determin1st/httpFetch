"use strict";
window.addEventListener('load', function() {
    ////
    // prepare
    var a, b;
    var b1  = document.querySelector('button.b1');
    var b2  = document.querySelector('button.b2');
    var b3  = document.querySelector('button.b2');
    var h1  = document.querySelector('h1');
    var data = {
        client_id: 'Iv1.0083b2083e6bf04f',
        client_secret: 'b05178a2a62f11cc6e5603665e356b7bd5e68ad7',
        redirect_uri: 'https://raw.githack.com/determin1st/httpFetch/master/test-4/index.html',
        code: '',
        token: ''
    };
    // check initial state
    debugger;
    if (a = window.location.search && a.indexOf('?code=') === 0)
    {
        // get temporary code
        b = a.substring(1).split('&');
        b.forEach(function(a) {
            a = a.split('=');
            data[a[0]] = a[1];
        });
        // clear location
        window.location.search = '';
        // show next step
        setTimeout(function() {
            h1.innerText = '';
            b2.classList.remove('hidden');
        }, 1000);
    }
    else
    {
        // show first step
        setTimeout(function() {
            h1.innerText = '';
            b1.classList.remove('hidden');
        }, 1000);
    }
    // set handlers
    b1.addEventListener('click', function(e) {
        ////
        // step1: auth redirect
        var url  = 'https://github.com/login/oauth/authorize';
        window.location = url+'?client_id='+data.client_id+'&redirect_uri='+data.redirect_uri;
    });
    b2.addEventListener('click', function(e) {
        ////
        // step2: exchange
        // prepare
        h1.innerText = 'exchanging code for token..';
        b2.disabled = true;
        // send request
        httpFetch({
            url: 'https://github.com/login/oauth/access_token',
            data: {
                client_id: data.client_id,
                client_secret: data.client_secret,
                code: data.code
            }
        }, function(ok, res) {
            if (ok)
            {
                debugger;
                /***
                h1.innerText = res.name;
                if (res.picture)
                {
                    img.src = res.picture;
                    img.classList.add('exist');
                }
                /***/
            }
            else
            {
                h1.innerText = 'error';
                console.log(res);
            }
            //b2.disabled = false;
        });
    });
});
