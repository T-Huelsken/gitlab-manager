{CompositeDisposable} = require('atom')
log = require './log'
opn = require 'opn'

class JobsView extends HTMLElement
  init: ->
    @classList.add('status-bar-gitlab-manager', 'inline-block')
    @activate()
    @currentProject = null
    @stages = {}
    @statuses = {}
    @tooltips = []

  activate: => @displayed = false
  deactivate: =>
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
    log "current project becomes #{project}"
    @currentProject = project
    if project?
      if @stages[project]?
        @update(project, @stages[project])
      else if @statuses[project]?
        @loading(project, @statuses[project])
      else
        @unknown(project)

  onStagesUpdate: (stages, pipelineID) =>
    @stages = stages
    if @stages[@currentProject]?
      @update(@currentProject, @stages[@currentProject], pipelineID)

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
      icon.classList
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

  update: (project, stages, pipelineID = "") =>
    log "updating stages of project #{project} with", stages
    @show()
    @disposeTooltips()
    status = document.createElement('div')
    status.classList.add('inline-block')
    icon = document.createElement('span')
    icon.onclick = ->
      if not not pipelineID
        log "Open the browser for gitlab with pipeline id #{pipelineID}"
        opn("https://gitlab.com/#{project}/pipelines/#{pipelineID}").catch (error) ->
          atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
          console.error error
      else
        log "Open the browser for gitlab"
        opn("https://gitlab.com/#{project}/pipelines").catch (error) ->
          atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
          console.error error
      return
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
      stages.forEach((stage) =>
        e = document.createElement('span')
        e.onclick = ->
          log "clicked"
          f = document.createElement('github-StatusBarTileController-tooltipMenu')
          e.appendChild f
          g = document.createElement('span')
          g.classList.add('icon', 'gitlab-skipped')
          e.appendChild g
          f.appendChild g
          log "test"
          return
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

module.exports = document.registerElement 'status-bar-gitlab-manager',
  prototype: StatusBarView.prototype, extends: 'div'
