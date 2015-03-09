# nobone-sync

A simple remote file sync tool for development.

It's also a simple example of how [nokit](https://github.com/ysmood/nokit) works.

[![NPM version](https://badge.fury.io/js/nobone-sync.svg)](http://badge.fury.io/js/nobone-sync) [![Build Status](https://travis-ci.org/ysmood/nobone-sync.svg)](https://travis-ci.org/ysmood/nobone-sync) [![Deps Up to Date](https://david-dm.org/ysmood/nobone-sync.svg?style=flat)](https://david-dm.org/ysmood/nobone-sync)

## Install

Install globally:

    npm install -g nobone-sync

Install as lib dependency:

    npm install nobone-sync

## Usage

### As CLI Tool

Start a remote file server:

    nobone-sync -s

Start a local client to push change to remote server.

    nobone-sync config.coffee

The defaults of `config.coffee` is:

```coffee
module.exports =
    local_dir: 'local_dir'

    # On client, it decides the root path to upload to.
    # On server, it decides the root accessible path.
    remote_dir: 'remote_dir'

    host: '127.0.0.1'
    port: 8345
    pattern: '**'
    polling_interval: 500

    # If it is set, data will be encrypted with the algorithm.
    password: null
    algorithm: 'aes128'

    on_change: (type, path, old_path) ->
        # It can also return a promise.
        console.log('Write your custom code here')
```

The `pattern` can be a string or an array, it takes advantage of `minimatch`.

Some basic usages:

- To only watch `js`, `css` and `jpg`: `'**/*.@(js|css|jpg)'`
- To ignore `js` and `css` file: `['**', '!**/*.@(js|css)']`

Use larger polling_interval if there are too many files to be watched.

#### Push a Path to Remote

Push a file or directory to remote server

    nobone-sync -u local_path host[:port]/path/to/dir

> local_path can be a file, a directory, or a glob pattern(glob pattern should use with quotation marks).

For example:

    nobone-sync -u 'src/css/a.css' 1.2.3.4:8222/home/me/src/css

    nobone-sync -u 'src/js/*.js' 1.2.3.4:8222/home/me/src/js


### As Library

Example:

```coffee
client = require 'nobone-sync/client'
server = require 'nobone-sync/server'

conf = {
    local_dir: 'local_dir'
    remote_dir: 'remote_dir'
    host: '127.0.0.1'
    port: 8345
    pattern: '**'
    polling_interval: 500
    password: '123456'
    on_change: (type, path, old_path) ->
        console.log('Write your custom code here')
}

client conf
server conf
```

## Protocol

The transfer protocol is based on http.
Only the `{info}` and `{data}` is used.

### Format

```
POST /{info} HTTP/1.1

{data}
```

- `info`

  It's a URI encoded json string. For example, the json is

  `{ type: 'create', path: '/home/u/a/b.js', mode: 0o777 }`,

  then the final info string should be

  `%7B%22type%22%3A%22create%22%2C%22path%22%3A%22%2Fhome%2Fu%2Fa%2Fb.js%22%2C%22mode%22%3A511%7D`.

- `data`

  It's raw binary. When the `type` is `move`, it should the target remote path.
  When the `type` is `create` or `modify`, it should be binary file content. In other cases, it will be ignored.

- `error`

  If operation failed the server will return http status code 403, 404 or 500.


## FAQ

- Why not use Samba or sshfs?

  > If you search text content in a large project via Samba, it can be very slow.

- Why not svn, git?

  > Use scm is somehow slow, and deploy a general scm server on a development machine is not funny.

- Why not sftp?

  > It depends on ssh, for example, in Baidu, direct access to development machine via ssh is blocked.

- Why ftp?

  > At most times, the IDE plugins are not programmable. You cannot use it as a library and take advantage of file change event.
  >
  > This tool ignores what IDE your different team members are using, the config file can be source controled. They don't have to waste time to decide what plugins is best for the job.

- Why http, not tcp?

  > I want the custom sync protocol as simple as possible, the http header is just suit for the action and path part of my protocol. Performance is not the bottleneck.

- SSL?

  > I don't have any plan for it, for now simple symmetric cryto is enough for development. If you need it, please open an issue.
