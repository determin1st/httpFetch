"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    ///
    // Initialize
    // create custom instance
    var myFetch = httpFetch.create({
        // for the future requests,
        // setting this option is a convenient way to reduce url:
        baseUrl: 'http://46.4.19.13:30980/api/test/',
        // to display detailed information about request and response data,
        // the following option must be enabled:
        fullHouse: true
    });
    // to handle secret key storage operations,
    // a special callback function must be created:
    var secretManager = function(op, data)
    {
        var a, b, c;
        ///
        // check operation
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
                a = ' (localstorage)';
                break;
            case 'set':
                ///
                // after successful handshake or fetch response,
                // secret may be saved to the storage of choice.
                ///
                window.localStorage.setItem('mySecret', data);
                a = ' (exchange)';
                break;
            case 'destroy':
                ///
                // when something goes wrong and the secret should be destroyed,
                // this operation erases it from the storage of choice.
                ///
                window.localStorage.removeItem('mySecret');
                break;
        }
        ///
        // display key information
        if (data)
        {
            b = help.base64ToBuf(data);
            c = b.slice(32);
            tSecret.value = "AES GCM encryption enabled"+a+"\n\n"+
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
    ///
    // Encryption control
    // prepare
    var tSecret    = document.querySelector('.control > textarea');
    var bHandshake = document.querySelector('.control > .b1');
    var bReset     = document.querySelector('.control > .b2');
    // set events
    bHandshake.addEventListener('click', async function(e) {
        ///
        // check
        if (!myFetch.handshake)
        {
            tSecret.value = 'Web Crypto API is not available (crypto.subtle is undefined)';
            return;
        }
        ///
        // try to establish shared secret.
        // repeated handshakes will fail until first is resolved, so
        // it is safe (but useless) to invoke this function multiple times.
        ///
        if (await myFetch.handshake('ecdh', secretManager))
        {
            ///
            // positive result means that future requests made
            // with this httpFetch instance will be encrypted.
            // next handshake call will destory current secret
            // and initiate new exchange. to disable this behaviour,
            // disable this button:
            ///
            bHandshake.disabled = true;
            bReset.disabled = false;
        }
    });
    bReset.addEventListener('click', function(e) {
        ///
        // check if encryption enabled
        if (myFetch.secret)
        {
            // the secret key will be destoyed and encryption disabled,
            // when handshake is called without parameters:
            myFetch.handshake();
            // reset buttons
            bHandshake.disabled = false;
            bReset.disabled = true;
        }
    });
    ///
    // content-type: text/plain
    // preapre
    var bSend = document.querySelector('.test.n1 button');
    var tArea = [...document.querySelectorAll('.test.n1 textarea')];
    // set event handler
    bSend.addEventListener('click', async function(e) {
        var a, b;
        ///
        // clear textareas
        tArea[1].value = '';
        tArea[2].value = '';
        tArea[3].value = '';
        // send message
        a = await myFetch({
            url: 'echo',
            headers: {'content-type': 'text/plain'},
            data: tArea[0].value
        });
        // display results
        if (a instanceof Error)
        {
            console.log(a);
        }
        else if (!a)
        {
            console.log('empty response');
        }
        else
        {
            if (b = a.request.crypto) {
                tArea[1].value = help.bufToHex(b.data);
            }
            tArea[2].value = a.data;
            if (b = a.crypto) {
                tArea[3].value = help.bufToHex(b.data);
            }
        }
    });
    /*CODE*/
    var help = {
      base64ToBuf: function(str){
        var a, b, c, d;
        a = atob(str);
        b = a.length;
        c = new Uint8Array(b);
        d = -1;
        while (++d < b) {
          c[d] = a.charCodeAt(d);
        }
        return c;
      },
      bufToHex: function(){
        var hex, i, n;
        hex = [];
        i = -1;
        n = 255;
        while (++i < n) {
          hex[i] = i.toString(16).padStart(2, '0');
        }
        return function(buf){
          var a, b, i, n;
          a = new Uint8Array(buf);
          b = [];
          i = -1;
          n = a.length;
          while (++i < n) {
            b[i] = hex[a[i]];
          }
          return b.join('');
        };
      }()
    };
    // some auto-tester
    window.test = function(count) {
        var cycle = function() {
            setTimeout(function() {
                if (--count)
                {
                    bSend.click();
                    cycle();
                }
                else {
                    console.log('finished');
                }
            }, 100);
        };
        cycle();
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
});
