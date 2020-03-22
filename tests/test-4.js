"use strict";

var test = async function() {
    // prepare
    var btn = [...document.querySelectorAll('button')];
    soFetch && btn.forEach(function(b) {
        b.disabled = false;
    });
    // create custom fetcher
    var oFetch = soFetch.create({
        notNull: true, // treat nulls as errors
        headers: {
            accept: 'application/json' // accept only JSON
        }
    });
    // set event handlers
    btn[0].addEventListener('click', async function(e) {
        // custom redirects {{{
        var a,url,res;
        if (!this.disabled)
        {
            // lock
            this.disabled = true;
            // loop
            a = assert(this.innerText+': ', true);
            url = '/tests/redirect-custom/30';
            while (res = await oFetch(url))
            {
                if (res instanceof Error)
                {
                    // display error and abort
                    a(res);
                    break;
                }
                else if (typeof res === 'string')
                {
                    // display redirection
                    a(res);
                    // to follow custom redirect,
                    // replace url parameter
                    url = res;
                }
                else
                {
                    // display final result and complete
                    console.log(res.content || res);
                    break;
                }
            }
            // unlock
            this.disabled = false;
        }
        // }}}
    });
    btn[1].addEventListener('click', function(e) {
        // random redirects {{{
        if (!this.disabled)
        {
            // prepare
            var a = assert(this.innerText+': ', true);
            // lock
            this.disabled = true;
            // retry with async callback
            oFetch('/tests/redirect-custom/-1', async function(ok, res) {
                while (true)
                {
                    if (res instanceof Error)
                    {
                        // display error and abort
                        a(res);
                    }
                    else if (typeof res !== 'string')
                    {
                        // display final result and complete
                        console.log(res.content || res);
                    }
                    else
                    {
                        // display redirection
                        a(res);
                        // mutate request url to follow this redirect
                        this.response.request.setUrl(oFetch.baseUrl, res);
                        break;
                    }
                    // unlock
                    btn[1].disabled = false;
                    return false;// don't retry
                }
                return true;// retry
            });
        }
        // }}}
    });
    btn[2].addEventListener('click', async function(e) {
        // native redirects {{{
        var a,res;
        if (!this.disabled)
        {
            // prepare
            var a = assert(this.innerText+': ', true);
            // lock
            this.disabled = true;
            // fetch
            res = await oFetch({
                url: '/tests/redirect/20',
                headers: {
                    accept: null // remove content-type restriction
                }
            });
            // check
            a(res);
            // unlock
            this.disabled = false;
        }
        // }}}
    });
};
