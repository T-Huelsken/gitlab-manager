{CompositeDisposable} = require 'atom'
log = require './log'
opn = require 'opn'
class GitlabRepositoryView extends HTMLElement

  init: (@gitlab) =>
    @classList.add('gitlab-repository')
    @currentProject = null
    @tooltips = []
    @successOnce = false
    @subscriptions = new CompositeDisposable
    @deleted = false
    @loading()

  getURI: () => 'atom://gitlab-manager/lib/gitlab-repository-view.coffee'
  getDefaultLocation: () => 'right'
  getTitle: () => 'Gitlab tasks'

  getSuccessOnce: =>
    return @successOnce
  serialize: ->
    deserializer: 'gitlab-manager/tobiasGitlabRepository'
  getElement: () ->
    return this.element

  deactivate: =>
    @deleted = true
    @successOnce = false
    @subscriptions.dispose()
    @disposeTooltips()

  loading: =>
    @removeAllChildren()
    status = document.createElement('div')
    status.classList.add('inline-block')
    icon = document.createElement('span')
    icon.classList.add('icon', 'icon-gitlab')
    status.classList.add("general-view")
    message = document.createElement('div')
    message.textContent = 'Currently there is no information about MR/issues available.'
    message.classList.add("floating")
    status.appendChild icon
    status.appendChild message
    @appendChild(status)

  recreateView: =>
    @successOnce = true
    @removeAllChildren()
    @appendChild(@createCollapsibleHead("Merge requests assigned to you:", (contentContainer) => @addMergeRequestInformation contentContainer ))
    @appendChild(@createCollapsibleHead("Merge requests for you to approve:", (contentContainer) => @addMergeRequestApprover contentContainer ))
    @appendChild(@createCollapsibleHead("Issues assigned to you:", (contentContainer) => @addIssuesSelfInformation contentContainer ))


  createCollapsibleHead: (name, contentFunction) =>
    mainContainer = document.createElement('div')
    mainContainer.classList.add('main-container')
    headContainer = document.createElement('div')
    headContainer.classList.add('head-container')
    button = document.createElement('button')
    button.classList.add('collapsible1')
    button.textContent = name
    headContainer.appendChild button
    contentContainer = document.createElement('div')
    contentContainer.classList.add('content-collapsible')
    mainContainer.appendChild headContainer
    mainContainer.appendChild contentContainer
    retry = document.createElement('div')
    retry.classList.add('floating-right')
    icon = document.createElement('span')
    icon.classList.add('icon', 'gitlab-retry' )
    retry.appendChild icon
    headContainer.appendChild retry
    button.onclick = =>
      button.classList.toggle 'active'
      if contentContainer.style.maxHeight
        contentContainer.style.maxHeight = null
      else
        contentFunction contentContainer
    retry.onclick = =>
      contentContainer.style.maxHeight = null
      contentFunction contentContainer
    return mainContainer

  addMergeRequestInformation: (contentContainer) =>
    mergeObject = @gitlab.retrieveMergeRequestsSelf().then (result) =>
      @removeAllChildrenObjects(contentContainer)
      if result.length == 0
        notExisting = document.createElement('div')
        notExisting.textContent = 'Currently there is no open merge request assigned to you.'
        contentContainer.appendChild notExisting
      else
        result.forEach((mergeRequest) =>
          mrContainer = document.createElement('div')
          mrContainer.textContent = "#{mergeRequest.title}"
          mrContainer.classList.add('clickable-link')
          mrContainer.onclick = =>
            opn(mergeRequest.web_url).catch (error) ->
              atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
              console.error error
          contentContainer.appendChild mrContainer
        )
      contentContainer.style.maxHeight = contentContainer.scrollHeight + 'px'
    .catch((error) =>
      @removeAllChildrenObjects(contentContainer)
      console.error "couldn't fullfill promise", error
      notExisting = document.createElement('div')
      notExisting.textContent = 'Could not retrieve merge request assigned to you.'
      contentContainer.appendChild notExisting
      contentContainer.style.maxHeight = contentContainer.scrollHeight + 'px'
    )

  addMergeRequestApprover: (contentContainer) =>
    mergeObject = @gitlab.retrieveMergeRequestsApprover().then (result) =>
      @removeAllChildrenObjects(contentContainer)
      if result.length == 0
        notExisting = document.createElement('div')
        notExisting.textContent = 'Currently there is no open merge for you to approve.'
        contentContainer.appendChild notExisting
      else
        result.forEach((mergeRequest) =>
          mrContainer = document.createElement('div')
          mrContainer.textContent = "#{mergeRequest.title}"
          mrContainer.classList.add('clickable-link')
          mrContainer.onclick = =>
            opn(mergeRequest.web_url).catch (error) ->
              atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
              console.error error
          contentContainer.appendChild mrContainer
        )
      contentContainer.style.maxHeight = contentContainer.scrollHeight + 'px'
    .catch((error) =>
      @removeAllChildrenObjects(contentContainer)
      console.error "couldn't fullfill promise", error
      notExisting = document.createElement('div')
      notExisting.textContent = 'Could not retrieve merge request assigned to you for approval.'
      contentContainer.appendChild notExisting
      contentContainer.style.maxHeight = contentContainer.scrollHeight + 'px'
    )

  addIssuesSelfInformation: (contentContainer) =>
    mergeObject = @gitlab.retrieveIssuesSelf().then (result) =>
      @removeAllChildrenObjects(contentContainer)
      if result.length == 0
        notExisting = document.createElement('div')
        notExisting.textContent = 'Currently there is no open issue assigned to you.'
        contentContainer.appendChild notExisting
      else
        result.forEach((responseObject) =>
          issContainer = document.createElement('div')
          issContainer.textContent = "#{responseObject.title}"
          issContainer.classList.add('clickable-link')
          issContainer.onclick = =>
            opn(responseObject.web_url).catch (error) ->
              atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
              console.error error
          contentContainer.appendChild issContainer
        )
      contentContainer.style.maxHeight = contentContainer.scrollHeight + 'px'
    .catch((error) =>
      @removeAllChildrenObjects(contentContainer)
      console.error "couldn't fullfill promise", error
      notExisting = document.createElement('div')
      notExisting.textContent = 'Could not retrieve open issues assigned to you.'
      contentContainer.appendChild notExisting
      contentContainer.style.maxHeight = contentContainer.scrollHeight + 'px'
    )

  disposeTooltips: =>
    @tooltips.forEach((tooltip) => tooltip.dispose())
    @tooltips = []

  removeAllChildrenObjects: (container) =>
    if container.children.length > 0
      while container.hasChildNodes()
        log "currentChildren", container.children[0]
        container.removeChild container.children[0]

  removeAllChildren: =>
    if @children.length > 0
      while @hasChildNodes()
        log "currentChildren", @children[0]
        @removeChild @children[0]

module.exports = document.registerElement 'gitlab-repository',
  prototype: GitlabRepositoryView.prototype, extends: 'div'
