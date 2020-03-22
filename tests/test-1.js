"use strict";

var test = async function() {
    // prepare controls
    var btn = [...document.querySelectorAll('button')];
    soFetch && btn.forEach(function(b) {
        b.disabled = false;
    });
    // set event handlers
    btn[0].addEventListener('click', async function(e) {
        // {{{
        if (!this.disabled)
        {
            // lock
            this.disabled = true;
            console.log('BEGIN:'+this.innerText);
            // run
            await soFetch({
                url: '/tests/sleep/6',
                timeout: 5
            }).then(assert(' > timeout: ', false));
            // unlock
            console.log('END:'+this.innerText);
            this.disabled = false;
        }
        // }}}
    });
    btn[1].addEventListener('click', async function(e) {
        // {{{
        if (!this.disabled)
        {
            // lock
            this.disabled = true;
            console.log('BEGIN:'+this.innerText);
            // run
            await soFetch('/tests/json/text')
                .then(assert(' > incorrect string: ', false));
            await soFetch('/tests/json/empty_string')
                .then(assert(' > empty string: ', true));
            await soFetch('/tests/json/null')
                .then(assert(' > JSON NULL: ', true));
            await soFetch('/tests/json/empty')
                .then(assert(' > empty response (no content): ', true));
            await soFetch({
                url: '/tests/json/empty',
                notNull: true
            }).then(assert(' > empty response but notNull: ', false));
            await soFetch('/tests/json/incorrect')
                .then(assert(' > incorrect object: ', false));
            await soFetch('/tests/json/withBOM')
                .then(assert(' > with BOM: ', true));
            // unlock
            console.log('END:'+this.innerText);
            this.disabled = false;
        }
        // }}}
    });
    btn[2].addEventListener('click', async function(e) {
        // {{{
        var a,b;
        if (!this.disabled)
        {
            // lock
            this.disabled = true;
            console.log('BEGIN:'+this.innerText);
            // run
            a = [
                100,100,
                204,
                300,303,
                400,404,
                500
            ];
            b = -1;
            while (++b < a.length)
            {
                await soFetch('/tests/status/'+a[b])
                    .then(assert(' > status '+a[b]+': ', false));
            }
            // unlock
            console.log('END:'+this.innerText);
            this.disabled = false;
        }
        // }}}
    });
    btn[3].addEventListener('click', async function(e) {
        // {{{
        if (!this.disabled)
        {
            // lock
            this.disabled = true;
            console.log('BEGIN:'+this.innerText);
            // run
            await soFetch.form({
                url: '/tests/echo',
                method: 'GET',
                data: 'GOT with BODY!'
            }).then(assert(' > GET with BODY: ', false));
            await soFetch({
                url: '/tests/echo',
                method: 'POST'
            }).then(assert(' > POST without BODY: ', true));
            await soFetch({
                url: '/tests/echo',
                method: 'POST',
                data: null
            }).then(assert(' > POST with NULL: ', true));
            // unlock
            console.log('END:'+this.innerText);
            this.disabled = false;
        }
        // }}}
    });
    btn[4].addEventListener('click', async function(e) {
        // {{{
        if (!this.disabled)
        {
            // lock
            this.disabled = true;
            console.log('BEGIN:'+this.innerText);
            // run
            await soFetch({
                url: '/tests/redirect/21',
                timeout: 0
            }).then(assert(' > auto redirect: ', false));
            await soFetch({
                url: '/tests/redirect/20',
                timeout: 0
            }).then(assert(' > auto redirected: ', true));
            await soFetch({
                url: '/tests/redirect/5',
                timeout: 0,
                redirect: 'manual'
            }).then(assert(' > manual redirect: ', true));
            await soFetch({
                url: '/tests/redirect-300/6',
                timeout: 0,
                redirect: 'manual'
            }).then(assert(' > manual redirect 300: ', false));
            await soFetch({
                url: '/tests/redirect-300/5',
                timeout: 0,
                redirect: 'manual'
            }).then(assert(' > manually redirected 300: ', true));
            // unlock
            console.log('END:'+this.innerText);
            this.disabled = false;
        }
        // }}}
    });
};

