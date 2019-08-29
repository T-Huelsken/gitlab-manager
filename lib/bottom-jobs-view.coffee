{CompositeDisposable, File, Directory, TextEditor} = require 'atom'
log = require './log'
path = require 'path'

class BottomJobsView extends HTMLElement
  init: ->
    @classList.add('bottom-jobs-gitlab')
    @activate()
    @currentProject = null
    @stages = {}
    @statuses = {}
    @tooltips = []
    @subscriptions = new CompositeDisposable()

  activate: => @displayed = false
  deactivate: =>
    #@hidePane()
    @panel?.destroy()
    alert "deact is called"
    @subscriptions?.dispose()
    @disposeTooltips()
    @dispose() if @displayed

  onDisplay: (@display) ->
    if @displayed
      @display(@)

  addGitlab: (@gitlab) =>

  setPanel: (panel) ->
    @panel = panel
    @subscriptions.add(@panel.onDidChangeVisible( (visible) =>
      if visible
        @showPane()
      else
        @hidePane()
    ))
    return

  showPane: ->
    @panel.show()
    return
  hidePane: ->
    @panel.hide()
    return

  isVisible: ->
    return @panel.isVisible()

  loading: =>
    log "Started loading the bottom jobs view"
    status = document.createElement('div')
    status.classList.add('inline-block')
    icon = document.createElement('span')
    icon.classList.add('icon', 'icon-gitlab')
    status.classList.add("general-view")
    @addCloseButton()
    message = document.createElement('div')
    message.textContent = 'Currently there is no pipeline status available.'
    message.classList.add("floating")
    status.appendChild icon
    status.appendChild message
    @appendChild(status)


  updateAllStagesView: (project, stages) ->
    log "update all stages of bottom jobs for project and stages", project, stages
    tempOffset = 0
    if document.getElementById('stageDiv')?
      tempOffset = document.getElementById('stageDiv').scrollTop
    @removeAllChildren()
    @addCloseButton()
    stageDiv = document.createElement('div')
    stages.forEach((stage) =>
      toAdd = @createSingleStageDiv(project, stage)
      toAdd.classList.add("multiple-jobs")
      stageDiv.appendChild toAdd
      )
    stageDiv.classList.add("general-view")
    stageDiv.id = "stageDiv"
    @appendChild(stageDiv)
    document.getElementById('stageDiv').scrollTop = tempOffset

  updateStageView: (project, stage) ->
    if document.getElementById('stageDiv')?
      tempOffset = document.getElementById('stageDiv').scrollTop
    @removeAllChildren()
    @addCloseButton()
    stageDiv = document.createElement('div')
    stageDiv.appendChild @createSingleStageDiv(project, stage)
    stageDiv.classList.add("general-view")
    stageDiv.id = "stageDiv"
    @appendChild(stageDiv)
    document.getElementById('stageDiv').scrollTop = tempOffset

  createSingleStageDiv: (project, stage) =>
    log "create a single stage view from stage", stage
    @currentVisibleProject = project
    tableDiv = document.createElement('div')
    tableDiv.classList.add("tableMain")
    currentStageName = document.createElement('div')
    currentStageName.textContent = "Stage: #{stage.name}"
    currentStageName.classList.add("stage-headline")
    tableDiv.appendChild currentStageName
    stage.jobs.forEach((job) =>
      jobDiv = document.createElement('div')
      jobActions = document.createElement('div')
      jobActions.classList.add("floating")
      jobName = document.createElement('div')
      jobName.textContent = "#{job.name}"
      jobName.classList.add("floating")
      jobName.classList.add("name")
      jobName.classList.add("tableCell")
      jobDiv.appendChild jobName
      jobDiv.classList.add("stage-job")
      e = document.createElement('span')
      e.classList.add("floating")
      jobActions.appendChild (e)
      jobActions.classList.add("tableCell")
      jobActions.classList.add("job-actions")
      switch
        when job.status is 'success'
          e.classList.add('icon', 'gitlab-success')
          jobActions.appendChild (@traceButton(project, job.id))
          jobActions.appendChild (@repeatButton(project, job.id))
        when job.status is 'failed'
          e.classList.add('icon', 'gitlab-failed')
          jobActions.appendChild (@traceButton(project, job.id))
          jobActions.appendChild (@retryButton(project, job.id))
        when job.status is 'running'
          e.classList.add('icon', 'gitlab-running')
          jobActions.appendChild (@traceButton(project, job.id))
          jobActions.appendChild (@cancelButton(project, job.id))
          jobActions.appendChild (@retryButton(project, job.id))
        when job.status is 'pending'
          e.classList.add('icon', 'gitlab-pending')
          jobActions.appendChild (@cancelButton(project, job.id))
          jobActions.appendChild (@repeatButton(project, job.id))
        when job.status is 'skipped'
          e.classList.add('icon', 'gitlab-skipped')
          jobActions.appendChild (@playButton(project, job.id))
        when job.status is 'canceled'
          e.classList.add('icon', 'gitlab-canceled')
          jobActions.appendChild (@traceButton(project, job.id))
          jobActions.appendChild (@repeatButton(project, job.id))
        when job.status is 'created'
          e.classList.add('icon', 'gitlab-created')
          jobActions.appendChild (@repeatButton(project, job.id))
        when job.status is 'manual'
          e.classList.add('icon', 'gitlab-manual')
          jobActions.appendChild (@playButton(project, job.id))
      if job.artifacts_file?
        jobActions.appendChild (@downloadButton(project, job.id))
      @tooltips.push atom.tooltips.add e, {
        title: "#{job.name}: #{job.status}"
      }
      jobDiv.appendChild jobActions

      tableDiv.appendChild jobDiv
    )
    return tableDiv

  traceButton: (project, id) =>
    trace = document.createElement('span')
    trace.classList.add('icon', 'gitlab-doc-text')
    trace.classList.add("floating")
    @tooltips.push atom.tooltips.add trace, {
      title: "Retrieve the job logs"
    }
    trace.onclick = =>
      trace = @gitlab.traceJob(project, id).then (result) =>
        atom.workspace.open("Job-#{id}.ansi").then =>
          editors = atom.workspace.getTextEditors()
          for editor in editors
            if "Job-#{id}.ansi" == editor.getTitle()
              # this regex is needed since gitlab and runners often cause problems with different
              # line feedings like only \r
              editor.setText(result.replace(/\r?\n/g, "\r\n").replace(/\r\n?/g, "\r\n"))
      .catch((error) =>
        console.error "couldn't fullfill promise", error
      )
    return trace

  downloadButton: (project, id) =>
    button = document.createElement('span')
    button.classList.add('icon', 'gitlab-download')
    button.classList.add("floating")
    @tooltips.push atom.tooltips.add button, {
      title: "Download the job artifacts and unzip them. - In progress but mostly working"
    }
    button.onclick = =>
      @gitlab.downloadJobArtifacts(project, id, "job-download-" +id)
    return button

  retryButton: (project, id) =>
    retry = document.createElement('span')
    retry.classList.add('icon', 'gitlab-retry')
    retry.classList.add("floating")
    @tooltips.push atom.tooltips.add retry, {
      title: "Retry the job"
    }
    retry.onclick = =>
      @gitlab.retryJob(project, id)
    return retry

  repeatButton: (project, id) =>
    repeat = document.createElement('span')
    repeat.classList.add('icon', 'gitlab-repeat')
    repeat.classList.add("floating")
    @tooltips.push atom.tooltips.add repeat, {
      title: "Repeat the job"
    }
    repeat.onclick = =>
      @gitlab.retryJob(project, id)
    return repeat

  cancelButton: (project, id) =>
    repeat = document.createElement('span')
    repeat.classList.add('icon', 'gitlab-cancel')
    repeat.classList.add("floating")
    @tooltips.push atom.tooltips.add repeat, {
      title: "Cancel the job"
    }
    repeat.onclick = =>
      @gitlab.cancelJob(project, id)
    return repeat

  playButton: (project, id) =>
    play = document.createElement('span')
    play.classList.add('icon', 'gitlab-play')
    play.classList.add("floating")
    @tooltips.push atom.tooltips.add play, {
      title: "Start the job the manually"
    }
    play.onclick = =>
      @gitlab.playJob(project, id)
    return play

  addCloseButton: ->
    log "closeButtonWill be appended"
    closeButton = document.createElement('span')
    closeButton.classList.add('icon', 'icon-close')
    closeButton.onclick = =>
      @hidePane()
    @appendChild closeButton

  removeAllChildren: =>
    if @children.length > 0
      while @hasChildNodes()
        log "currentChildren", @children[0]
        @removeChild @children[0]

module.exports = document.registerElement 'bottom-jobs-gitlab',
  prototype: BottomJobsView.prototype, extends: 'div'
