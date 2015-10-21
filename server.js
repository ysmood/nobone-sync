// Watch and sync a local folder with a remote one.
// All the local operations will be repeated on the remote.
//
// This this the remote server.

var cs, http, kit, localPath;

kit = require('nokit');

cs = kit.require('brush');

http = require('http');

localPath = function(path) {
  if (process.platform === 'win32') {
    return path.replace(/\//g, '\\');
  } else {
    return path.replace(/\\/g, '\/');
  }
};

module.exports = function(conf) {
  var decodeInfo, service;
  kit._.defaults(conf, require('./config.default'));
  decodeInfo = function(str) {
    return JSON.parse(conf.password ? kit.decrypt(new Buffer(str, 'hex'), conf.password, conf.algorithm) : decodeURIComponent(str));
  };
  service = http.createServer(function(req, res) {
    var absPath, absRoot, data, err, getStream, httpError, mode, p, path, pipeToFile, ref, reqStream, type;
    httpError = function(code, err) {
      kit.err((err != null ? err.stack : void 0) || err);
      res.statusCode = code;
      return res.end(http.STATUS_CODES[code]);
    };
    try {
      ref = decodeInfo(req.url.slice(1)), type = ref.type, path = ref.path, mode = ref.mode;
    } catch (_error) {
      err = _error;
      return httpError(400, err);
    }
    path = localPath(path);
    if (conf.rootAllowed) {
      absPath = kit.path.normalize(kit.path.resolve(path));
      absRoot = kit.path.normalize(kit.path.resolve(conf.rootAllowed));
      if (absPath.indexOf(absRoot) !== 0) {
        return httpError(403, err);
      }
    }
    kit.log(cs.grey("[server] ") + cs.cyan(type) + ': ' + path);
    p = kit.Promise.resolve();
    reqStream = null;
    getStream = function() {
      var crypto, decipher;
      if (conf.password) {
        crypto = kit.require('crypto', __dirname);
        decipher = crypto.createDecipher(conf.algorithm, conf.password);
        return req.pipe(decipher);
      } else {
        return req;
      }
    };
    pipeToFile = function() {
      reqStream = getStream();
      return kit.mkdirs(kit.path.dirname(path)).then(function() {
        var f;
        f = kit.createWriteStream(path, {
          mode: mode
        });
        f.on('error', function(err) {
          return p = kit.Promise.reject(err);
        });
        return new kit.Promise(function(resolve) {
          return reqStream.pipe(f).on('finish', function() {
            return resolve();
          });
        });
      });
    };
    switch (type) {
      case 'create':
        if (path.slice(-1) === kit.path.sep) {
          p = kit.mkdirs(path);
        } else {
          p = pipeToFile();
        }
        break;
      case 'modify':
        p = pipeToFile();
    }
    if (!reqStream) {
      data = new Buffer(0);
      req.on('data', function(chunk) {
        return data = Buffer.concat([data, chunk]);
      });
    }
    req.on('error', function(err) {
      return p = kit.Promise.reject(err);
    });
    return req.on('end', function() {
      var child_process, oldPath, tmpFile;
      oldPath = null;
      switch (type) {
        case 'create':
        case 'modify':
          null;
          break;
        case 'move':
          if (conf.password && data.length > 0) {
            data = kit.decrypt(data, conf.password, conf.algorithm);
          }
          oldPath = localPath(data.toString());
          p = kit.move(oldPath, path.replace(/\/+$/, ''));
          break;
        case 'delete':
          p = kit.remove(path);
          break;
        case 'execute':
          child_process = kit.require('child_process', __dirname);
          if (conf.password && data.length > 0) {
            data = kit.decrypt(data, conf.password, conf.algorithm);
          }
          tmpFile = __dirname + '/tmp/' + Date.now() + Math.random() + (path || '.js');
          kit.outputFile(tmpFile, data).then(function() {
            var cipher, crypto, proc;
            proc = child_process.fork(tmpFile, {
              silent: true
            });
            res.on('error', function() {
              return proc.kill('SIGINT');
            });
            proc.on('close', function() {
              var ref1;
              kit.remove(tmpFile);
              return (ref1 = conf.onChange) != null ? ref1.call(0, type, path) : void 0;
            });
            if (conf.password) {
              crypto = kit.require('crypto', __dirname);
              cipher = crypto.createCipher(conf.algorithm, conf.password);
              proc.on('close', function() {
                return res.end(cipher.final());
              });
              proc.stdout.on('data', function(c) {
                return res.write(cipher.update(c));
              });
              return proc.stderr.on('data', function(c) {
                return res.write(cipher.update(c));
              });
            } else {
              proc.on('close', function() {
                return res.end();
              });
              proc.stdout.on('data', function(c) {
                return res.write(c);
              });
              return proc.stderr.on('data', function(c) {
                return res.write(c);
              });
            }
          });
          return;
        default:
          return httpError(404, new Error('Unknown Change Type'));
      }
      return p.then(function() {
        var ref1;
        return kit.Promise.resolve((ref1 = conf.onChange) != null ? ref1.call(0, type, path, oldPath, mode) : void 0);
      }).then(function() {
        return res.end();
      })["catch"](function(err) {
        return httpError(500, err);
      });
    });
  });
  return service.listen(conf.port, function() {
    return kit.log(cs.cyan("Listen: ") + conf.port);
  });
};
