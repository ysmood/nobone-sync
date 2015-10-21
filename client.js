// Watch and sync a local folder with a remote one.
// All the local operations will be repeated on the remote.
//
// This this the local watcher.

var cs, isDir, kit, send;

kit = require('nokit');

cs = kit.require('brush');

isDir = function(path) {
  return path.slice(-1) === kit.path.sep;
};

module.exports = function(conf, watch) {
  var push, watchHandler;
  if (watch == null) {
    watch = true;
  }
  kit._.defaults(conf, require('./config.default'));
  process.env.pollingWatch = conf.pollingInterval;
  watchHandler = function(type, path, oldPath, stats) {
    if (stats.isDirectory())
      path = path + kit.path.sep;

    var remotePath;
    kit.log(cs.cyan(type) + ': ' + path + (oldPath ? cs.cyan(' <- ') + oldPath : ''));
    remotePath = kit.path.join(conf.remoteDir, conf._useFilename ? kit.path.basename(path) : kit.path.relative(conf.localDir, path), isDir(path) ? '/' : '');
    return send({
      conf: conf,
      path: path,
      type: type,
      remotePath: remotePath,
      oldPath: oldPath,
      stats: stats
    }).then(function() {
      var ref;
      return (ref = conf.onChange) != null ? ref.call(0, type, path, oldPath, stats) : void 0;
    })["catch"](function(err) {
      return kit.log(cs.red(err.stack));
    });
  };
  push = function(path, stats) {
    return watchHandler('create', path, null, stats);
  };
  if (watch) {
    return kit.watchDir(conf.localDir, {
      patterns: conf.pattern,
      handler: watchHandler
    }).then(function(list) {
      return kit.log(cs.cyan('Watched: ') + kit._.keys(list).length);
    })["catch"](function(err) {
      return kit.log(cs.red(err.stack));
    });
  } else {
    conf.glob = conf.localDir;
    return kit.lstat(conf.localDir).then(function(stat) {
      if (stat.isDirectory()) {
        if (kit._.isString(conf.pattern)) {
          conf.pattern = [conf.pattern];
        }
        return conf.glob = conf.pattern.map(function(p) {
          if (p[0] === '!') {
            return '!' + kit.path.join(conf.localDir, p.slice(1));
          } else {
            return kit.path.join(conf.localDir, p);
          }
        });
      } else {
        return conf._useFilename = true;
      }
    }, function(err) {
      conf._useFilename = true;
      return kit.Promise.resolve(err);
    }).then(function() {
      return kit.glob(conf.glob, {
        all: true,
        iter: function(info) {
          if (!info.isDir) {
            return push(info.path, info.stats);
          }
        }
      });
    });
  }
};


/**
 * Send single request.
 * @param  {Object} opts Defaults:
 * ```js
 * { conf, path, type, remotePath, oldPath, stats }
 * ```
 * @return {Promise}
 */

module.exports.send = send = function(opts) {
  var PassThrough, cipher, conf, crypto, data, encodeInfo, operationInfo, p, rdata;
  conf = opts.conf;
  if (opts.isPipeToStdout == null) {
    opts.isPipeToStdout = true;
  }
  encodeInfo = function(info) {
    var str;
    str = kit._.isString(info) ? info : JSON.stringify(info);
    if (conf.password) {
      return kit.encrypt(str, conf.password, conf.algorithm).toString('hex');
    } else {
      return encodeURIComponent(str);
    }
  };
  operationInfo = {
    type: opts.type,
    path: opts.remotePath
  };
  rdata = {
    url: "http://" + conf.host + ":" + conf.port + "/",
    method: 'POST',
    body: false
  };
  p = kit.Promise.resolve();
  switch (opts.type) {
    case 'create':
    case 'modify':
      if (!isDir(opts.path)) {
        if (opts.stats) {
          operationInfo.mode = opts.stats.mode;
        }
        rdata.reqPipe = kit.createReadStream(opts.path);
        crypto = kit.require('crypto', __dirname);
        if (conf.password) {
          cipher = crypto.createCipher('aes128', conf.password);
          rdata.reqPipe = rdata.reqPipe.pipe(cipher);
        }
      }
      break;
    case 'move':
      rdata.reqData = kit.path.join(conf.remoteDir, opts.oldPath.replace(conf.localDir, '').replace('/', ''));
      if (conf.password) {
        rdata.reqData = kit.encrypt(rdata.reqData, conf.password, conf.algorithm);
      }
      break;
    case 'execute':
      if (conf.password) {
        rdata.reqData = kit.encrypt(opts.source, conf.password, conf.algorithm);
        crypto = kit.require('crypto', __dirname);
        rdata.resPipe = crypto.createDecipher(conf.algorithm, conf.password);
        if (opts.isPipeToStdout) {
          rdata.resPipe.pipe(process.stdout);
        }
      } else {
        PassThrough = kit.require('stream', __dirname).PassThrough;
        rdata.reqData = opts.source;
        rdata.resPipe = new PassThrough;
      }
      data = new Buffer(0);
      rdata.resPipe.on('data', function(chunk) {
        if (!conf.password) {
          process.stdout.write(chunk);
        }
        return data = Buffer.concat([data, chunk]);
      });
      rdata.url += encodeInfo(operationInfo);
      return kit.request(rdata).then(function() {
        return data;
      });
  }
  return p = p.then(function() {
    rdata.url += encodeInfo(operationInfo);
    return kit.request(rdata);
  }).then(function(res) {
    if (res.statusCode === 200) {
      return kit.log(cs.green('Synced: ') + opts.path);
    } else {
      return kit.log(res.body);
    }
  });
};
