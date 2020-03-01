"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    ////
    // prepare
    var button  = document.querySelector('button');
    var state   = false;
    var myFetch = httpFetch.create({
        //baseUrl: 'http://localhost/api/test/',
        baseUrl: 'http://46.4.19.13:30980/api/test/',
        timeout: 5
    });
    // set event handler
    button.addEventListener('click', async function(e) {
        var a,b,c,d, res;
        // prepare {{{
        // to prevent simultaneous requests,
        // let's check current state
        if (state) {
            return;
        }
        // lock
        state = true;
        console.log('BEGIN');
        // }}}
        /***/
        // run tests {{{
        a = '#1, timeout: ';
        b = await myFetch('sleep/6');
        assert(a, b, false);
        ////
        ////
        a = '#2.1, JSON incorrect string: ';
        b = await myFetch('json/text');
        assert(a, b, false);
        a = '#2.2, JSON empty string: ';
        b = await myFetch('json/empty_string');
        assert(a, b, true);
        a = '#2.3, JSON empty BODY: ';
        b = await myFetch('json/empty');
        assert(a, b, true);
        a = '#2.3, JSON empty BODY but notNull: ';
        b = await myFetch({
            url: 'json/empty',
            notNull: true
        });
        assert(a, b, false);
        a = '#2.4, JSON incorrect object: ';
        b = await myFetch('json/incorrect');
        assert(a, b, false);
        a = '#2.5, JSON with BOM: ';
        b = await myFetch('json/withBOM');
        assert(a, b, true);
        ////
        ////
        // Random http statuses (except 200=OK)
        d = [1,2,3,4,5];
        c = -1;
        while (++c < d.length)
        {
            a = '#3.'+d[c]+'xx, non-200 HTTP STATUS: ';
            b = await myFetch('status/'+d[c]);
            if (b.hasOwnProperty('status')) {
                a += '['+b.status+']: ';
            }
            assert(a, b, false);
        }
        ////
        ////
        a = '#4.1, method GET with BODY: '
        b = await myFetch.text({
            url: 'echo',
            method: 'GET',
            data: 'GET with BODY!'
        });
        assert(a, b, true);
        a = '#4.2, method POST without BODY: ';
        b = await myFetch({
            url: 'echo',
            method: 'POST'
        });
        assert(a, b, true);
        a = '#4.3, method POST with NULL: ';
        b = await myFetch({
            url: 'echo',
            method: 'POST',
            data: null
        });
        ////
        ////
        assert(a, b, true);
        a = '#5.1, auto redirect: ';
        b = await myFetch({
            url: 'redirect/21',
            timeout: 0
        });
        assert(a, b, false);
        a = '#5.2, auto redirected: ';
        b = await myFetch({
            url: 'redirect/20',
            timeout: 0
        });
        assert(a, b, true);
        a = '#5.3, manual redirect: ';
        b = await myFetch({
            url: 'redirect/6',
            timeout: 0,
            redirect: 'manual'
        });
        assert(a, b, true);
        // }}}
        /***
        a = '#5.3, manual redirect: ';
        b = await myFetch({
            url: 'redirect/6',
            mode: 'no-cors',
            timeout: 0,
            redirect: 'manual'
        });
        assert(a, b, true);
        /***/
        /***/
        // complete {{{
        // unlock
        state = false;
        console.log('END');
        // }}}
    });
    /*CODE*/
    // {{{
    // create helpers
    var assert = function(title, res, expect)
    {
        var isError = (res instanceof Error);
        title = '%c'+title;
        if (isError) {
            res = res.message+' ['+res.id+']';
        }
        if (isError !== expect) {
            expect = 'color:green';
        }
        else {
            expect = 'color:red';
        }
        console.log(title+'%c'+res, 'font-weight:bold', expect);
    };
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
    // }}}
});
