request = require 'request-promise-native'
requestBare = require 'request'
log = require './log'
fs = require 'fs'
opn = require 'opn'
unzipper = require 'unzipper'
path = require 'path'
class GitlabStatus
  constructor: (@view, @timeout=null, @projects={}, @pending=[], @jobs={}, @pipelineID=null) ->
    @token = atom.config.get('gitlab-manager.token')
    @period = atom.config.get('gitlab-manager.period')
    @unsecureSsl = atom.config.get('gitlab-manager.unsecureSsl')
    @userID = atom.config.get('gitlab-manager.userID')
    if @userID == 0
      atom.notifications.addError("User ID not set", {
        detail : "Gitlab user ID must be set for the plugin to work properly.",
        dismissable: true
      })
    if not not  atom.config.get('gitlab-manager.savingPath')
      @savingPath = atom.config.get('gitlab-manager.savingPath')
    else
      @savingPath =""
    @updating = {}
    @watchTimeout = null
    if atom.config.get('gitlab-manager.http')
      @protocol = 'http'
    else
      @protocol = 'https'

  updateSavingPath: (savingPath) ->
    if not atom.config.get('gitlab-manager.savingPath')
      @savingPath = savingPath

  onProjectChange: (project) =>
    @currentProject = project

  retrieveCurrentProject: =>
    return @currentProject

  fetch: (host, q, paging=false) ->
    log " -> fetch '#{q}' from '#{host}'"
    @get("#{@protocol}://#{host}/api/v4/#{q}").then((res) =>
      log " <- ", res
      if res.headers['x-next-page']
        if paging
          log " -> retrieving #{res.headers['x-total-pages']} pages"
          Promise.all(
            [res.body].concat(
              new Array(
                parseInt(res.headers['x-total-pages']) - 1,
              ).fill(0).map(
                (dum, i) =>
                  log " -> page #{i + 2}"
                  @get(
                    "#{@protocol}://#{host}/api/v4/#{q}" +
                    (if q.includes('?') then '&' else '?') +
                    "per_page=" + res.headers['x-per-page'] +
                    "&page=#{i+2}"
                  ).then((page) =>
                    log "     <- page #{i + 2}", page
                    page.body
                  ).catch((error) =>
                    console.error "cannot fetch page #{i + 2}", error
                    Promise.resolve([])
                  )
              )
            )
          ).then((all) =>
            Promise.resolve(all.reduce(
              (all, one) =>
                all.concat(one)
              , [])
            )
          )
        else
          log " -> ignoring paged output for #{q}"
          res.body
      else
        res.body
    )

  get: (url) =>
    request({
      method: 'GET',
      uri: url,
      headers: {
        "PRIVATE-TOKEN": @token,
      },
      resolveWithFullResponse: true,
      json: true,
      agentOptions: {
        rejectUnauthorized: @unsecureSsl is false,
      }
    }).catch((error) =>
      Promise.reject(error)
    )
  downloadAndUnzip: (url, filename) =>
    if not @savingPath
      atom.notifications.addError("Couldn't download artifacts", {
        detail : "Couldn't download the job artifacts #{filename}, because the path for saving was empty. Either open a file in a pane with a valid location or set a default value.",
        dismissable: true
      })
      return
    `let req = requestBare.defaults({
         headers: {
             'PRIVATE-TOKEN': this.token,
      }
      });
      req(url)
          .pipe(unzipper.Extract({ path: this.savingPath + path.sep + filename}))
          .on('finish', () => {
              atom.notifications.addSuccess("Successfully downloaded the artifact.", {
                detail : "Successfully downloaded the artifacts to: " + this.savingPath + path.sep + filename
              });
          })
          .on('error', error => {
              atom.notifications.addError("Error downloading the archive!", {
                detail : "Error downloading the archive. The error was: " + error.stack
                  });
          });
          `
    return

  post: (url) =>
    request({
      method: 'POST',
      uri: url,
      headers: {
        "PRIVATE-TOKEN": @token,
      },
      resolveWithFullResponse: true,
      json: true,
      agentOptions: {
        rejectUnauthorized: @unsecureSsl is false,
      }
    }).catch((error) =>
      Promise.reject(error)
    )

  update: ->
    @pending = Object.keys(@projects).slice()
    @updatePipelines()

  retryJob: (project, jobId) ->
    { host, project, repos } = @projects[project]
    log "#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/retry"
    @post("#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/retry").then((res) ->
      atom.notifications.addSuccess("Successfully retried the job.", {
        detail : "Successfully retried the job #{jobId}. A new job should have been triggered",
      })
      log " <- ", res
      res.body
    ).catch((error) =>
      atom.notifications.addError("Failed retrying the job.", {
        detail : "Failed at retrying the job #{jobId}. detail: #{error.stack}"
      })
      Promise.reject(error)
    )
  cancelJob: (project, jobId) ->
    { host, project, repos } = @projects[project]
    log "#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/cancel"
    @post("#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/cancel").then((res) ->
      log " <- ", res
      res.body
    ).catch((error) =>
      atom.notifications.addError("Failed cancelling the job.", {
        detail : "Failed at cancelling the job #{jobId}. detail: #{error.stack}"
      })
      Promise.reject(error)
    )

  retrieveMergeRequestsSelf: ->
    if not @projects[@currentProject]?
      log "projects was not loaded", @projects
      return Promise.reject()
    { host, project, repos } = @projects[@currentProject]
    log "#{@protocol}://#{host}/api/v4/merge_requests?state=opened&scope=assigned_to_me"
    @get("#{@protocol}://#{host}/api/v4/merge_requests?state=opened&scope=assigned_to_me").then((res) ->
      log " <- ", res
      res.body
    ).catch((error) =>
      atom.notifications.addError("Failed retrieving the MR.", {
        detail : "Failed retrieving the MR. Detail: #{error.stack}"
      })
      Promise.reject(error)
    )
  retrieveMergeRequestsApprover: ->
    if not @projects[@currentProject]?
      log "projects was not loaded", @projects
      return Promise.reject()
    { host, project, repos } = @projects[@currentProject]
    log "#{@protocol}://#{host}/api/v4/merge_requests?state=opened&approver_ids\[1\]=#{@userID}"
    @get("#{@protocol}://#{host}/api/v4/merge_requests?state=opened&approver_ids\[1\]=#{@userID}").then((res) ->
      log " <- ", res
      res.body
    ).catch((error) =>
      atom.notifications.addError("Failed retrieving the MR.", {
        detail : "Failed retrieving the MR. Detail: #{error.stack}"
      })
      Promise.reject(error)
    )

  retrieveIssuesSelf: ->
    if not @projects[@currentProject]?
      log "projects was not loaded", @projects
      return Promise.reject()
    { host, project, repos } = @projects[@currentProject]
    log "#{@protocol}://#{host}/api/v4/issues?state=opened&scope=assigned_to_me"
    @get("#{@protocol}://#{host}/api/v4/issues?state=opened&scope=assigned_to_me").then((res) ->
      log " <- ", res
      res.body
    ).catch((error) =>
      atom.notifications.addError("Failed retrieving the MR.", {
        detail : "Failed retrieving the MR. Detail: #{error.stack}"
      })
      Promise.reject(error)
    )

  downloadJobArtifacts: (project, jobId, filename) ->
    { host, project, repos } = @projects[project]
    log "#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/artifacts"
    @downloadAndUnzip("#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/artifacts", filename)

  playJob: (project, jobId) ->
    { host, project, repos } = @projects[project]
    log "#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/play"
    @post("#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/play").then((res) ->
      log " <- ", res
      res.body
    ).catch((error) =>
      atom.notifications.addError("Failed at playing the job.", {
        detail : "Failed at at playing the job #{jobId}. detail: #{error.stack}"
      })
      Promise.reject(error)
    )

  traceJob: (project, jobId) ->
    { host, project, repos } = @projects[project]
    log "#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/trace"
    @get("#{@protocol}://#{host}/api/v4/projects/#{project.id}/jobs/#{jobId}/trace").then((res) ->
      log " <- trace job promise", res
      res.body
    ).catch((error) =>
      atom.notifications.addError("Failed cancelling the job.", {
        detail : "Failed at receiving trace of the job #{jobId}. detail: #{error.stack}"
      })
      Promise.reject(error)
    )

  gotoBrowserNewMergeRequestCurrentBranch: (projectRepo) ->
    log "Open new MR in Browser", projectRepo, @projects
    if not @projects[projectRepo]
      alert("test")
      return
    { host, project, repos } = @projects[projectRepo]
    currentBranch = repos?.getShortHead?()
    log "try to open  the following #{@protocol}://#{host}/#{projectRepo}/merge_requests/new?utf8=%E2%9C%93&merge_request%5Bsource_project_id%5D=#{project.id}&merge_request%5Bsource_branch%5D=#{currentBranch}&merge_request%5Btarget_project_id%5D=#{project.id}&merge_request%5Btarget_branch%5D=#{project.default_branch}"
    opn("#{@protocol}://#{host}/#{projectRepo}/merge_requests/new?utf8=%E2%9C%93&merge_request%5Bsource_project_id%5D=#{project.id}&merge_request%5Bsource_branch%5D=#{currentBranch}&merge_request%5Btarget_project_id%5D=#{project.id}&merge_request%5Btarget_branch%5D=#{project.default_branch}").catch (error) ->
      atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
      console.error error
    return

  gotoOpenIssues: (projectRepo) ->
    if not @projects[projectRepo]
      log "projects was not loaded", @projects
      return
    { host, project, repos } = @projects[projectRepo]
    log "try to open  the following #{@protocol}://#{host}/#{projectRepo}/issues"
    opn("#{@protocol}://#{host}/#{projectRepo}/issues").catch (error) ->
      atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
      console.error error

  gotoCompareToMaster: (projectRepo) ->
    if not @projects[projectRepo]
      log "projects was not loaded", @projects
      return
    { host, project, repos } = @projects[projectRepo]
    ref = repos?.getShortHead?()
    log "try to open  the following #{@protocol}://#{host}/#{projectRepo}/compare/#{project.default_branch}...#{ref}"
    opn("#{@protocol}://#{host}/#{projectRepo}/compare/#{project.default_branch}...#{ref}").catch (error) ->
      atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
      console.error error

  gotoRepositoryBranchFiles: (projectRepo) ->
    if not @projects[projectRepo]
      log "projects was not loaded", @projects
      return
    { host, project, repos } = @projects[projectRepo]
    ref = repos?.getShortHead?()
    log "try to open  the following #{@protocol}://#{host}/#{projectRepo}/tree/#{ref}"
    opn("#{@protocol}://#{host}/#{projectRepo}/tree/#{ref}").catch (error) ->
      atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
      console.error error

  gotoBrowserPath: (path) ->
    { host, project, repos } = @projects[@currentProject]
    ref = repos?.getShortHead?()
    log "try to open  the following #{@protocol}://#{host}/#{path}"
    opn("#{@protocol}://#{host}/#{path}").catch (error) ->
      atom.notifications.addError error.toString(), detail: error.stack or '', dismissable: true
      console.error error

  watch: (host, projectPath, repos) ->
    projectPath = projectPath.toLowerCase()
    if not @projects[projectPath]? and not @updating[projectPath]?
      @updating[projectPath] = false
      @view.loading projectPath, "loading project..."
      @fetch(host, "projects?membership=yes", true).then(
        (projects) =>
          projects = projects.map(
            (project) =>
              project.path_with_namespace = project.path_with_namespace.toLowerCase()
              project
          )
          log "received projects from #{host}", projects
          if projects?
            project = projects.filter(
              (project) =>
                project.path_with_namespace is projectPath
            )[0]
            if project?
              @projects[projectPath] = { host, project, repos }
              @update()
            else
              @view.unknown(projectPath)
          else
            @view.unknown(projectPath)
      ).catch((error) =>
        @updating[projectPath] = undefined
        console.error "cannot fetch projects from #{host}", error
        @view.unknown(projectPath)
      )

  schedule: ->
    if @period?
      @timeout = setTimeout @update.bind(@), @period


  updatePipelines: ->
    Object.keys(@projects).map(
      (projectPath) =>
        { host, project, repos } = @projects[projectPath]
        if project? and project.id? and not @updating[projectPath]
          @updating[projectPath] = true
          try
            ref = repos?.getShortHead?()
          catch error
            console.error "cannot get project #{projectPath} ref", error
            delete @projects[projectPath]
            return Promise.resolve(@endUpdate(projectPath))
          if ref?
            log "project #{project} ref is #{ref}"
            ref = "?ref=#{ref}"
          else
            ref = ""
          if not @jobs[projectPath]?
            @view.loading(projectPath, "loading pipelines...")
          @fetch(host, "projects/#{project.id}/pipelines#{ref}").then(
            (pipelines) =>
              log "received pipelines from #{host}/#{project.id}", pipelines
              if pipelines.length > 0
                @updateJobs(host, project, pipelines[0])
                @pipelineID = pipelines[0].id
              else
                @onJobs(project, [])
          ).catch((error) =>
            console.error "cannot fetch pipelines for project #{projectPath}", error
            Promise.resolve(@endUpdate(projectPath))
          )
    )

  endUpdate: (project) ->
    @updating[project] = false
    @pending = @pending.filter((pending) => pending isnt project)
    if @pending.length is 0
      @view.onStagesUpdate(@jobs)
      @schedule()
    @jobs[project]

  updateJobs: (host, project, pipeline) ->
    if not @jobs[project.path_with_namespace]?
      @view.loading(project.path_with_namespace, "loading jobs...")
    @fetch(host, "projects/#{project.id}/" + "pipelines/#{pipeline.id}/jobs", true)
    .then((jobs) =>
      log "received jobs from #{host}/#{project.id}/#{pipeline.id}", jobs
      if jobs.length is 0
        @onJobs(project, [
          name: pipeline.name
          status: pipeline.status
          jobs: []
        ])
      else
        @onJobs(project, jobs.sort((a, b) -> a.id - b.id).reduce(
          (stages, job) ->
            stage = stages.find(
              (stage) -> stage.name is job.stage
            )
            if not stage?
              stage =
                name: job.stage
                status: 'success'
                jobs: []
              stages = stages.concat([stage])
            stage.jobs = stage.jobs.concat([job])
            return stages
        , []).map((stage) ->
          Object.assign(stage, {
            status: stage.jobs
              .sort((a, b) -> b.id - a.id)
              .reduce((status, job) ->
                switch
                  when job.status is 'pending' then 'pending'
                  when job.status is 'created' then 'created'
                  when job.status is 'canceled' then 'canceled'
                  when job.status is 'running' then 'running'
                  when job.status is 'skipped' then 'skipped'
                  when job.status is 'failed' and
                    status is 'success' then 'success'
                  else status
              , 'success')
          })
        ))
    ).catch((error) =>
      console.error "cannot fetch jobs for pipeline ##{pipeline.id} of project #{project.path_with_namespace}", error
      Promise.resolve(@endUpdate(project.path_with_namespace))
    )

  onJobs: (project, stages) ->
    @jobs[project.path_with_namespace] = stages.slice()
    @endUpdate(project.path_with_namespace)
    Promise.resolve(stages)
  testDeleteMeLater: ->
    log "YEAY GITLAB"
  stop: ->
    if @timeout?
      clearTimeout @timeout
    if @watchTimeout?
      clearTimeout @watchTimeout
    @view.hide()

  deactivate: ->
    @stop()

module.exports = GitlabStatus
