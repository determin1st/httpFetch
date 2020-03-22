"use strict";

var test = async function() {
    // prepare
    var btn = [...document.querySelectorAll('button')];
    soFetch && btn.forEach(function(b) {
        b.disabled = false;
    });
    var promise, res;
    var sleep = function(timeout) {
        return async function(e) {
            ////
            if (!this.disabled)
            {
                // start sleeping
                console.log('sleeping '+timeout+'..');
                promise = soFetch({
                    url: '/tests/sleep/10',
                    timeout: timeout
                });
                // lock
                btn[0].disabled = true;
                btn[1].disabled = true;
                btn[2].disabled = false;
                // wait
                res = await promise;
                // check
                if (res instanceof Error) {
                    console.log('interrupted('+res.id+'): '+res.message);
                }
                else {
                    console.log('overslept.');
                }
                // unlock
                btn[0].disabled = false;
                btn[1].disabled = false;
                btn[2].disabled = true;
            }
        };
    };
    // set event handlers
    btn[0].addEventListener('click', sleep(10));
    btn[1].addEventListener('click', sleep(11));
    btn[2].disabled = true;
    btn[2].addEventListener('click', async function(e) {
        // cancel request
        if (promise && promise.pending) {
            promise.cancel();// or promise.abort()
        }
    });
};
