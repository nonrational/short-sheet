# ShortSheet

A REPL environment and Rake tasks to synchronize [Shortcut](https://shortcut.com/) and [Google Sheets](https://workspace.google.com/) to enhance Shortcut's capabilities and facilitate low-friction planning.

## Why Google Sheets?

This project provides customization and automation that sits on top of Shortcut to provide a more flexible and powerful planning experience. Google Sheets is familiar and flexible. A central "planning sheet" can then be a staging area to prioritize and organize initiatives before they're pushed into Shortcut.

![A screenshot of a Google Sheet with columns A-K, including Name (with initiative names blurred out), Doc, Shortcut, Owner, Urgency, Status, Begin, Target, Start, End. The 'Begin' and 'End' columns show values like 'Nov H1 '24' and 'Feb H2 '25' (iteration names) and the resulting Start/End calendar dates are shown in columns to the right. The Target column has the funnel icon highlighted, indicated that the column is filtered.](https://raw.githubusercontent.com/nonrational/short-sheet/refs/heads/main/static/annotated_google_sheet_screenshot.png)


### (1) Iteration-Bound Delivery

Rather than needing to think in target _dates_, we've found it helpful to think in target _iterations_. Our planning sheet automatically translates canonical iteration names with start/end dates, so we can plan talking about iterations, then push the resulting dates into Shortcut epics.

### (2) Story to Epic Evolution

When we consider a new initiative, it usually starts as a "Scoping" story in Shortcut. That story represents discovery and definition of the initiative. After scoping is complete, we'll make a go/no-go decision. If we decide not to proceed right now, having an Epic sitting in the hopper is confusing. So, the Sheet view allows us to prioritize Epics _alongside Stories_. The Sheet order can then be pushed into Shortcut.

### (3) Obvious Filtering

Using Google Sheet's column filtering criteria is more intuitive for those less familiar with Shortcut.

<div style="margin-bottom: 180px;"></div>

## Feature Summary

- REPL with ActiveRecord-esque models for interacting with Shortcut & Sheets
- Bi-directional sync between Shortcut Epics and Google Sheets
    - Name, Owner, Status, Start Date, Target Date, Summary Information (Participants, Remaining Stories, etc.)
- Creation of canonically named Bi-Monthly Iterations
- Creation of Monthly Chores epics, based on Google Sheet template
- Bulk creation of stories from CSV or Google Sheet
- [Prioritization of iteration stories](https://github.com/nonrational/short-sheet/blob/main/lib/tasks/iteration_ready_sort.rb#L34-L41) based on epic sort order, priority, product area, blocked status, due date, etc.
- Map & synchronize "Project" field to arbitrary Custom Field to support migrating away from Shortcut's Project field
- ~Automatically move all incomplete stories from the previous iteration to the current iteration~ Now supported natively in Shortcut. :tada:

## Automation

### Task Summary

```shell
$ rake -T

rake config:check                    # Check config is valid
rake config:export                   # Export the config.yml file as a base64 encoded string

rake monthly_chores:create_current   # Create the next monthly chores epic
rake monthly_chores:create_next      # Create the next monthly chores epic

rake planning:prioritize_shortcut    # Sort epics by sheet order and ready stories by priority
rake planning:review                 # Interactively review any out-of-sync initiatives and choose whether to update shortcut or the sheet
rake planning:update_sheet           # Fetch information from shortcut and update the sheet with it

rake shortcut:iteration:create_next  # Create the next iteration
rake shortcut:project_sync:run       # Ensure that all stories with a project have the correct product area set

```
### Scheduling

Once you've got everything configured in `config.yml`, run `rake config:export` to produce a base64'd version suitable to drop into ENV to trigger actions via GitHub Actions or another crotab-like provider.

## Development

```shell
asdf plugin add ruby
asdf install
gem install bundler
bundle
```

## Configuration

See `config.yml.example`

### Shortcut Credentials

Set `shortcut-api-token` in `config.yml` or `SHORTCUT_API_TOKEN` in `.env`.

### Google Workspace Credentials

1. Generate an OAuth2 Client at https://console.cloud.google.com/apis/credentials with the required scopes and permissions to access the Drive and Sheets APIs.
1. Download its JSON config to `client_secrets.json`.
1. Run `make serve` and visit http://localhost:4567 to fetch access and refresh tokens, saving them to `google_credentials.json`.
1. The refresh token will then automatically be used to refresh your credentials as necessary.

## Rake Completion via Homebrew

Tab completion for `rake` is really handy.

```sh
brew install bash bash-completion
curl -o "$(brew --prefix)/etc/bash_completion.d/rake" \
    "https://raw.githubusercontent.com/ai/rake-completion/e46866ebf5d2e0d5b8cb3f03bae6ff98f22a2899/rake"
```
