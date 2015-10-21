var nokit;

nokit = require('nokit');

module.exports = function(task, option) {
  return task('test', function() {
    return require('./test/basic');
  });
};
