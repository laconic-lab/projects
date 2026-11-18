# Cross-Platform Command Execution and Logging Safety Standard

**Scope:** Commands and scripts for Linux, Linux Mint, Arch Linux, Windows PowerShell, WSL, VMs and containers.

**Purpose:** Ensure generated commands have a bounded lifecycle, logs cannot grow without supervision, failures remain visible, and the user retains control of the machine.

## 1. Mandatory principles

1. **Diagnose first.** Prefer read-only inspection before modifications. State where commands run and what they do.
2. **Bound execution.** Every command must have a clear completion condition and a reasonable expected duration. Explain genuinely long-running or interactive work.
3. **Bound output.** Every report must have a reasonable expected size. Avoid unlimited streams, unbounded loops and excessive verbose output.
4. **Foreground by default.** Do not detach loggers, watchers, jobs or services unless explicitly required, monitored and given a stop procedure.
5. **No silent writers.** Do not leave a process writing to a report after the script claims completion. Account for child processes and inherited output handles.
6. **Preserve terminal access.** Interactive programs and TUIs must retain their terminal. Do not pipe their terminal output through a logger if that breaks interaction.
7. **Protect existing data.** Never overwrite, truncate, rotate, delete or clean up existing reports without explicit approval and a verified preservation plan.
8. **Fail visibly.** Preserve command exit codes and errors. A logging wrapper must not hide the operation's failure.
9. **Least privilege.** Use administrator/root privileges only when necessary and explain why.
10. **Recovery first.** For consequential changes, explain the rollback path and verify backups before proceeding.
11. **No speculative emergency actions.** Do not stop display managers, reboot, kill broad process groups, repair filesystems or uninstall software merely to simplify diagnosis.
12. **User control.** Do not introduce unattended startup, scheduled jobs, persistent services or background monitoring without approval.

## 2. Incident analysis: unsafe asynchronous logging

Two Linux Mint btop scripts used the same construction:

~~~bash
exec > >(tee -a "$REPORT") 2>&1
~~~

This redirects the shell's standard output and standard error through Bash process substitution. The tee process is started asynchronously. File descriptors can be inherited by child processes; process-substitution lifecycle and exit-status handling are not equivalent to a simple foreground pipeline.

The scripts did not explicitly manage or verify the logger's lifetime. They also lacked a report-size limit and a post-completion check that the report had stopped changing.

**Evidence boundary:** this construction is unsafe as a default report-logging design and is prohibited in generated scripts. However, the script text alone does not prove that an orphaned tee process caused the observed growth. The exact writer was not identified before reboot. The two reports were approximately 3.1 MB, had the same last-modification timestamp in the post-reboot inventory, and stopped growing after reboot. These facts are consistent with a lingering writer but do not conclusively identify one.

There was no obvious intentional infinite loop in either supplied script. The established design failure was inadequate control and verification of the logging lifecycle. Do not describe a suspected process as a proven root cause.

### Prohibited routine pattern

Do not use asynchronous process substitution as the default logging wrapper:

~~~bash
exec > >(tee -a "$REPORT") 2>&1
~~~

Do not assume set -e, set -u or set -o pipefail makes asynchronous logging synchronous or guarantees that the logger has stopped.

## 3. Safer logging patterns

These examples are patterns, not permission to run unreviewed commands. Adapt them to the actual shell and task.

### 3.1 Bash: foreground pipeline for finite scripts

~~~bash
#!/usr/bin/env bash
set -Eeuo pipefail

REPORT="$HOME/Desktop/$(date +%Y%m%d_%H%M%S)_results_for_issue.txt"

if [[ -e "$REPORT" ]]; then
    echo "Refusing to overwrite existing report: $REPORT" >&2
    exit 1
fi

{
    echo "Started: $(date --iso-8601=seconds)"
    # Perform bounded, reviewed operations here.
    echo "Completed: $(date --iso-8601=seconds)"
} 2>&1 | tee "$REPORT"
~~~

A foreground pipeline keeps the logger attached to the script's execution. With pipefail, a failure in the grouped commands is reflected in the pipeline status. Do not append "|| true" to conceal failures.

This pattern is not sufficient if the script starts background jobs, daemons, watchers or detached commands. Explicitly manage those processes and their output handles. Prefer not to start them from an audit script.

### 3.2 Bash: output and time limits

- Prefer finite commands and bounded queries.
- Use head, tail, journal time ranges and line-count limits when inspecting logs.
- Do not use journalctl -f, tail -f, watch, endless loops or continuous monitors in a report-producing audit unless the user explicitly requests a live session.
- For commands that may hang, use a suitable timeout after checking the platform's implementation. Explain what may be terminated and what partial output remains.
- Prefer a unique report filename. Do not append to an unknown existing report.

### 3.3 Windows PowerShell: explicit transcript lifecycle

~~~powershell
$Report = Join-Path $HOME ("Desktop\{0}_results_for_issue.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$TranscriptStarted = $false

try {
    if (Test-Path -LiteralPath $Report) {
        throw "Refusing to overwrite existing report: $Report"
    }

    Start-Transcript -LiteralPath $Report -ErrorAction Stop | Out-Null
    $TranscriptStarted = $true

    Write-Output "Started: $(Get-Date -Format o)"
    # Perform bounded, reviewed operations here.
    Write-Output "Completed: $(Get-Date -Format o)"
}
finally {
    if ($TranscriptStarted) {
        Stop-Transcript | Out-Null
    }
}
~~~

A PowerShell transcript records PowerShell session output. It is not a universal capture mechanism for every GUI application or every native process. For native executables, handle stdout and stderr deliberately, wait for the process, capture its exit code, and avoid detached processes that inherit output handles.

### 3.4 Other shells and environments

Do not copy Bash syntax into PowerShell or assume Linux process/file-descriptor behaviour applies on Windows. Use the native logging and process-control mechanism for the actual shell. The invariant is the same: a defined logger lifecycle, bounded output, accounted-for child processes and verified completion.

## 4. Required preflight before providing commands

The assistant must check:

- [ ] Correct execution environment and shell: host, container, VM, WSL, PowerShell, etc.
- [ ] Target paths and current state are known or safely checked.
- [ ] Existing files will not be overwritten unintentionally.
- [ ] Report naming avoids collisions.
- [ ] Logging is foreground and lifecycle-managed.
- [ ] Output is bounded by time, line count, size or a clear completion condition.
- [ ] No accidental continuous stream, polling loop or background writer exists.
- [ ] Interactive applications retain terminal access.
- [ ] Child processes are waited for or explicitly managed.
- [ ] Exit codes and errors remain visible.
- [ ] Elevated privileges and destructive effects are explained.
- [ ] The user has a clear safe stop procedure.
- [ ] Changes have a backup and rollback plan where appropriate.

If any item cannot be satisfied, explain the limitation and choose a safer alternative. Do not trade lifecycle safety for a shorter script.

## 5. Report-file safety

- Use timestamped names, for example YYYYMMDD_HHMMSS_results_for_issue.txt.
- Refuse to overwrite an existing report. Do not silently truncate it.
- Do not log passwords, tokens, private keys, session cookies or sensitive personal data.
- Avoid dumping entire journals, recursive trees, binary data or huge environment listings.
- Estimate or cap potentially large output before writing it.
- On completion, report the path, size, exit status and completion time.
- Where practical, verify that report size remains stable after the writer exits. Keep this verification bounded and do not create another uncontrolled logger.
- Do not automatically delete or truncate a report when something goes wrong. Preserve evidence unless the user authorizes cleanup.

## 6. Interactive applications and TUIs

Programs such as btop, editors, pagers, installers and interactive shells need direct terminal access.

For an interactive test:
1. Keep the application attached to the terminal.
2. Log only bounded setup metadata before launch.
3. Launch the application in the foreground.
4. Let the user exit it normally.
5. Capture its exit status after it returns.
6. Collect only bounded, relevant post-run logs.
7. Verify that no process started by the test remains unexpectedly.

Do not pipe an interactive TUI's standard output through tee as a substitute for an application log.

## 7. Emergency response when a report grows unexpectedly

1. Stop launching new scripts and editors against the affected report.
2. Do not delete, truncate, rename or rotate the file.
3. Preserve the current desktop/session if it remains usable.
4. Identify the exact process holding the file open using an appropriate, bounded, read-only process/file-descriptor inspection.
5. Inspect its command, parent, elapsed time and open descriptors before stopping anything.
6. Stop only the confirmed unwanted writer, using the least disruptive signal and a targeted PID.
7. Verify that the file size has stopped changing.
8. Check filesystem free space and system health.
9. Preserve the report and relevant process evidence.
10. Reboot only if the system is genuinely unresponsive or the writer cannot be safely controlled. A reboot may stop a writer but destroys valuable live process evidence.

**Do not stop the display manager as a generic logging emergency measure.** That terminates the graphical session and can prevent the user from continuing work or accessing the chat needed for guidance. A TTY is an alternative only when the graphical session is already unusable and the user can operate it.

## 8. Responsibilities of an AI assistant

- State what each command does and where it runs.
- Separate read-only inspection from changes.
- Keep scripts as short as the task permits, without sacrificing process/logging safety.
- Remember that read-only commands can still exhaust storage or destabilize applications through uncontrolled output.
- Do not assume a writer has stopped because its visible parent shell exited.
- Do not claim a root cause without evidence.
- If a previous command causes unexpected behaviour, stop the workflow, acknowledge it, analyze the actual command and revise the approach before continuing.
- Never ask the user to run a large diagnostic script during an active emergency.
- Never repeat a failed or suspect command unchanged.

## 9. Reusable instruction for future ChatGPT sessions

Copy and paste this instruction whenever requesting shell commands or scripts:

~~~text
Before generating any Bash, Linux shell, or Windows PowerShell commands, follow the Cross-Platform Command Execution and Logging Safety Standard:
https://github.com/laconic-lab/projects/blob/main/memory/CROSS-PLATFORM-COMMAND-EXECUTION-AND-LOGGING-SAFETY-STANDARD.md

This standard is mandatory:
- Diagnose first; prefer read-only checks before changes.
- Use bounded commands and bounded report output.
- Never use asynchronous Bash process substitution such as exec > >(tee ...) for report logging.
- Keep logging in the foreground with a defined lifecycle; account for child/background processes.
- Preserve interactive terminal applications and TUIs.
- Never leave a report writer running after the script completes.
- Do not overwrite, truncate or delete existing reports without approval.
- Explain risks, scope, expected duration, stop procedure and rollback before consequential commands.
- For Bash commands, capture stdout and stderr in a timestamped Desktop report named:
  YYYYMMDD_HHMMSS_results_for_<issue>.txt
  Prefer showing output in the terminal while saving it safely.
- For PowerShell, use native PowerShell logging and explicit transcript/process cleanup.
- Do not assume Bash and PowerShell have the same process or logging behaviour.
- If safe bounded logging cannot be guaranteed, explain why and provide a safer alternative instead of generating the script.
~~~

## 10. Applicability

This standard applies to new chats and projects, regardless of whether the target is Linux Mint, Arch Linux, another Linux distribution, Windows PowerShell, a VM, WSL or a container.

Project-specific requirements and verified platform behaviour take precedence over generic examples, but no project may waive the core requirements for bounded execution, controlled logging, process lifecycle management, data preservation and explicit authorization.

**Objective:** Every command must finish predictably, every report must stop growing when its writer exits, and the user must never have to rely on an editor warning to discover uncontrolled output.
