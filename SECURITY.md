# Security Policy

## Supported versions

RePlace. is a small hobby project. Only the latest version on the `main` branch receives security fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Report them privately through GitHub instead: open the **Security** tab of this repository and choose **Report a vulnerability** ([private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)).

Please include:

- a description of the problem and its impact,
- steps to reproduce it, and
- your macOS, Xcode and iPhone iOS versions.

This is a spare-time project, so I cannot promise a response time, but I will read every report and do my best to fix confirmed issues.

## Scope

RePlace. runs locally on your Mac. It has no server, no user accounts and sends no data to the developer (see the *Privacy* section in the [README](README.md)).

What is relevant for security reports:

- ways to run unintended commands through the app, for example through crafted input in the address or coordinate fields,
- unintended access to files, data or devices,
- problems in how the app starts Apple's `devicectl` tool.

Not in scope:

- faking a location in other apps or services and the terms of use of those services (see *Responsible use* in the [README](README.md)),
- vulnerabilities in Xcode, `devicectl`, MapKit or iOS themselves. Please report those to Apple.

## How the app is built

- The app launches Apple's `xcrun devicectl` with a fixed argument list and does **not** use a shell, so input cannot be turned into commands.
- Coordinates are parsed as numbers and range-checked before use.
- The app is not sandboxed because it must start `devicectl`, but it is built with the **Hardened Runtime**.
- There are no third-party dependencies.
