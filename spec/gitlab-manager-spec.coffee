nock = require 'nock'

describe 'GitLab Integration', ->
  integration = null
  project = null
  beforeEach ->
    project =
      getPath: -> '/some/project'
    integration = require '../lib/gitlab-manager'
    integration.gitlab =
      jasmine.createSpyObj 'gitlab', [
        'watch',
      ]
    integration.view = jasmine.createSpyObj 'view', [
      'onProjectChange',
    ]
    integration.projects = {}

  it 'correctly handles Git URL', ->
    repos =
      getOriginURL: -> 'git@some-url.com:some/project'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com', 'some/project', repos)

    repos =
      getOriginURL: -> 'git@some-url.com:some/project.git'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com', 'some/project', repos)

  it 'correctly handles HTTP URL', ->
    repos =
      getOriginURL: -> 'http://some-url.com/some/project'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com', 'some/project', repos)

    repos =
      getOriginURL: -> 'https://some-url.com/some/project.git'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com', 'some/project', repos)

    repos =
      getOriginURL: -> 'https://test@some-url.com/some/project.git'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com', 'some/project', repos)

  it 'correctly handles non-standard port', ->
    repos =
      getOriginURL: -> 'ssh://git@some-url.com:1234/some/project'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com', 'some/project', repos)

    repos =
      getOriginURL: -> 'http://some-url.com:1234/some/project.git'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com:1234', 'some/project', repos)

    repos =
      getOriginURL: -> 'https://test@some-url.com:1234/some/project.git'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('some/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com:1234', 'some/project', repos)

  it 'correctly ignores case for projects name', ->
    repos =
      getOriginURL: -> 'git@some-url.com:SenSiTiVe/ProJecT'

    integration.handleRepository project, repos

    expect(integration.projects['/some/project'])
      .toBe('sensitive/project')
    expect(integration.gitlab.watch)
      .toHaveBeenCalledWith('some-url.com', 'sensitive/project', repos)
