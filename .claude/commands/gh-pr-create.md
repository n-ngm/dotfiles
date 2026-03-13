---
allowed-tools: Bash(git branch:*), Bash(git status:*), Bash(git diff:*), Bash(git add:*)
description: Create a GitHub Pull Request with guided workflow
---

# GitHub PR Creation Workflow

You are helping the user create a GitHub Pull Request. Follow these steps:

## Step 1: Get PR Title
Ask the user for the PR title.
Suggest your recommendation based on the changes detected in the working directory.

## Step 2: Check and Update Branch
1. Check the current branch name
2. If on the initial branch (main/master), create a new branch based on the PR title
   - format: <prefix>/<short-description>
   - prefix: Choose from feature, bugfix, hotfix, docs
   - short-description: Convert the title
   - available characters: lowercase alphanumeric and hyphens for spaces, remove special chars
   - max length: should 50 characters

## Step 3: Stage Files Interactively
If target files are not specified:

1. Show all unstaged files with numbers
2. Ask the user to select files to add (by numbers, comma-separated)
3. If no, skip to next step
4. Run `git add` for selected files

else add the specified files directly.

## Step 4: Create Commit
1. Create a commit following Conventional Commits 1.0.0 format, and summarize in one line.
2. Use the user's guidance if provided
3. Generate an appropriate commit message based on changes

## Step 5: Repeat Staging (if needed)
1. Check if there are still unstaged files
2. Ask if the user wants to continue adding files
3. If yes, repeat steps 3-4
4. If no, proceed to PR creation

## Step 6: Create Pull Request
1. Find PR template in this priority order:
   - `../.github/pull_request_template.md`
   - `.github/pull_request_template.md`
   - `$REPO_ROOT/.github/pull_request_template.md`
   - `https://raw.githubusercontent.com/HotStartup/.github/refs/heads/main/pull_request_template.md`
2. Fill out the template sections appropriately
   - Write test cases using Markdown checklist
3. Create PR using `gh pr create` with the filled template
4. Show the PR URL to the user

Execute this workflow step by step, guiding the user through the process.
