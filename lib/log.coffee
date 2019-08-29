debug = atom.config.get('gitlab-manager.debug')
module.exports = (args...) ->
  console.log.apply(null, ['[gitlab-manager]'].concat(args)) if debug
