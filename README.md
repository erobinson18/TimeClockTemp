TimeClock Engine
Overview

TimeClock is an offline-first time clock engine designed for reliability in real-world conditions. It supports Web, Android, and iOS clients and ensures punches are never lost due to network issues. The backend remains the single source of truth, while clients focus on capture, storage, and synchronization.

This repository is structured as a reusable engine intended for long-term internal use and future enterprise integrations.

Core Design

The engine follows three rules: punches are always captured, synchronization is deterministic, and business logic lives on the server. Clients never decide clock-in or clock-out state; they only submit events. The backend resolves employee status from punch history.

Repository Structure
TimeClockTemp/
├── backend/
│   └── TimeClock/
│       ├── TimeClock.Api
│       ├── TimeClock.Application
│       ├── TimeClock.Domain
│       └── TimeClock.Infrastructure
│
└── mobile/
    └── flutter/
        └── mobile_timeclock/

Backend Summary (.NET)

The API project exposes HTTP endpoints and Swagger. The application layer coordinates use cases such as punching, status lookup, verification, and batch sync. The domain layer defines business rules and core models. The infrastructure layer handles persistence using SQL Server and Entity Framework Core.

All integrations with external systems should be implemented in the application layer.

Mobile Client Summary (Flutter)

The Flutter client is a thin UI and transport layer. Punches are written to local storage immediately and synced when connectivity is confirmed. Hive is used for offline persistence, and Dio is used for HTTP communication.

Connectivity is determined by backend reachability, not just network presence.

Offline and Sync Behavior

Punches created while offline are queued locally and sent to the backend as a batch once connectivity is restored. The backend processes punches in order and recalculates employee status. After successful sync, the local queue is cleared and status is refreshed.

Configuration and Integration Points

Backend database configuration is located in the API project’s appsettings file. Employee verification and status resolution are intentionally abstracted and should be extended in the application layer when integrating with enterprise systems such as payroll or HR platforms.

Intended Extensions

This engine is designed to be extended without modification to core logic. Planned or optional add-ons include authentication, enterprise employee lookup, payroll export, approvals, auditing, and reporting.

Platform Notes

The backend is stateless and suitable for IIS, cloud hosting, or containers. Flutter supports Web and Android builds on Windows. iOS builds require macOS for signing and App Store submission.

Summary

TimeClock provides a reliable, offline-capable foundation for employee time tracking with a clear separation of concerns and safe extension points for future development.



Developer Onboarding
Prerequisites

Backend development requires .NET (LTS), SQL Server or LocalDB, and Visual Studio or VS Code.
Mobile development requires Flutter SDK, Android Studio (for Android builds), and VS Code or Visual Studio.

Getting Started (Local)

Start the backend API project.

Verify Swagger loads successfully.

Run the Flutter application (Web or Android).

Use a valid employee GUID for testing.

Confirm status, punch, offline queue, and sync behavior.

The backend must be running for online punches and sync operations.

Integration Hook Locations (Code-Level)

The engine is intentionally structured so enterprise integrations can be added without touching core logic.

Employee Verification

Location:

TimeClock.Application.Services.EmployeeVerificationService


Replace stub logic here when integrating with:

HR systems

Payroll systems

Employee master records (e.g., Viewpoint)

Employee Status Resolution

Location:

TimeClock.Application.Services.EmployeeStatusService


Extend here for:

Cross-site logic

Weekend rules

Transfer handling

Supervisor overrides

Database / Enterprise Data

Location:

TimeClock.Infrastructure


Replace or extend repository implementations to integrate with:

SQL Server (production)

Enterprise reporting databases

Read-only mirrors of HR systems

Offline Engine Extension Guide

The offline engine is intentionally isolated from business rules.

Where Offline Logic Lives

Local punch storage:

mobile/flutter/mobile_timeclock/lib/data/local/punch_queue.dart


Sync DTOs:

mobile/flutter/mobile_timeclock/lib/data/models/sync.dart


Sync execution:

mobile/flutter/mobile_timeclock/lib/features/status

Safe Extension Rules

Offline logic should only:

Store punches

Preserve order

Retry sync

It should never:

Decide employee status

Enforce business rules

Reject punches

Production Deployment Checklist
Backend

Switch LocalDB to SQL Server

Configure connection string in appsettings.json

Enable HTTPS

Disable Swagger in production

Deploy to IIS, Azure App Service, or container host

Mobile

Remove forced Offline Mode

Set production API base URL

Generate Android keystore

Build Android App Bundle (AAB)

iOS builds require macOS for signing and App Store submission

Planned Engine Add-Ons

The following features can be added without altering core architecture:

Authentication (SSO, Azure AD, OAuth)

Idempotency and duplicate punch protection

Supervisor approvals

Payroll export

Audit trail and reporting

Optional geofencing validation

Role-based access control

Each add-on should be layered on top of existing services rather than embedded into them.

Maintenance Guidelines

Business rules belong in the backend

Clients remain thin and offline-safe

Do not bypass the sync pipeline

Preserve deterministic ordering

Avoid coupling UI logic to enterprise rules

Final Notes

This engine is designed for long-term ownership and iterative expansion. New features should be added as layers, not modifications to core flow. The offline-first guarantee must always be preserved.

Optional Next Steps (When Ready)

Add idempotency keys to punch processing

Add automated integration tests

Introduce structured logging and metrics

Prepare a public-facing technical overview (if open-sourced)