"use strict";

var test = async function() {
    // prepare
    var btn = [...document.querySelectorAll('button')];
    var img = document.querySelector('.control img');
    // set event handlers
    btn[0].addEventListener('click', async function(e) {
        // data {{{
        var blob;
        if (!this.disabled)
        {
            // prepare
            lockButtons();
            clearImage();
            // get image blob
            blob = await soFetch({
                url: '/tests/download/img',
                notNull: true
            });
            // check
            assert('got data: ', true)(blob);
            if (!(blob instanceof Error))
            {
                // apply blob to node
                setImage(URL.createObjectURL(blob));
            }
            // complete
            unlockButtons();
        }
        // }}}
    });
    btn[1].addEventListener('click', async function(e) {
        // stream {{{
        var stream, a,b;
        if (!this.disabled)
        {
            // prepare
            lockButtons();
            clearImage();
            // get image stream
            stream = await soFetch({
                url: '/tests/download/img',
                notNull: true,
                parseResponse: 'stream' // FetchStream
            });
            // check
            assert('stream start: ', true)(stream);
            if (!(stream instanceof Error))
            {
                // prepare storage
                a = [];
                setImage(true);
                // read stream
                while (b = await stream.read())
                {
                    // display progress
                    console.log('got chunk, size is '+b.length+' '+
                                'total progress: '+(100 * stream.progress).toFixed(0)+'%');
                    // accumulate into blob
                    a.push(b);
                    b = new Blob(a, {type: 'image/jpeg'});
                    img.src = URL.createObjectURL(b);
                }
                // complete
                assert('stream finished: ', true)(stream.error);
            }
            // unlock
            unlockButtons();
        }
        // }}}
    });
    /***/
    // HELPERS {{{
    var lockButtons = function()
    {
        btn.forEach(function(node) {
            node.disabled = true;
        });
    };
    var unlockButtons = function()
    {
        btn.forEach(function(node) {
            node.disabled = false;
        });
    };
    var setImage = function(url)
    {
        if (typeof url === 'string') {
            img.src = url;
        }
        img.style.opacity = 1;
    };
    var clearImage = function()
    {
        img.style.opacity = 0;
        img.src = '';
    };
    // }}}
    /***/
    soFetch && unlockButtons();
};
