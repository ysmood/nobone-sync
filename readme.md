## Install

Make sure you have nobone installed.

    npm i -g nobone-sync

## Usage

### As CLI Tool

Push a file or directory to remote server
    
    nobone -p local_path host[:port] remote_dir

> local_path can be a file , a directory, or a glob pattern.

Start a remote file server:

    nobone sync -s

Start a local client to push change to remote server.

    nobone sync config.coffee

The defaults of `config.coffee` is:

```coffee
module.exports =
    local_dir: 'local_dir'
    remote_dir: 'remote_dir'
    host: '127.0.0.1'
    port: 8345
    pattern: '**'
    polling_interval: 500
    on_change: (type, path, old_path) ->
        console.log('Write your custom code here')
```

The `pattern` can be a string or an array, it takes advantage of `minimatch`.Some simple usages:

- To ignore `js` and `css` file: `'!**/*.@(js|css)'`.
- To only watch `js`, `css` and `jpg`: `[**/*.@(js|css)', '**/*.jpg']`

Use larger polling_interval if there are too many files to be watched.

### As Library

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
    on_change: (type, path, old_path) ->
        console.log('Write your custom code here')
}

client conf
server conf
```
