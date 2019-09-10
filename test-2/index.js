"use strict";
window.addEventListener('load', function() {
    ////
    var test = function()
    {
        var url  = 'https://accounts.google.com/o/oauth2/v2/auth';
        var data = {
            client_id: '167739649429-kek60h1r979qdtpa1do04qjnctihnm22.apps.googleusercontent.com',
            redirect_uri: 'https://raw.githack.com/determin1st/httpFetch/master/test-2/index.html',
            scope: 'profile'
        };
        httpFetch.post(url, data, function(ok, res) {
            debugger;
        });
    }
    test();
    document.body.style.display = '';
    ////
});
