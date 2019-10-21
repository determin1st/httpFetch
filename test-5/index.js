"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    ////
    // prepare
    var btn = document.querySelector('button');
    var myFetch = httpFetch.create({
        baseUrl: 'http://46.4.19.13:30980/api/test/',
        timeout: 0
    });
    var promise, data;
    // set event handler
    btn.addEventListener('click', async function(e) {
        ////
        // check promise state and
        // cancel currently running request (if any)
        if (promise && promise.pending) {
            promise.cancel();
        }
        // make a new request
        console.log('BEGIN');
        data = await (promise = myFetch.get('sleep/10'));
        // check result
        if (data instanceof Error) {
            console.log('ERROR: '+data.message);
        }
        else {
            console.log('OK: slept for some time..');
        }
        console.log('END');
    });
    /*CODE*/
    ////
    // get source code
    var a,b,c;
    main = main.toString();
    a = '\/*CODE*\/';
    b = main.indexOf(a) + a.length;
    c = main.substr(b);
    c = c.substr(0, c.indexOf(a));
    // set
    a = document.querySelector('.main .javascript');
    a.innerHTML = c;
    // done
    hljs.initHighlighting();
});
