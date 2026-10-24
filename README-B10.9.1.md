# B10.9.1 — major:minor parsing fix

The B10.9 kernel device-identity inspection now requests raw `lsblk` output and strips whitespace before checking the `major:minor` format. This prevents the aligned output padding of `lsblk` from causing a false block. Empty, missing, and malformed IDs still fail closed.

Read-only. No disk writes or installation execution enabled.
