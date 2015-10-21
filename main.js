
var app, cliConf, cmder, conf, configFile, cs, err, kit, port, remote;

kit = require('nokit');

cs = kit.require('colors/safe');

cmder = require('commander');

cmder.option('-h, --help', 'Help', function() {
  return cmder.help();
});

cmder.option('-s, --server');

cmder.option('-u, --upload [localFile host[:port]/path/to/dir]', 'Upload file or directory to remote host.');

cmder.option('-p, --password <pwd>', 'Password.');

cmder.option('-a, --algorithm <alg>', 'Algorithm', 'aes128');

cmder.option('-v, --ver', 'Print version', function() {
  console.log((require('./package.json')).version);
  return process.exit();
});

cmder.parse(process.argv);

cliConf = {};

configFile = cmder.args[1] || cmder.args[0];

if (cmder.upload) {
  if (cmder.upload === true) {
    configFile = cmder.args[0];
  } else {
    cliConf.localDir = cmder.upload;
    remote = null;
    kit._.find(cmder.args, function(arg, index) {
      remote = /([^\/:]+)(:\d+)?\/(.*)/.exec(arg);
      if (remote) {
        cmder.args.splice(index, 1);
      }
      return remote;
    });
    if (remote) {
      if (!remote[3]) {
        kit.err('Wrong argument, host[:port]/path/to/file wanted.');
        process.exit(1);
      }
      cliConf.host = remote[1] || '';
      port = remote[2] || ':8345';
      cliConf.port = port.slice(1);
      cliConf.remoteDir = "/" + remote[3];
    }
    configFile = cmder.args[0];
  }
}

cmder.password && (cliConf.password = cmder.password);

cmder.algorithm && (cliConf.algorithm = cmder.algorithm);

try {
  require('coffee-script/register');
  conf = require(kit.path.resolve(configFile));
} catch (_error) {
  err = _error;
  if (cmder.args.length > 0) {
    kit.err(err.stack);
    process.exit(1);
  } else {
    kit.log(cs.yellow('No config specified, use default.'));
    conf = {};
  }
}

kit._.extend(conf, cliConf);

if (cmder.server) {
  app = require('./server');
} else {
  app = require('./client');
}

app(conf, !cmder.upload);
