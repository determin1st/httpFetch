"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    ////
    // prepare
    var bHandshake = document.querySelector('button.handshake');
    var bReset     = document.querySelector('button.reset');
    var tSecret    = document.querySelector('div.cipher > textarea');
    var myFetch = httpFetch.create({
        baseUrl: 'http://localhost:8081/api/test/'
    });
    var secretManager = function(key) {
        var a,b;
        ////
        // check parameter
        if (key) {
            // save secret key
            window.localStorage.setItem('secret', key);
            // display key information
            a = help.base64ToBuf(key);
            b = a.slice(0, 12);
            a = a.slice(0, 32);
            tSecret.value = "AES GCM encryption enabled\n\n"+
                "Cipher key(256bit): "+help.bufToHex(a)+"\n\n"+
                "Counter/IV(96bit): "+help.bufToHex(b)+"\n";
        }
        else {
            // restore secret key
            if ((key = window.localStorage.getItem('secret')) === null) {
                key = '';
            }
        }
        return key;
    };
    // set event handlers
    bHandshake.addEventListener('click', async function(e) {
        ////
        // lock
        this.disabled = true;
        // exchange public keys and establish shared secret
        if (await myFetch.handshake('ecdh', secretManager)) {
            // enable reset
            bReset.disabled = false;
        }
        else
        {
            // clear key information
            tSecret.value = '';
            // unlock
            this.disabled = false;
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
