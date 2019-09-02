# Atom gitlab-manager package

Control your gitlab pipelines/jobs and improve your overall workflow with gitlab.

![Fullview](https://user-images.githubusercontent.com/54643607/63933230-1a151480-ca59-11e9-8dee-64eb9c9c8686.png)

## Configuration

Mandatory:
- Set your Gitlab personal access token, which is needed to perform all the needed calls on your behalf. It must at least have the `API` scope. The documentation to creeate one is at https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html.
- Set your Gitlab user id. You will find this id at your User Profile -> Settings page.(https://gitlab.com/profile)

Optional:
- Set the polling period to your desired time. Since every project added in an atom window will be polled until the window is closed, it's recommended to not set this value to low to reduce network traffic/CPU utilization.
- Set the download location if you dont' want to download the artifacts into your project but to the specified folder instead.
- Disable the ssl certificate check if you are using a self hosted gitlab server with untrusted certificates.
- Enable HTTP to always use http, if the  server doesn't support https.

### Complementary plugins
- Display your job logs with proper colours instead of ansi escape sequences: https://atom.io/packages/language-ansi-styles
- Handling multiple different configurations (API token and user id) for different projects: https://atom.io/packages/atomic-management

## Usage
Once the plugin has been installed and you have filled in the mandatory information restart your atom to let the configuration take effect.   
If you now open a gitlab project using `Add project folder` (ctrl + shift + a) and open a file in it, the plugin will be triggered and started. Once a project has been opened and loaded in a window you can also open files of other projects to view their pipeline statuses.
It will add the Gitlab icon as well as one icon for every pipeline stage with it's current status. The displayed pipeline is always the last pipeline of the currently checked out branch. From there on you will have the following options:
- Click on a pipeline stage icon to open it's stage details.
- Click on the pipeline icon (rocket) to open all pipeline stages at once.
- Click on the gitlab icon to open the files tab of your current branch in your default browser.

When you have opened a pipeline stage, you can click the corresponding stage icon to close it again. In the detailed view you have full control over your pipeline jobs. You can start/retry/cancel jobs as well as you can view it's jobs logs inside of atom or download it's contents which then will be unzipped automatically.

Furthermore the following hotkeys are implemented:
- Open a dock with `alt-i`. The dock contains a list of open merge requests assigned to you, issues assigned to you and merge requests where you an approver. It's items are clickable and will redirect you to the corresponding item in your browser. This view is not refreshed automatically and thus has be refreshed using the displayed buttons.
- `ctrl-shift-m`: Create a new merge request on basis of your current branch. (opens Browser)
- `ctrl-shift-j`: Compares your current branch to the master. (opens Browser)
- `ctrl-shift-o`: Opens the projects open issues. (opens Browser)

## Current limitations
- Gitlab-Manager is incompatible with the plugin gitlab-integration, since gitlab-manager is a fork of it. Therefore you can only have one of them installed and active in atom. A restart after switching them might be required.
- The projects must be root level elements. It's not possible to add some kind of root repository which contains several gitlab-projects at once.
- Using multiple projects in one atom window might not always be working 100%. Additionally it's only supported for one gitlab host at once.
- Gitlab-Manager uses the remote with the name `origin` for retrieving the gitlab host information. Therefore the remote upstream must be set correctly.

## Plans for future
- Adding tests
- Adding more shortcuts or commands if requested
- Fixing some styles and improving the look and feel
- Adding new functionality (create MR in atom)
- Improve logging to be more useful
- Improve download job functionality to also handle artifacts which can't be unzipped
- Improve performance
- Refactoring of code

## Further Advice
This is only a minimal viable product without real testing or similar. it was hacked in the spare time of a couple of weeks. Since it's also my first frontend project I advice you to not have a closer look into the code if not needed. If you dare to do so no reparations will be paid in case of heart attacks, getting ventilated about it, consuming an uncommon big amount of chocolate or alike.

## Thanks
Thanks to blakawk whose implementation is the basis of this project. (https://atom.io/packages/gitlab-integration)

## Contributing
Reporting issues and pull requests are welcome for this project. In case of errors provide console debug output and the steps to reproduce the error. You can enable the debug output in the settings
