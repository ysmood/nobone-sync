## Install

Make sure you have nobone installed.

    npm i -g nobone-sync

## Usage

Start a remote file server:

    nobone sync -s

Start a local client to push change to remote server.

    nobone sync config.coffee

The defaults of `config.coffee` is:

```coffeescript
module.exports =
    local_dir: 'local_dir'
    remote_dir: 'remote_dir'
    host: '127.0.0.1'
    port: 8345
    pattern: '**'
```

Both the `local_dir` and `remote_dir` should be an absolute path.

The `pattern` can be a string or an array. The `pattern` should at least match all directories if you want to listen `create` and `move` operations. For example:

- To ignore `js` and `css` file: `'**/*.!(js|css)'`.
- To only watch `js`, `css` and `jpg`: `[**/*.+(js|css)', '**/*.jpg']`
