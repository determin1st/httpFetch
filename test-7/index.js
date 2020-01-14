"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    ///
    // encryption control
    // prepare
    var tSecret = document.querySelector('.control > textarea');
    var bHand   = document.querySelector('.control > .b1');
    var bReset  = document.querySelector('.control > .b2');
    var myFetch = httpFetch.create({
        baseUrl: 'http://localhost:8081/api/test/'
    });
    var secretManager = function(key) {
        var a, b, c;
        ///
        // saves or restores shared secret
        // the argument determines the type of operation (get or set),
        // the browser's local storage is used here
        if (key === '')
        {
            // reset
            window.localStorage.removeItem('secret');
        }
        else if (key)
        {
            // set
            window.localStorage.setItem('secret', key);
            c = ' (exchange)';
        }
        else
        {
            // get
            if ((key = window.localStorage.getItem('secret')) === null) {
                key = '';
            }
            c = ' (localstorage)';
        }
        // display key information
        if (key)
        {
            a = help.base64ToBuf(key);
            b = a.slice(32);
            a = a.slice(0, 32);
            tSecret.value = "AES GCM encryption enabled"+c+"\n\n"+
                "Cipher key (256bit): "+help.bufToHex(a)+"\n"+
                "Counter/IV  (96bit): "+help.bufToHex(b)+"\n";
        }
        else {
            tSecret.value = '';
        }
        // done
        return key;
    };
    // set event handlers
    bHand.addEventListener('click', async function(e) {
        ///
        // lock button
        this.disabled = true;
        // establish shared secret
        if (await myFetch.handshake('ecdh', secretManager))
        {
            // unlock reset
            bReset.disabled = false;
        }
        else
        {
            // reset on failure
            this.disabled = false;
            tSecret.value = '';
        }
    });
    bReset.addEventListener('click', function(e) {
        ///
        // reset
        this.disabled  = true;
        bHand.disabled = false;
        tSecret.value  = '';
        myFetch.handshake();
    });
    ///
    // content-type: plain/text
    // preapre
    var bSend = document.querySelector('.message.text button');
    var tArea = [...document.querySelectorAll('.message.text textarea')];
    // set event handler
    bSend.addEventListener('click', function(e) {
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
