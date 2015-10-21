var nokit;

nokit = require('nokit');

module.exports = function(task, option) {
  task('default build', function() {
    nokit.require('drives');
    return nokit.warp('*.coffee').load(nokit.drives.auto('compile')).run();
  });
  return task('test', function() {
    return require('./test/basic');
  });
};
