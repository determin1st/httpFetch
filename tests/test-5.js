"use strict";

var test = async function() {
    // prepare
    var btn = [...document.querySelectorAll('button')];
    var img = document.querySelector('.control img');
    var stream, blob;
    // set event handlers
    btn[0].addEventListener('click', async function(e) {
        // data {{{
        if (!this.disabled)
        {
            // prepare
            lockButtons();
            // fetch image blob (all in a single chunk)
            blob = soFetch({
                url: '/tests/download/img',
                notNull: true
            });
            blob = await blob;
            // check
            assert('got data: ', true)(blob);
            if (!(blob instanceof Error))
            {
                showImage(URL.createObjectURL(blob));
            }
            // done
            unlockButtons();
        }
        // }}}
    });
    btn[1].addEventListener('click', async function(e) {
        // stream {{{
        var chunk;
        if (!this.disabled)
        {
            // prepare
            lockButtons(true);
            // fetch image stream
            stream = await soFetch({
                url: '/tests/download/img',
                notNull: true,
                parseResponse: 'stream' // FetchStream
            });
            // check
            assert('stream started: ', true)(stream);
            if (!(stream instanceof Error))
            {
                // prepare
                showImage();
                // read stream as it goes
                while (chunk = await stream.read())
                {
                    showProgress(chunk);
                    updateImage(chunk);
                }
                // display result
                assert('stream finished: ', true)(stream.error);
                console.log('timing: '+stream.timing);
            }
            // done
            unlockButtons();
        }
        // }}}
    });
    btn[2].addEventListener('click', async function(e) {
        // chunks {{{
        var chunk,a;
        if (!this.disabled)
        {
            // prepare
            lockButtons(true);
            // fetch image stream
            stream = await soFetch({
                url: '/tests/download/img',
                notNull: true,
                parseResponse: 'stream' // FetchStream
            });
            // check
            assert('chunked stream started: ', true)(stream);
            if (!(stream instanceof Error))
            {
                // prepare
                showImage();
                // read stream in exact chunks
                while (chunk = await stream.read(512))
                {
                    showProgress(chunk);
                    updateImage(chunk);
                    ////
                    // slow down streaming
                    if (stream.latency < 20) {
                        await sleep(20 - stream.latency);
                    }
                }
                // display result
                assert('chunked stream finished: ', true)(stream.error);
                console.log('timing: '+stream.timing);
            }
            // done
            unlockButtons();
        }
        // }}}
    });
    btn[3].addEventListener('click', function(e) {
        // pause {{{
        if (stream.pause())
        {
            btn[3].disabled = true;
            btn[4].disabled = false;
        }
        // }}}
    });
    btn[4].addEventListener('click', function(e) {
        // resume {{{
        if (stream.resume())
        {
            btn[3].disabled = false;
            btn[4].disabled = true;
        }
        // }}}
    });
    btn[5].addEventListener('click', function(e) {
        // cancel {{{
        if (stream)
        {
            stream.cancel();
        }
        else
        {
            blob.cancel();
        }
        // }}}
    });
    /***/
    // HELPERS {{{
    var showProgress = function(chunk)
    {
        console.log('got chunk, size='+chunk.length+' '+
                    'progress='+(100 * stream.progress).toFixed(0)+'% '+
                    'latency='+stream.latency.toFixed()+'ms');
    };
    var updateImage = function(chunk)
    {
        var a,b;
        // accumulate chunks
        if (!blob) {
            blob = [];
        }
        blob.push(chunk);
        // create image blob
        a = new Blob(blob, {type: 'image/jpeg'});
        // update image source
        b = img.src;
        img.src = URL.createObjectURL(a);
        // dispose previous source
        if (b) {
            URL.revokeObjectURL(b);
        }
    };
    var lockButtons = function(isStream)
    {
        btn[0].disabled = true;
        btn[1].disabled = true;
        btn[2].disabled = true;
        if (isStream) {
            btn[3].disabled = false;
        }
        btn[4].disabled = true;
        btn[5].disabled = false;
        // cleanup
        stream = blob = null;
        hideImage();
    };
    var unlockButtons = function()
    {
        btn[0].disabled = false;
        btn[1].disabled = false;
        btn[2].disabled = false;
        btn[3].disabled = true;
        btn[4].disabled = true;
        btn[5].disabled = true;
    };
    var showImage = function(url)
    {
        if (typeof url === 'string') {
            img.src = url;
        }
        img.style.opacity = 1;
    };
    var hideImage = function()
    {
        if (img.src)
        {
            URL.revokeObjectURL(img.src);
            img.src = '';
        }
        img.style.opacity = 0;
    };
    // }}}
    /***/
    soFetch && unlockButtons();
};
