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
        //baseUrl: 'http://localhost/api/test/',
        timeout: 5
    });
    // set event handler
    button.addEventListener('click', async function(e) {
        var a,b, res;
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
        res = await myFetch('sleep/10');
        if (res instanceof Error) {
            console.log('#1: '+res.message+': ok!');
        }
        else {
            console.log('#1: fail!');
        }
        // #2: incorrect JSON responses
        res = await myFetch('json/text');
        if (res instanceof Error) {
            console.log('#2.1: '+res.message+': ok!');
        }
        else {
            console.log('#2.1: fail!');
        }
        res = await myFetch('json/empty_string');
        if (res instanceof Error) {
            console.log('#2.2: '+res.message+': fail!');
        }
        else {
            console.log('#2.2: ok!');
        }
        res = await myFetch({
            url: 'json/empty',
            notNull: true
        });
        if (res instanceof Error) {
            console.log('#2.3: '+res.message+': ok!');
        }
        else {
            console.log('#2.3: fail!');
        }
        res = await myFetch('json');
        if (res instanceof Error) {
            console.log('#2.4: '+res.message+': fail!');
        }
        else {
            console.log('#2.4: ok!');
        }
        res = await myFetch('json/incorrect');
        if (res instanceof Error) {
            console.log('#2.4: '+res.message+': ok!');
        }
        else {
            console.log('#2.4: fail!');
        }
        // #3: Random http statuses (except 200=OK)
        // Unfortunately, Chrome/Firefox, both are unable to bring some statuses
        // to the caller API when CORS fails..
        for (var s of [1,2,3,4,5])
        {
            res = await myFetch('status/'+s);
            if (res instanceof Error) {
                console.log('#3.'+s+'xx:'+res.status+': '+res.message+': ok!');
            }
            else {
                console.log('#3.'+s+'xx: fail!');
            }
        }
        a = '#4, GET method with BODY: '
        b = await myFetch({
            url: 'echo',
            method: 'GET',
            headers: {
                'content-type': 'text/plain'
            },
            data: 'GET with BODY!'
        });
        if (b instanceof Error) {
            console.log(a+b.message+': fail!');
        }
        else {
            console.log(a+b+': ok!');
        }
        a = '#5, POST method without BODY: ';
        b = await myFetch({
            url: 'echo',
            method: 'POST'
        });
        if (b instanceof Error) {
            console.log(a+b.message+': fail!');
        }
        else {
            console.log(a+b+': ok!');
        }
        a = '#6, POST method with NULL: ';
        b = await myFetch({
            url: 'echo',
            method: 'POST',
            data: null
        });
        if (b instanceof Error) {
            console.log(a+b.message+': fail!');
        }
        else {
            console.log(a+b+': ok!');
        }
        /***
        a = '#7, ...: ';
        b = await httpFetch({
            //url: 'https://wpdemo.gatsbycentral.com/wp-json',
            url: 'https://engineersf.com/wp-json',
            method: 'GET'
        });
        if (b instanceof Error)
        {
            console.log(a+b.message+': fail!');
        }
        else
        {
            console.log(a+b+': ok!');
        }
        /***/
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
