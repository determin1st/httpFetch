"use strict";

var test = async function() {
    // initialize
    // get controls
    var btn = [...document.querySelectorAll('button')];
    var tSecret = document.querySelector('.control > textarea');
    var tArea = [...document.querySelectorAll('.test textarea')];
    // create custom instance
    var cryptoFetch = soFetch.create({
        // to display detailed information about request and response data,
        // the following option must be enabled:
        fullHouse: true,
        // session cookie will be used
        credentials: 'include'
    });
    // to handle secret key storage operations,
    // a special callback must be created:
    var secretManager = function(op, data)
    {
        var a,b,c;
        // check secret operation type
        switch (op)
        {
            case 'get':
                ///
                // before any handshake attempt is made,
                // previous secret may be queried from the storage of choice.
                // here and below, the browser's local storage is used.
                ///
                if ((data = window.localStorage.getItem('mySecret')) === null) {
                    data = '';
                }
                a = 'localstorage';
                break;
            case 'set':
                ///
                // after successful handshake or fetch response,
                // secret may be saved to the storage of choice.
                ///
                window.localStorage.setItem('mySecret', data);
                a = 'exchange';
                break;
            case 'destroy':
                ///
                // this operation erases secret from the storage of choice.
                ///
                window.localStorage.removeItem('mySecret');
                break;
            case 'fail':
                ///
                // protocol failed, erase at will
                // but for test purposes only,
                // information about the failure is displayed
                ///
                // show crypto input if available
                if (a = data.response.request.crypto) {
                    tArea[1].value = help.bufToHex(a.data);
                }
                // get error message
                a = data.message;
                // get secret
                data = cryptoFetch.secret;
                break;
        }
        // display key information
        if (data)
        {
            b = help.base64ToBuf(data);
            c = b.slice(32);
            tSecret.value = "AES GCM encryption enabled ("+a+")\n\n"+
                "Cipher key (256bit): "+help.bufToHex(b.slice(0,  32))+"\n"+
                "Counter/IV  (96bit): "+
                help.bufToHex(c.slice(0,  10))+" (private) + "+
                help.bufToHex(c.slice(10, 12))+" (public)\n";
        }
        else {
            tSecret.value = '';
        }
        return data;
    };
    // set event handlers
    btn[0].addEventListener('click', async function(e) {
        // check
        if (!cryptoFetch.handshake)
        {
            tSecret.value = 'Web Crypto API is not available (crypto is undefined)';
            return;
        }
        ///
        // try to establish shared secret.
        // repeated handshakes will fail until first is resolved, so
        // it is safe (but useless) to invoke this function multiple times.
        ///
        var a = assert('ECDH handshake: ', true);
        if (await cryptoFetch.handshake('/handshake', secretManager))
        {
            ///
            // positive result means that future requests made
            // with this httpFetch instance will be encrypted.
            // next handshake call will destory current secret
            // and initiate new exchange. to disable this behaviour,
            // disable this button:
            ///
            btn[0].disabled = true;
            btn[1].disabled = false;
            a(true);
        }
        else {
            a(new Error('failed'));
        }
    });
    btn[1].addEventListener('click', function(e) {
        ///
        // the secret key will be destoyed and encryption disabled,
        // when handshake is called without parameters:
        ///
        cryptoFetch.handshake();// sync
        // reset buttons
        btn[0].disabled = false;
        btn[1].disabled = true;
    });
    btn[2].addEventListener('click', async function(e) {
        var a,b;
        // clear
        tArea[1].value = '';
        tArea[2].value = '';
        tArea[3].value = '';
        // send
        a = assert('message: ', true);
        b = await cryptoFetch({
            url: '/tests/echo',
            notNull: true,
            headers: {'content-type': 'text/plain'},
            data: tArea[0].value
        });
        // display
        if (b instanceof Error)
        {
            a(b);
        }
        else
        {
            a(b.data);
            if (a = b.request.crypto) {
                tArea[1].value = help.bufToHex(a.data);
            }
            tArea[2].value = b.data;
            if (a = b.crypto) {
                tArea[3].value = help.bufToHex(a.data);
            }
        }
    });
    // auto-tester
    window.autotest = function(count) {
        var cycle = function() {
            setTimeout(function() {
                if (--count)
                {
                    btn[2].click();
                    cycle();
                }
                else {
                    console.log('finished');
                }
            }, 100);
        };
        cycle();
    };
};
