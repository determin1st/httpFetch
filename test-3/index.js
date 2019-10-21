"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    ////
    // prepare
    var button  = document.querySelector('button');
    var state   = false;
    var myFetch = httpFetch.create({
        baseUrl: 'http://46.4.19.13:30980/api/test/',
        timeout: 5
    });
    // set event handler
    button.addEventListener('click', async function(e) {
        var res;
        ////
        // to prevent simultaneous requests,
        // let's check current state
        if (state) {
            return;
        }
        // lock
        state = true;
        console.log('BEGIN');
        /***/
        // #1: connection timeout
        // Remote API will delay for more than timeout is, so,
        // the request will be cancelled..
        res = await myFetch.get('sleep/10');
        if (res instanceof Error)
        {
            console.log('#1: '+res.message);
            console.log('#1: ok!');
        }
        else
        {
            console.log('#1: failed!');
        }
        /***/
        // #2: incorrect response body
        // The server specifies content-type header as application/json
        // but returns text/html. This may happen when remote code
        // has problems with the output, for example,
        // PHP's [E_NOTICE]/[E_WARNING]/[E_ERROR] pollution..
        res = await myFetch.get('fail/non-json-response');
        if (res instanceof Error)
        {
            console.log('#2: '+res.message);
            console.log('#2: ok!');
        }
        else
        {
            console.log('#2: failed!');
        }
        /***/
        // #3: Random http statuses (except 200=OK)
        // Unfortunately, Chrome/Firefox, both are unable to bring some statuses
        // to the caller API when CORS fails..
        for (var s of [1,2,3,4,5])
        {
            res = await myFetch.get('status/'+s);
            if (res instanceof Error)
            {
                console.log('#3-'+s+'xx:'+res.status+': '+res.message);
                console.log('#3-'+s+'xx:'+res.status+': ok!');
            }
            else
            {
                console.log('#3-'+s+'xx: failed!');
            }
        }
        // unlock
        state = false;
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
