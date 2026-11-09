# Design Document: PostgreSQL Configuration Management

> **Note (version 6.0.0):** the `postgresql_config` option described here never worked: the Supervisor only keeps keys of a dictionary option that the schema lists by name, so the `match(...)` key dropped every setting. Version 6.0.0 replaces it with `postgresql_settings`, a list of `name=value` entries written to `postgresql.user.conf` (see README.md). `pg_hba_config` works as described.

## Overview

This document describes the design for allowing users to customize PostgreSQL configuration files (`postgresql.conf` and `pg_hba.conf`) through Home Assistant addon configuration, replacing the current "advanced users only" approach of using shell commands.

## Current State

### Existing Configuration Approach

Currently, users can modify PostgreSQL configuration files using the `init_commands` option:

```yaml
init_commands:
  - 'sed -i -e "/max_connections =/ s/= .*/= 50/" /data/postgres/postgresql.conf'
```

**Problems with this approach:**

- Requires shell scripting knowledge
- Error-prone (sed syntax, regex, escaping)
- Not validated
- Runs in `init-user` service (timing may be unpredictable)
- Hard to maintain and debug
- No safety guardrails

### Current Configuration Flow

1. `init-addon/run` - Initializes PostgreSQL data directory and base configuration
2. `init-user/run` - Runs user packages and init_commands
3. `postgres/run` - Starts PostgreSQL service

## Proposed Solution

### Design Principles

1. **Declarative Configuration**: Users specify _what_ they want, not _how_ to do it
2. **Type Safety**: Configuration is validated by Home Assistant schema
3. **User-Friendly**: Simple YAML, no shell scripting required
4. **Safe**: Prevent modification of critical settings
5. **Transparent**: All changes are logged
6. **Backward Compatible**: Existing init_commands continue to work
7. **Idempotent**: Same configuration produces same result

### New Configuration Options

#### 1. `postgresql_config` - Key-Value Configuration

Allows users to set or override PostgreSQL configuration parameters in `postgresql.conf`.

**Schema:**

```yaml
postgresql_config:
  parameter_name: "value"
```

**Example:**

```yaml
postgresql_config:
  log_statement: "all"
  log_duration: "on"
  work_mem: "16MB"
  maintenance_work_mem: "256MB"
  effective_cache_size: "4GB"
  random_page_cost: "1.1"
  checkpoint_completion_target: "0.9"
```

**Validation:**

- Keys must be valid PostgreSQL parameter names (string validation)
- Values are treated as strings (PostgreSQL handles type validation)
- Certain critical parameters are forbidden (see Safety section)

#### 2. `pg_hba_config` - Authentication Configuration

Allows users to append custom authentication rules to `pg_hba.conf`.

**Schema:**

```yaml
pg_hba_config:
  - type: "host|local|hostssl|hostnossl"
    database: "database_name"
    user: "username"
    address: "CIDR_address" # Optional, not used for 'local'
    method: "md5|trust|reject|scram-sha-256|etc"
    options: "key=value" # Optional
```

**Example:**

```yaml
pg_hba_config:
  # Allow specific subnet with password
  - type: "host"
    database: "homeassistant"
    user: "all"
    address: "192.168.1.0/24"
    method: "md5"

  # Require SSL for remote connections
  - type: "hostssl"
    database: "all"
    user: "admin"
    address: "0.0.0.0/0"
    method: "scram-sha-256"

  # Reject specific user
  - type: "host"
    database: "all"
    user: "guest"
    address: "0.0.0.0/0"
    method: "reject"
```

**Validation:**

- `type` must be one of: host, local, hostssl, hostnossl
- `database` and `user` are required strings
- `address` is required for non-local types
- `method` must be a valid authentication method

**Behavior:**

- Custom rules are **appended** to the default rules (not replaced)
- Default rules remain in place for safety
- Rules are applied in order (first match wins in pg_hba.conf)

### Implementation Architecture

#### File Structure

```
timescaledb/
├── config.yaml                              # Updated with new schema
└── rootfs/
    ├── etc/
    │   └── s6-overlay/
    │       └── s6-rc.d/
    │           └── init-addon/
    │               └── run                  # Updated to call helper script
    └── usr/
        └── share/
            └── timescaledb/
                ├── 000_install_timescaledb.sh
                ├── 001_reenable_auth.sh
                ├── 002_timescaledb_tune.sh
                └── 003_apply_user_config.sh  # NEW
```

#### New Script: `003_apply_user_config.sh`

This helper script will:

1. Read configuration from Home Assistant addon options
2. Validate settings
3. Apply `postgresql_config` settings to `postgresql.conf`
4. Apply `pg_hba_config` rules to `pg_hba.conf`
5. Log all changes

#### Integration Point in `init-addon/run`

The configuration application will occur at the end of `init-addon/run`, after:

- Data directory initialization
- Timescaledb tuning
- max_connections setting
- But BEFORE the postgres service starts

```bash
# At the end of init-addon/run, add:

# Apply user configuration overrides
if bashio::config.has_value 'postgresql_config' || bashio::config.has_value 'pg_hba_config'; then
    bashio::log.info "Applying user configuration overrides.."
    /usr/share/timescaledb/003_apply_user_config.sh
    bashio::log.info "done"
fi
```

### Configuration Schema (`config.yaml`)

```yaml
options:
  # ... existing options ...
  postgresql_config: {}
  pg_hba_config: []

schema:
  # ... existing schema ...
  postgresql_config:
    match(^[a-z_]+$)?: str
  pg_hba_config:
    - type: list(local|host|hostssl|hostnossl)?
      database: str?
      user: str?
      address: str?
      method: list(trust|reject|md5|password|scram-sha-256|gss|sspi|ident|peer|pam|ldap|radius|cert)?
      options: str?
```

### Safety Features

#### Forbidden PostgreSQL Parameters

These parameters cannot be modified via `postgresql_config` as they are critical for addon operation:

- `data_directory` - Managed by addon
- `hba_file` - Managed by addon
- `ident_file` - Managed by addon
- `port` - Managed by Home Assistant
- `unix_socket_directories` - Managed by addon
- `shared_preload_libraries` - Managed by addon (TimescaleDB requirement)

Attempts to set these will be logged as warnings and ignored.

#### Default pg_hba.conf Rules

The default rules created by the addon are:

```
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
local   all             all                                     md5
local   all             all                                     peer
```

These rules are **always present** and applied before user rules. User rules can only add additional rules, not remove these defaults.

### Error Handling

1. **Invalid Configuration**:
   - Validated by Home Assistant schema before applying
   - Schema errors prevent addon from starting
2. **Invalid PostgreSQL Parameter**:
   - Logged as warning
   - Parameter is skipped
   - Addon continues to start
3. **Invalid pg_hba Rule**:
   - Logged as warning
   - Rule is skipped
   - Addon continues to start

4. **File Write Errors**:
   - Logged as error
   - Addon fails to start (safe failure)

### Logging

All configuration changes are logged with INFO level:

```
[INFO] Applying user configuration overrides..
[INFO] Setting postgresql.conf parameter: log_statement = 'all'
[INFO] Setting postgresql.conf parameter: work_mem = '16MB'
[INFO] Adding pg_hba.conf rule: host homeassistant all 192.168.1.0/24 md5
[INFO] Applied 2 PostgreSQL config parameters and 1 pg_hba rules
[INFO] done
```

Warnings for skipped settings:

```
[WARN] Skipping forbidden parameter: shared_preload_libraries
[WARN] Skipping invalid pg_hba rule: missing required field 'database'
```

### Documentation Requirements

#### README.md Updates

Add new section: "Advanced Configuration"

````markdown
### PostgreSQL Configuration

#### Option: `postgresql_config`

Allows you to customize PostgreSQL server parameters. These settings are applied to `postgresql.conf`.

**Example:**

```yaml
postgresql_config:
  log_statement: "all"
  log_min_duration_statement: "1000" # Log queries taking > 1 second
  work_mem: "16MB"
  maintenance_work_mem: "256MB"
```
````

See [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config.html) for available parameters.

**Note:** Some critical parameters cannot be modified (e.g., `shared_preload_libraries`, `port`, `data_directory`) as they are managed by the addon.

#### Option: `pg_hba_config`

Allows you to add custom authentication rules to `pg_hba.conf`. Rules are appended to the default rules.

**Example:**

```yaml
pg_hba_config:
  # Allow specific subnet
  - type: "host"
    database: "homeassistant"
    user: "all"
    address: "192.168.1.0/24"
    method: "md5"

  # Require SSL for admin user
  - type: "hostssl"
    database: "all"
    user: "admin"
    address: "0.0.0.0/0"
    method: "scram-sha-256"
```

See [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html) for authentication methods.

**Warning:** Be careful with authentication rules. Incorrect configuration can lock you out of the database.

````

### Testing Approach

#### Manual Testing

1. **Test Case 1: Basic postgresql_config**
   - Set simple parameters (log_statement, work_mem)
   - Verify they appear in postgresql.conf
   - Verify PostgreSQL starts successfully
   - Verify settings are active: `SHOW log_statement;`

2. **Test Case 2: Forbidden parameters**
   - Try to set `shared_preload_libraries`
   - Verify warning is logged
   - Verify parameter is not changed
   - Verify addon starts successfully

3. **Test Case 3: Basic pg_hba_config**
   - Add a custom rule
   - Verify it appears in pg_hba.conf
   - Verify default rules are still present
   - Test authentication works as expected

4. **Test Case 4: Invalid pg_hba_config**
   - Provide invalid rule (missing required field)
   - Verify warning is logged
   - Verify addon starts successfully

5. **Test Case 5: Empty configuration**
   - Don't set postgresql_config or pg_hba_config
   - Verify addon works normally
   - Verify backward compatibility

6. **Test Case 6: Upgrade scenario**
   - Start addon with old config
   - Add new options
   - Restart addon
   - Verify settings are applied on existing database

#### Integration Testing

- Test across different architectures (amd64, aarch64, armv7)
- Test with fresh install vs upgrade
- Test interaction with timescaledb-tune
- Test interaction with max_connections setting

### Migration Path

**Existing Users:**
- No migration required
- New options are optional
- Existing `init_commands` continue to work
- Users can gradually migrate from init_commands to declarative config

**Documentation:**
- Add migration guide showing how to convert common init_commands to declarative config
- Example:
  ```yaml
  # Old way (still works)
  init_commands:
    - 'sed -i -e "/log_statement =/ s/= .*/= '\''all'\''/" /data/postgres/postgresql.conf'

  # New way (recommended)
  postgresql_config:
    log_statement: "all"
````

### Future Enhancements

1. **Configuration Templates**: Pre-defined templates for common scenarios
   - Performance tuning
   - Security hardening
   - Development mode
2. **Validation Improvements**: Check parameter values against PostgreSQL docs
3. **pg_hba Management**: Allow replacing default rules (advanced option)
4. **Configuration Backup**: Automatic backup before applying changes

5. **Web UI**: Integration with Home Assistant UI for easier configuration

## Implementation Checklist

- [ ] Update `config.yaml` with new schema
- [ ] Create `003_apply_user_config.sh` script
- [ ] Update `init-addon/run` to call new script
- [ ] Add validation for forbidden parameters
- [ ] Add logging for all changes
- [ ] Update README.md with new options
- [ ] Add examples to documentation
- [ ] Test on fresh install
- [ ] Test on upgrade scenario
- [ ] Test forbidden parameters
- [ ] Test invalid configurations
- [ ] Test across architectures

## Summary

This design provides a user-friendly, safe, and maintainable way to customize PostgreSQL configuration through declarative YAML configuration instead of shell commands. It maintains backward compatibility while providing a much better user experience for common configuration tasks.

The implementation follows Home Assistant addon best practices and the guidelines in AGENTS.md, ensuring consistent code quality and maintainability.
