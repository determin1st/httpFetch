"use strict";
window.addEventListener('load', function() {
    ////
    var test;
    var h1 = document.querySelector('h1');
    var h4 = document.querySelector('h4');
    document.querySelector('button').addEventListener('click', test = function(e) {
        ////
        httpFetch('https://api.quotable.io/random', function(ok, res) {
            if (ok)
            {
                // set quote..
                if (res && res.hasOwnProperty('content'))
                {
                    h1.innerText = res.content;
                    h4.innerHTML = '&mdash;'+res.author;
                }
                else
                {
                    h1.innerText = "I didn't fail the test, I just found 100 ways to do it wrong";
                    h4.innerHTML = '&mdash; Benjamin Franklin (unexpected server response)';
                }
            }
            else
            {
                // set error quote..
                h1.innerText = res.message;
                h4.innerHTML = '&mdash;Error';
            }
        });
    });
    ////
    test();
    document.body.style.display = '';
});
