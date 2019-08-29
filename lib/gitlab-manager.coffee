{CompositeDisposable, File, Directory, TextEditor} = require 'atom'
path = require 'path'
GitUrlParse = require 'git-url-parse'
StatusBarView = require './status-bar-view'
BottomJobsView = require './bottom-jobs-view'
GitlabRepositoryView = require './gitlab-repository-view'
GitlabStatus = require './gitlab'
log = require './log'
opn = require 'opn'

class GitlabIntegration
  config:
    token:
      title: 'Gitlab API token'
      description: 'Mandatory: Token to access your Gitlab API'
      type: 'string'
      default: ''
    userID:
      title: 'Gitlab userID'
      description: 'Mandatory: Your user ID which fits the access token. You can retrieve it at https://%YOUR_GITLAB_HOST%/profile'
      type: 'integer'
      minimum: 0
      default: 0
    period:
      title: 'Polling period (ms)'
      description: 'The interval at which gitlab will be polled'
      minimum: 1000
      default: 5000
      type: 'integer'
    unsecureSsl:
      title: 'Disable SSL certificate check'
      description: 'In case your Gitlab server is using a self-signed certificate, enable this option to allow plugin to work'
      type: 'boolean'
      default: false
    debug:
      title: 'Enable debug output in console'
      type: 'boolean'
      default: false
    http:
      title: 'Enable HTTP'
      description: 'In case your Gitlab server does not support HTTPs, enable this option to use HTTP instead of HTTPs (highly unrecommended).'
      type: 'boolean'
      default: false
    savingPath:
      title: 'Download Location'
      description: 'The folder which you want to download the job artifacts to.  E.g. "C:\\tmp". If not path is set, the currently active\'s pane path will be used.'
      type: 'string'
      default: ''

  constructor: () ->
    @URI = 'atom://gitlab-manager/lib/gitlab-repository-view.coffee'
    @disposables = new CompositeDisposable
  consumeStatusBar: (statusBar) ->
    @statusBar = statusBar
    @statusBarView.onDisplay =>
      @statusBarTile = @statusBar.addRightTile
        item: @statusBarView, priority: -1
    @statusBarView.onDispose =>
      @statusBarTile.destroy()

  onPathChange: ->
    currentPane = atom.workspace.getActivePaneItem()
    if currentPane instanceof TextEditor
      currentPath = currentPane?.getPath?()
      if currentPath?
        [ currentProject, _ ] =
          atom.project.relativizePath(currentPath)
        @gitlab.updateSavingPath(atom.project.relativizePath(currentPath)[0])
      else
        currentProject = undefined
      log "-- path change"
      log "    - current:", @currentProject
      log "    - new:", currentProject
      log "    - projects:", @projects
      log "    - current path:", currentPath
      if currentProject isnt @currentProject
        log "     -> project changed to", @projects[currentProject]
        if @projects[currentProject]?
          if @projects[currentProject] isnt "<unknown>"
            @statusBarView.onProjectChange(
              @projects[currentProject]
            )
            @gitlab.onProjectChange(
              @projects[currentProject]
            )
          else
            @statusBarView.onProjectChange(null)
            @statusBarView.unknown(currentProject)
        else
          if not currentProject? and currentPath?
            project = new File(currentPath).getParent()
            currentProject = project.getPath()
            if not @projects[currentProject]?
              atom.project.repositoryForDirectory(project)
                .then((repos) =>
                  @handleRepository(project, repos, true)
                )
            else
              @statusBarView.onProjectChange(
                @projects[currentProject]
              )
              @gitlab.onProjectChange(
                @projects[currentProject]
              )
        @currentProject = currentProject

  handleRepository: (project, repos, setCurrent) ->
    origin = repos?.getOriginURL()
    log "--- handle repository"
    log "     - project:", project
    log "     - repos:", repos
    log "     - current:", setCurrent
    log "     - projects:", @projects
    if origin?
      log "     - origin:", origin
      url = GitUrlParse(origin)
      log "     - url:", url
      if url?
        projectName = url.pathname
          .slice(1).replace(/\.git$/, '').toLowerCase()
        log "     - name:", projectName
        @projects[project.getPath()] = projectName
        sshProto = (
          url.protocols.length is 0 and url.protocol is "ssh"
        ) or "ssh" in url.protocols
        if url.port? and not sshProto
          host = "#{url.resource}:#{url.port}"
        else
          host = url.resource
        @gitlab.watch(host, projectName, repos).then () =>
          if @gitlabRepositoryView? and not @gitlabRepositoryView.getSuccessOnce()
            @gitlabRepositoryView.recreateView()
        if setCurrent?
          @statusBarView.onProjectChange(projectName)
          @gitlab.onProjectChange(
            projectName
          )

      else
        @projects[project.getPath()] = "<unknown>"
    else
      @projects[project.getPath()] = "<unknown>"

  handleProjects: (projects) ->
    Promise.all(
      projects.map(
        (project) =>
          atom.project.repositoryForDirectory(project).then(
            (repos) =>
              @handleRepository(project, repos)
              Promise.resolve()
          )
      )
    ).then(=>
      if @projects[@currentProject] is "<unknown>"
        @statusBarView.unknown(@currentProject)
      else
        @statusBarView.onProjectChange(@projects[@currentProject])
        @gitlab.onProjectChange(@projects[@currentProject])
    )

  activate: (state) =>
    @subscriptions = new CompositeDisposable
    @statusBarView = new StatusBarView
    @statusBarView.init(if state.isBottomJobsVisible? then state.isBottomJobsVisible else false)
    @gitlab = new GitlabStatus @statusBarView
    if @gitlabRepositoryView?
      @gitlabRepositoryView.init(@gitlab)
    @statusBarView.addGitlab(@gitlab)
    @projects = {}
    if not atom.config.get('gitlab-manager.token')
      atom.notifications.addInfo(
        "You likely forgot to configure your gitlab token",
        {dismissable: true}
      )
    @handleProjects(atom.project.getDirectories())
    @subscriptions.add atom.project.onDidChangePaths (paths) =>
      @handleProjects(paths.map((path) => new Directory(path)))
    atom.workspace.observeActivePaneItem (editor) =>
      if editor instanceof TextEditor
        @onPathChange()
        @subscriptions.add editor.onDidChangePath =>
          @onPathChange
    # add all the hotkeys
    @subscriptions.add(atom.commands.add('atom-workspace', {
      'gitlab-manager:browser-create-new-merge-request': => @gotoBrowserNewMergeRequestCurrentBranch()
    }))
    @subscriptions.add(atom.commands.add('atom-workspace', {
      'gitlab-manager:browser-open-open-issues': => @gotoOpenIssues()
    }))
    @subscriptions.add(atom.commands.add('atom-workspace', {
      'gitlab-manager:browser-compare-to-master': => @gotoCompareToMaster()
    }))
    @subscriptions.add(atom.commands.add('atom-workspace', {
      'gitlab-manager:toggle-dock': => @toggleRepositoryView()
    }))
    @subscriptions.add(atom.workspace.addOpener( (uri) =>
      if uri == this.URI
        return @deserializeRepositoryView()
    ))


  deserializeRepositoryView: () =>
    if @gitlabRepositoryView?
      this.gitlabRepositoryView.deactivate()
      this.gitlabRepositoryView = null
    this.gitlabRepositoryView = new GitlabRepositoryView
    if @gitlab?
      @gitlabRepositoryView.init(@gitlab)
      if @gitlab.retrieveCurrentProject()?
        @gitlabRepositoryView.recreateView()
    return this.gitlabRepositoryView

  serialize: ->
    return
      deserializer: 'gitlab-manager/tobiasGitlabIntegration'
      isBottomJobsVisible: @statusBarView.isBottomJobsVisible()

  gotoBrowserNewMergeRequestCurrentBranch: ->
    @gitlab.gotoBrowserNewMergeRequestCurrentBranch(@projects[@currentProject])
    return
  gotoOpenIssues: ->
    @gitlab.gotoOpenIssues(@projects[@currentProject])
    return
  gotoCompareToMaster: ->
    @gitlab.gotoCompareToMaster(@projects[@currentProject])
    return
  toggleRepositoryView: ->
    atom.workspace.toggle(@URI)

  deactivate: ->
    @subscriptions.dispose()
    @gitlab?.deactivate()
    if @statusBarView?
      @statusBarView.deactivate()
    @statusBarTile?.destroy()

module.exports = new GitlabIntegration
