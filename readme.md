```shell
# Start a remote file server.
nobone sync -s

# Start a local client to push change to remote server.
nobone sync config.coffee
```

The defaults of `config.coffee` is:

```coffeescript
module.exports =
    local_dir: 'local_dir'
    remote_dir: 'remote_dir'
    host: '127.0.0.1:8345'
```