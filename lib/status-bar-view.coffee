{CompositeDisposable} = require('atom')
log = require './log'
BottomJobsView = require './bottom-jobs-view'

class StatusBarView extends HTMLElement

  constructor: (props) ->
    super(props)
    @onClick = @onClick.bind(this)

  onClick: (e) =>
    this.props.onClick()

  init: (isBottomViewVisible)->
    @classList.add('status-bar-gitlab', 'inline-block')
    @activate()
    @currentProject = null
    @gitlab = null
    @stages = {}
    @statuses = {}
    @bottomJobsCurrentStage = {}
    @projectsMetaInfo = {}
    @tooltips = []
    @bottomJobsView = new BottomJobsView()
    @bottomJobsView.init()
    @bottomJobsPanel = atom.workspace.addBottomPanel(item: @bottomJobsView, visible: false)
    @bottomJobsView.loading()
    if isBottomViewVisible
      @bottomJobsPanel.show()
    else
      @bottomJobsPanel.hide()
    @bottomJobsView.setPanel(@bottomJobsPanel)

  isBottomJobsVisible: ->
    return @bottomJobsView.isVisible()

  addGitlab: (gitlab) =>
    @gitlab = gitlab
    @bottomJobsView.addGitlab(gitlab)

  activate: => @displayed = false
  deactivate: =>
    @bottomJobsView?deactivate()
    if @bottomJobsPanel?
      @bottomJobsPanel.destroy()
    @disposeTooltips()
    @dispose() if @displayed

  onDisplay: (@display) ->
    if @displayed
      @display(@)

  onDispose: (@dispose) ->

  hide: =>
    @dispose() if @displayed
    @displayed = false

  show: =>
    if @display?
      @display(@) if not @displayed
    @displayed = true

  onProjectChange: (project) =>
    log "current project becomes #{project}", project
    @currentProject = project
    if project?
      log "stages of the project are ", @stages
      if @stages[project]?
        @update(project, @stages[project])
      else if @statuses[project]?
        @loading(project, @statuses[project])
      else
        @unknown(project)

  onStagesUpdate: (stages) =>
    @stages = stages
    if @stages[@currentProject]?
      @update(@currentProject, @stages[@currentProject])

  disposeTooltips: =>
    @tooltips.forEach((tooltip) => tooltip.dispose())
    @tooltips = []

  loading: (project, message) =>
    log "project #{project} loading with status '#{message}'"
    @statuses[project] = message
    if @currentProject is project
      @show()
      @disposeTooltips()
      status = document.createElement('div')
      status.classList.add('inline-block')
      icon = document.createElement('span')
      icon.classList.add('icon', 'icon-gitlab')
      @tooltips.push atom.tooltips.add icon, {
        title: "GitLab project #{project}"
      }
      span = document.createElement('span')
      span.classList.add('icon', 'icon-sync', 'icon-loading')
      @tooltips.push atom.tooltips.add(span, {
        title: message,
      })
      status.appendChild icon
      status.appendChild span
      @setchild(status)

  setchild: (child) =>
    if @children.length > 0
      @replaceChild child, @children[0]
    else
      @appendChild child

  update: (project, stages) =>
    @show()
    @disposeTooltips()
    status = document.createElement('div')
    status.classList.add('inline-block')
    icon = document.createElement('span')
    icon.onclick = =>
      log "Open the browser for gitlab"
      @gitlab.gotoRepositoryBranchFiles(project)

    icon.classList.add('icon', 'icon-gitlab')
    @tooltips.push atom.tooltips.add icon, {
      title: "GitLab project #{project}"
    }
    status.appendChild icon
    if stages.length is 0
      e = document.createElement('span')
      e.classList.add('icon', 'icon-question')
      @tooltips.push atom.tooltips.add e, {
        title: "no pipeline found"
      }
      status.appendChild e
    else
      e = document.createElement('span')
      e.classList.add('icon', 'gitlab-rocket')
      if @bottomJobsView.isVisible() and not @bottomJobsCurrentStage[project]?
        @bottomJobsView.updateAllStagesView(project, stages)
      e.onclick = =>
        if @bottomJobsView.isVisible() and not @bottomJobsCurrentStage[project]?
          @bottomJobsView.hidePane()
        else
          delete @bottomJobsCurrentStage[project]
          @bottomJobsView.updateAllStagesView(project, stages)
          @bottomJobsView.showPane()

      status.appendChild e
      stages.forEach((stage) =>
        e = document.createElement('span')
        if @bottomJobsView.isVisible() and @bottomJobsCurrentStage[project]? and stage.name == @bottomJobsCurrentStage[project].stageName
          @bottomJobsView.updateStageView(project, stage)
        e.onclick = =>
          if @bottomJobsView.isVisible() && @bottomJobsCurrentStage[project]? && stage.name == @bottomJobsCurrentStage[project].stageName
            @bottomJobsView.hidePane()
            delete @bottomJobsCurrentStage[project]
          else
            @bottomJobsCurrentStage[project] = {stageName: stage.name}
            @bottomJobsView.updateStageView(project, stage)
            @bottomJobsView.showPane()
        switch
          when stage.status is 'success'
            e.classList.add('icon', 'gitlab-success')
          when stage.status is 'failed'
            e.classList.add('icon', 'gitlab-failed')
          when stage.status is 'running'
            e.classList.add('icon', 'gitlab-running')
          when stage.status is 'pending'
            e.classList.add('icon', 'gitlab-pending')
          when stage.status is 'skipped'
            e.classList.add('icon', 'gitlab-skipped')
          when stage.status is 'canceled'
            e.classList.add('icon', 'gitlab-canceled')
          when stage.status is 'created'
            e.classList.add('icon', 'gitlab-created')
          when stage.status is 'manual'
            e.classList.add('icon', 'gitlab-manual')
        @tooltips.push atom.tooltips.add e, {
          title: "#{stage.name}: #{stage.status}"
        }
        status.appendChild e
      )
    @setchild(status)

  unknown: (project) =>
    log "project #{project} is unknown"
    @statuses[project] = undefined
    if @currentProject is project
      @show()
      @disposeTooltips()
      status = document.createElement('div')
      status.classList.add('inline-block')
      span = document.createElement('span')
      span.classList.add('icon', 'icon-question')
      status.appendChild span
      @tooltips.push atom.tooltips.add(span, {
        title: "no GitLab project detected in #{project}"
      })
      @setchild(status)

module.exports = document.registerElement 'status-bar-gitlab',
  prototype: StatusBarView.prototype, extends: 'div'
