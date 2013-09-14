var http = require('http'), fs = require('fs');

http.createServer(function (request, response) {
    var filename = __dirname + '/site' + request.url;

    if (filename.lastIndexOf('.') === -1) {
        if (filename.charAt(filename.length - 1) !== '/') {
            filename += '/';
        }
        filename += 'index.html';
    }

    fs.exists(filename, function (exists) {
        if (exists) {
            fs.readFile(filename, function (err, data) {
                if (err) {
                    response.writeHead(500);
                    response.end();
                } else {
                    var ext = filename.substring(filename.lastIndexOf('.') + 1);
                    response.writeHead(200, {
                        'Content-Length': data.length,
                        'Content-Type': 'text/' + (ext === 'txt' ? 'plain' : ext)
                    });
                    response.end(data, 'utf-8');
                }
            });
        } else {
            response.writeHead(404);
            response.end();
        }
    });
}).listen(process.env.PORT || 5000);
