# Backend Development Guidelines

> Best practices for backend development in this project.

---

## Overview

This directory contains guidelines for backend development. Fill in each file with your project's specific conventions.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Database Guidelines](./database-guidelines.md) | ORM patterns, queries, migrations | To fill |
| [Error Handling](./error-handling.md) | Error types, handling strategies | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Logging Guidelines](./logging-guidelines.md) | Structured logging, log levels | To fill |
| [Native Toolchain](./native-toolchain.md) | LLVM host tools, OHOS cross build, runtime validation gates | Recorded |
| [Android Runtime](./android-runtime.md) | Android LLVM packages, process isolation, streaming and cancellation | Recorded |
| [Desktop Runtime](./desktop-runtime.md) | Mixed translation units, language modes, libm, process cleanup and verification | Recorded |
| [Portable Runtime](./portable-runtime.md) | LLVM/WASI resources, interpreter limits, exceptions, cancellation and iOS channels | Recorded |
| [Web Runtime](./web-runtime.md) | Browser compiler workers, WASI I/O, durable project storage and actual UI verification | Recorded |

---

## How to Fill These Guidelines

For each guideline file:

1. Document your project's **actual conventions** (not ideals)
2. Include **code examples** from your codebase
3. List **forbidden patterns** and why
4. Add **common mistakes** your team has made

The goal is to help AI assistants and new team members understand how YOUR project works.

---

**Language**: All documentation should be written in **English**.
