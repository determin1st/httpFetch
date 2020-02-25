"use strict";
var main;
window.addEventListener('load', main = async function() {
    /*CODE*/
    ////
    // prepare
    var file  = document.querySelector('input');
    var btn   = document.querySelector('button');
    var image = document.querySelector('img');
    // set event handlers
    btn.addEventListener('click', function(e) {
        file.click(); // trigger file selection
    });
    file.addEventListener('input', async function(e) {
        ////
        // check file selected
        if (file.files.length !== 1) {
            return;
        }
        // lock
        btn.disabled = true;
        console.log('UPLOADING..');
        // upload single file with metadata using FormData
        var data = await httpFetch({
            url: 'http://46.4.19.13:30980/api/test/upload/put-single-jpg',
            headers: {
                'Content-Type': 'multipart/form-data'
            },
            data: {
                image: file,
                alt: 'test image',
                timestamp: (new Date()).toISOString()
            }
        });
        // check result
        if (data instanceof Error) {
            console.log('ERROR: '+data.message);
        }
        else if (!data) {
            console.log('ERROR: server refused to accept this file..');
        }
        else {
            console.log('OK: upload complete..');
            console.log(data);
        }
        // done
        image.src = image.src; // re-load image
        file.value = ''; // de-select file
        btn.disabled = false; // enable button
    });
    /*CODE*/
    /*
    function uploadImageToImgur(blob) {
    var formData = new FormData();
    formData.append('type', 'file');
    formData.append('image', blob);

    return fetch('https://api.imgur.com/3/upload.json', {
        method: 'POST',
        headers: {
        Accept: 'application/json',
        Authorization: 'Client-ID dc708f3823b7756'// imgur specific
        },
        body: formData
    })
        .then(processStatus)
        .then(parseJson);
    }
    /***/
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
