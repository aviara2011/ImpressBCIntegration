# I/I preview invalid-state diagnostics — 1.0.0.79

Reported on BC 28.4.53241.54346 with integration 1.0.0.78: Gen. Jnl.-Post Preview.PreviewStart reports an invalid exit state. The available BC 28.1 reference source raises this when the callback returns true or GetLastErrorCallStack is blank. The report does not reveal the initial posting validation failure or prove which condition occurred on BC 28.4.

The custom callback now clears stale error state before its Boolean runner. The normal false return with an error call stack is left intact, including BC's successful preview rollback sentinel. For an invalid return state, the callback displays errors retained by Error Message Management, then stops. If none are retained, it surfaces remaining error text or an explicit diagnostic requiring first-error debugging. It never manufactures a successful preview sentinel or shows entries from an unconfirmed preview.

The existing runner still executes all preparation and posting within one rollback boundary, suppresses Sales-Post commits and unconditionally raises an error if posting returns normally. No commits or posting retries were added.

This is a diagnostic handling change, not a confirmed fix for the underlying BC 28.4 posting failure. Compile against cached BC 28.1 symbols, then retry in the affected sandbox. If no underlying error is retained, capture the initial error with AL debugger breakOnError enabled and obtain matching BC 28.4 symbols before further changes.
