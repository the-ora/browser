# Data and Persistence

The app uses SwiftData with a single `ModelContainer` storing `TabContainer`, `History`, and `Download` models. The default store is under the app's Application Support directory as `OraData.sqlite`.

## Database Location

The SwiftData database is stored at:
```
~/Library/Application Support/com.orabrowser.ora/OraData.sqlite
```

## Data Models

### TabContainer
- Stores tab groups/containers (spaces)
- Manages tab organization and grouping

### History
- Browsing history entries
- URL visits and timestamps

### Download
- Download metadata and status
- File paths and progress tracking

## Development: Resetting Local Store

To reset the local store during development, you can delete the database file:

```bash
rm -f "$(getconf DARWIN_USER_DIR 2>/dev/null || echo "$HOME/Library/Application Support")/OraData.sqlite"*
```

> **⚠️ Caution: Use with care—this permanently clears tabs/history/download metadata.**

## Alternative Reset Method

You can also find and delete the database manually:

1. Open Finder
2. Press `Cmd+Shift+G`
3. Go to: `~/Library/Application Support/com.orabrowser.ora/`
4. Delete `OraData.sqlite` and related files (`OraData.sqlite-wal`, `OraData.sqlite-shm`)

## Data Migration

SwiftData handles schema migrations automatically, but major changes may require manual migration logic in the app code.

## Backup Considerations

The database contains:
- All tab states and organization
- Complete browsing history
- Download records

Consider this when implementing backup/sync features or privacy modes.