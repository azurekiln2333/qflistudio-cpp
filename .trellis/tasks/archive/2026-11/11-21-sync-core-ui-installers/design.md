# Design

Use the isolated sibling worktrees at D:/MyNewProjects/_wt/qfli-c-ui-sync.
The app branch starts from github/main; the clean core worktree is detached at cbaa4a4.
The original app and core worktrees contain unrelated uncommitted work and stay intact.

The UI lives in the shared core. Keep pubspec.yaml's sibling path dependency.
All installer jobs pin the same new core SHA. Stock Flutter needs only the Huawei platform-view compatibility patch because the newer core already avoids TargetPlatform.ohos. OHOS builds use the original core source.

Run app regression tests against the clean new core. Fix only integration incompatibilities. Use the existing published native artifacts because this UI change changes no native ABI.

Publish the isolated branch with explicit refspecs and run the existing workflow with target=all. Promote to GitHub main after the branch build succeeds. Keep exact run and artifact evidence in task records.
