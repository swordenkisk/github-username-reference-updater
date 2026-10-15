# GitHub Username Reference Updater

A Bash script that searches your GitHub repositories for an old username, replaces matching occurrences in tracked text files, and lets you review each repository’s changes before committing and pushing.

## Requirements

- Bash
- Git
- Perl
- [GitHub CLI](https://cli.github.com/)
- GitHub CLI authenticated as the account with the new username

## Setup

1. Change the default `OLD_USERNAME` in `scripts/update-username.sh`, or set it when running the script.
2. Make the script executable:

   ```bash
   chmod +x scripts/update-username.sh
   ```

3. Authenticate with GitHub CLI:

   ```bash
   gh auth login
   ```

4. Rename your GitHub account first, then authenticate the GitHub CLI as the renamed account.

## Usage

Run the script:

```bash
./scripts/update-username.sh
```

Enter your new GitHub username when prompted. For each repository, the script will show the changes and ask you to type `PUSH` before committing and pushing them. Press Enter to leave the changes uncommitted for review.

You can override the old username and working directory with environment variables:

```bash
OLD_USERNAME=old-name WORKDIR="$HOME/repo-updates" \
  ./scripts/update-username.sh
```

## What it does

- Lists up to 1,000 repositories for the authenticated account.
- Clones repositories into the working directory, or fast-forward pulls existing clean clones.
- Searches tracked text files for the old username.
- Replaces matching occurrences.
- Shows a summary and asks for confirmation before committing and pushing.

## Safety notes

- The script checks that GitHub CLI is authenticated as the new username you enter.
- It skips existing repositories with uncommitted or untracked changes.
- Review every diff carefully before typing `PUSH`.
- Skipped changes remain in the local clone for review.
- A failed push leaves the local commit in place.
- The script updates repository contents; it does not change your GitHub account name, repository settings, or external services.

## Configuration and API keys

No `.env` file or third-party AI API keys are required. The script uses GitHub CLI for repository access and authentication.
