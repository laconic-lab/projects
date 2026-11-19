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

This redirects the current shell's standard output and standard error through Bash process substitution. The tee process is started asynchronously. Crucially, `exec` changes the file descriptors of the shell in which it runs; it does not restore them when a pasted command block or sequence of commands finishes. If this line is entered directly at an interactive prompt, that interactive shell remains redirected.

A second top-level redirection can create a chain. In a controlled reproduction using a child Bash shell, the first report received the marker emitted after the first redirection and also both markers emitted after the second redirection. The second report received only the markers emitted after the second redirection. This confirmed that the later tee's output was also flowing through the earlier tee. Subsequent interactive prompts and commands can therefore be appended to both reports.

### 2.1 Evidence and controlled reproduction: Linux Mint incident, 2026-11-18

Two Desktop reports associated with the btop 1.3.2 preflight and source-build work grew to approximately 3.1 MB each. Their tails contained the interactive shell prompt, later commands typed by the user, command output and terminal-control sequences. Both had the same last-modification timestamp in the post-reboot inventory. The files stopped growing after the user rebooted.

The original command blocks used the redirection above at top level. The original script files were not found on disk during the later investigation, but their contents had been supplied in the conversation. No obvious intentional infinite loop or continuously running writer was present in those finite operations.

A controlled Stage 2 test safely reproduced successive top-level redirections inside a disposable child Bash shell:
- Marker emitted after redirection 1 appeared once in report 1 and not in report 2.
- Markers emitted after redirection 2 appeared in both reports.
- The first report therefore contained the complete output stream; the second contained the later portion of that stream.

A Stage 3 test verified safer alternatives:
- A foreground grouped-command pipeline with `tee` recorded each test marker once.
- An `exec` redirection confined to a subshell wrote the child marker to its report but did not redirect the parent-shell marker into that report.
- The child marker also appeared in the outer test's foreground pipeline report, as expected, because that outer pipeline captured the entire test block.

**Conclusion and evidence boundary:** the strongest supported explanation is that the process-substitution `exec` statements were applied to the interactive Bash shell, leaving it redirected after the intended finite command blocks ended. The successive redirections then formed a tee chain, explaining why later interactive activity appeared in both original reports. The Stage 2 reproduction confirms the redirection-chain mechanism; the original report tails independently support that the interactive shell was affected. The original live process tree and file descriptors were not captured before reboot, so the exact original tee PIDs/topology and whether any additional inherited child process contributed to growth remain unverified. Do not claim that the original live process topology was recovered.

The incident was a logging-scope/lifecycle failure, not evidence of a btop infinite loop. The user also reported that a previous suggestion to stop the display manager removed access to the graphical session and chat; this was unnecessarily disruptive and must not be repeated as a generic logging response.

### Prohibited routine pattern

Do not use asynchronous process substitution as the default logging wrapper:

~~~bash
exec > >(tee -a "$REPORT") 2>&1
~~~

Do not assume set -e, set -u or set -o pipefail makes asynchronous logging synchronous or guarantees that the logger has stopped.

**Interactive-shell restriction:** never place a top-level `exec > >(tee ...)` logging redirection in a command block intended to be pasted directly into the user's interactive shell. It changes that shell's descriptors persistently. Prefer the foreground pipeline in §3.1. If a task genuinely requires `exec`, confine it to a dedicated script process or a subshell, and still manage/wait for child processes and verify completion. A subshell prevents the descriptor change from escaping to its parent; it does not by itself guarantee that asynchronous process-substitution children have completed or that their exit status is handled.

## 3. Safer logging patterns

These examples are patterns, not permission to run unreviewed commands. Adapt them to the actual shell and task.

### 3.1 Bash: foreground pipeline for finite, non-interactive scripts

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

**Scope restriction:** this pattern is for finite, non-interactive work only. It is not an acceptable wrapper for an interactive command merely because the pipeline is in the foreground. In particular, do not place an interactive command inside a grouped block whose output is piped to `tee`.

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
- [ ] Interactive applications retain terminal access and are not placed inside pipelines, logging wrappers or timeout wrappers that can interfere with terminal interaction, authentication or process lifecycle.
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

### 6.1 Absolute separation of interactive execution and report logging

Interactive commands must remain directly attached to the user's terminal. Do not embed them inside a shell pipeline, grouped logging pipeline, `tee` pipeline, command-substitution logging wrapper, asynchronous redirection, or timeout wrapper when that arrangement can interfere with normal terminal interaction, authentication, signals, or process lifecycle.

This rule explicitly includes, but is not limited to:
- `sudo apt install` and `sudo apt-get install`;
- package-manager upgrades, removals and configuration operations;
- commands that request a sudo or other interactive authentication password;
- installers and package-configuration dialogs;
- terminal user interfaces (TUIs);
- commands requiring interactive confirmation or user input.

**Mandatory execution model:**
1. Complete the read-only preflight and verify the exact intended operation.
2. Explain the operation, required privileges, risks, expected duration and safe interruption procedure before execution.
3. Run the interactive command directly in the user's terminal. Do not pipe it through `tee`, redirect its terminal streams to an asynchronous logger, or wrap it in `timeout`.
4. Allow the user to see and interact with the program normally, including authentication and package-configuration prompts.
5. Wait for the interactive process to terminate and capture its actual exit status directly.
6. Only after it has terminated, perform separate bounded, non-interactive verification and reporting, if authorized and appropriate.
7. Report the actual operation result. Never substitute the exit status of a surrounding shell group, logging process, or subsequent `echo` command for the interactive command's exit status.

A report requirement does not authorize changing the execution model of an interactive command. Logging must not take priority over terminal interaction. If safe logging cannot be combined with direct interactive execution, run the interactive operation directly and record its result through separate post-operation verification. Do not invent a logging workaround.

**Authentication input boundary:** ordinary `tee` pipelines capture the standard output and standard error that are connected to them; they do not, by themselves, capture keyboard input from the terminal. Do not claim that this guarantees a password was not exposed by every other mechanism. Never deliberately echo, store, log, or transmit passwords. Keep authentication prompts on the user's terminal and do not redirect or record terminal input.

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

## 9. Assistant error register — observed mistakes and prevention

This table records concrete mistakes made while generating or guiding commands in prior sessions. It is a mandatory learning aid for future command generation. The entries distinguish confirmed mistakes from causes that have not been established. It must not be used to claim that a particular mistake caused an unrelated crash or system symptom without evidence.

| Observed assistant error | What went wrong / evidence boundary | Mandatory rule to avoid repeating it |
|---|---|---|
| Used top-level asynchronous `exec > >(tee -a "$REPORT") 2>&1` in commands intended for the interactive Bash shell (btop audit, 2026-11-18) | Changed the interactive shell's file descriptors persistently and created successive tee redirection chains. Later prompts and commands were written into the reports; the controlled reproduction confirmed the chain mechanism. | Never use this pattern in a pasted interactive-shell block. Use a dedicated script process or a scoped subshell with a managed lifecycle. |
| Recommended stopping the display manager during a report-growth incident | This was unnecessarily disruptive: it terminated the graphical session and removed the user's access to the desktop/chat. It was not a proportionate first diagnostic step. | Never stop a display manager as a generic logging response. Identify and inspect the exact writer first; stop only a confirmed unwanted process using the least disruptive targeted action. |
| fwupd audit script tested whether `/etc/fwupd/fwupd.conf` existed but not whether it was readable (2026-11-19) | The file existed but `sed` failed with “Permission denied”. With strict error handling and a pipeline, the grouped audit stopped at that point. Remote configuration, `fwupdmgr get-remotes` and `get-settings` were not inspected. The report was incomplete. | Preflight every path for existence, file type and readability. Treat permission restrictions as explicit findings; select an approved read-only privilege method when needed. Record skipped/unrun checks and never present a partial report as complete. |
| Used a foreground `tee` pipeline for the fwupd diagnostic without a material need | The pattern was not the prohibited asynchronous process-substitution pattern. There is no evidence that this foreground `tee` caused the terminal crash. It nevertheless added unnecessary pipeline complexity. | Do not use `tee` by habit. Choose the simplest safe capture method for the task. For a short diagnostic, direct terminal output may be sufficient. When a report is required, isolate capture in a script process or scoped subshell; do not redirect the interactive shell. |
| Placed `set -Eeuo pipefail` in a block intended to be pasted into an interactive shell | Strict shell options can persist in the user's current shell. The combination also made the fwupd audit abort on an unhandled read-permission failure. | Scope strict options to a standalone script or subshell. Design expected non-zero outcomes explicitly; strict mode does not replace error handling. |
| Used repeated `|| true` in the fwupd audit | This hid command failures without distinguishing expected absence from genuine errors. | Handle each expected condition explicitly, preserve unexpected exit statuses, and report failures rather than suppressing them. |
| Did not provide a completion marker or completeness summary in the fwupd audit | The output stopped at the first permission error and did not clearly state which later checks had not run. | Multi-section diagnostics must end with a status summary: completed, skipped, failed and not run. Include an explicit complete/incomplete result. |
| Previously overstated what kerneloops configuration proved | A setting permitting or preventing forwarding describes policy/capability; it does not establish that a report was successfully transmitted. No successful submission evidence had been established. | Distinguish configuration, permission, process activity, attempted transmission and confirmed successful transmission. State only what the evidence supports. |
| Initially risked classifying ordinary background/network activity as telemetry during the Mint privacy audit | Local mDNS/DNS-SD discovery and printing are functional network activity, not evidence of unsolicited telemetry. The user clarified that the audit is not a hunt for ordinary daemons. | Keep the question narrow: identify unsolicited collection or external transmission without explicit user choice. A running daemon, network socket or LAN packet alone is not telemetry evidence. |
| Briefly reversed a user-level GVFS GOA service mask with an `unmask` command before masking it again | The command sequence temporarily undid the intended state. The mask was reapplied and later verified as masked/inactive. | Before state changes, verify the exact target and intended verb. After each operation, verify both enablement/mask state and active state; do not assume a command sequence produced the intended result. |

### 9.1 Mandatory script-review checklist

Before presenting a command block or script, review it for all of the following:

1. **Shell and scope:** Is this the correct shell? Will shell options, variables, traps, working directory or file descriptors persist in the user's interactive session?
2. **Permissions:** Are all files checked for existence, type and readability before access? Is elevation genuinely necessary?
3. **Failure handling:** Are expected missing/permission-denied cases handled explicitly? Are unexpected errors and exit statuses preserved?
4. **Logging:** Is logging necessary? Is `tee` genuinely useful? Is the logger foreground, bounded and guaranteed to finish? Does any redirection alter the interactive shell?
5. **Interaction:** Are authentication prompts, installers, package operations, TUIs and user-input commands directly attached to the terminal?
6. **Process lifecycle:** Are child processes waited for? Could any process remain as an untracked writer after the parent exits?
7. **Output bounds:** Are command output, runtime, loops and journal ranges bounded?
8. **Report integrity:** Is the filename collision-safe? Is existing data preserved? Is the report's completion and exit status unambiguous?
9. **Scope discipline:** Does the script answer the actual question without unrelated inventory, cleanup or changes?
10. **Evidence discipline:** Does the interpretation distinguish capability from observed activity and observed activity from confirmed transmission?
11. **User safety:** Are environment, purpose, risk, expected duration and safe stop explained before execution?
12. **Verification:** Is there a separate, bounded post-run check for the actual result and any unexpected surviving processes?

A script that fails this review must be corrected before it is given to the user. Large scripts are acceptable when the task warrants them; correctness, bounded behaviour, clarity and reviewability matter more than line count.

## 10. Reusable instruction for future ChatGPT sessions

Copy and paste this instruction whenever requesting shell commands or scripts:

~~~text
Before generating any Bash, Linux shell, or Windows PowerShell commands, follow the Cross-Platform Command Execution and Logging Safety Standard:
https://github.com/laconic-lab/projects/blob/main/memory/CROSS-PLATFORM-COMMAND-EXECUTION-AND-LOGGING-SAFETY-STANDARD.md

This standard is mandatory:
- Diagnose first; prefer read-only checks before changes.
- Use bounded commands and bounded report output.
- Never use asynchronous Bash process substitution such as exec > >(tee ...) for report logging.
- Keep logging in the foreground with a defined lifecycle; account for child/background processes.
- Preserve interactive terminal applications and TUIs; never put interactive commands, sudo authentication prompts or installers inside tee/logging pipelines or timeout wrappers.
- Run interactive operations directly in the terminal; perform bounded non-interactive verification and reporting only after they exit.
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

## 11. Applicability

This standard applies to new chats and projects, regardless of whether the target is Linux Mint, Arch Linux, another Linux distribution, Windows PowerShell, a VM, WSL or a container.

Project-specific requirements and verified platform behaviour take precedence over generic examples, but no project may waive the core requirements for bounded execution, controlled logging, process lifecycle management, data preservation and explicit authorization.

**Objective:** Every command must finish predictably, every report must stop growing when its writer exits, and the user must never have to rely on an editor warning to discover uncontrolled output.
