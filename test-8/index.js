"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    // create custom fetcher
    var oFetch = httpFetch.create({
        //baseUrl: 'http://localhost/api/test/',
        baseUrl: 'http://46.4.19.13:30980/api/test/',
        timeout: 0,    // wait indefinately
        notNull: true, // treat nulls as errors
        headers: {
            accept: 'application/json' // accept only JSON content
        }
    });
    // initialize controls
    // prepare
    var b1 = document.querySelector('.control > .b1');
    var b2 = document.querySelector('.control > .b2');
    var b3 = document.querySelector('.control > .b3');
    // set events
    b1.addEventListener('click', async function(e) {
        // custom redirects {{{
        var url,res;
        ///
        // lock control
        if (b1.disabled) {
            return;
        }
        b1.disabled = true;
        console.log('BEGIN custom redirects');
        // iterate forever
        url = 'redirect-custom/30';
        while (res = await oFetch(url))
        {
            if (res instanceof Error)
            {
                // display error
                console.log('ERROR');
                break;
            }
            else if (typeof res === 'string')
            {
                // follow custom redirect
                console.log('REDIRECT: '+res);
                // replace url parameter
                url = res;
            }
            else
            {
                // display final result
                console.log(res.content || res);
                break;
            }
        }
        // unlock
        console.log('END custom redirects');
        b1.disabled = false;
        // }}}
    });
    b2.addEventListener('click', function(e) {
        // random redirects {{{
        ///
        // lock control
        if (b2.disabled) {
            return;
        }
        b2.disabled = true;
        console.log('BEGIN random redirects');
        // retry with async callback
        oFetch('redirect-random/1', async function(ok, res, req) {
            while (true)
            {
                if (res instanceof Error)
                {
                    // display error
                    console.log('ERROR');
                }
                else if (typeof res !== 'string')
                {
                    // display final result
                    console.log(res.content || res);
                }
                else
                {
                    // follow custom redirect
                    console.log('REDIRECT: '+res);
                    break;
                }
                // unlock
                console.log('END random redirects');
                b2.disabled = false;
                // don't retry
                return false;
            }
            // mutate request with different url
            req.setUrl(oFetch.baseUrl, res);
            // retry
            return true;
        });
        // }}}
    });
    b3.addEventListener('click', async function(e) {
        var res;
        // native redirects {{{
        ///
        // lock control
        if (b3.disabled) {
            return;
        }
        b3.disabled = true;
        console.log('BEGIN native redirects');
        // fetch
        res = await oFetch({
            url: 'redirect/20',
            headers: {
                accept: null // no content-type restriction
            }
        });
        // check
        if (res instanceof Error)
        {
            // display error
            console.log('ERROR: '+res.message);
        }
        else
        {
            // display final result
            console.log(res);
        }
        // unlock
        console.log('END native redirects');
        b3.disabled = false;
        // }}}
    });
    /*CODE*/
    ///
    // helpers {{{
    var help = {
        b1_locked: false,
        ////
        ////
        delay: function(ms)
        {
            var r = null;
            var p = new Promise(function(resolve) {
                r = resolve;
            });
            setTimeout(r, ms);
            return p;
        }
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
    window.dispatchEvent(new Event('resize'));
    // }}}
});
