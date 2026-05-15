#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Apply user-provided PostgreSQL configuration
# Applies custom postgresql.conf settings and pg_hba.conf rules from addon config
# ==============================================================================

declare POSTGRES_DATA
declare POSTGRESQL_CONF
declare PG_HBA_CONF
declare -a FORBIDDEN_PARAMS
declare PARAM_COUNT
declare RULE_COUNT

POSTGRES_DATA=/data/postgres
POSTGRESQL_CONF="${POSTGRES_DATA}/postgresql.conf"
PG_HBA_CONF="${POSTGRES_DATA}/pg_hba.conf"
PARAM_COUNT=0
RULE_COUNT=0

# List of parameters that cannot be modified by users
# These are critical for addon operation and Home Assistant integration
FORBIDDEN_PARAMS=(
    "data_directory"
    "hba_file"
    "ident_file"
    "port"
    "unix_socket_directories"
    "shared_preload_libraries"
)

# Check if a parameter is forbidden
is_forbidden_param() {
    local param="${1}"
    local forbidden

    for forbidden in "${FORBIDDEN_PARAMS[@]}"; do
        if [[ "${param}" == "${forbidden}" ]]; then
            return 0
        fi
    done
    return 1
}

# Safely read an optional bashio config value.
# bashio::config "key" "" collapses the empty-string default to the literal
# string "null" (due to `${2:-null}` in bashio), which then gets written into
# pg_hba.conf and rejected by PostgreSQL. Guard with has_value to return a true
# empty string instead.
optional_config() {
    local key="${1}"
    local fallback="${2:-}"
    if bashio::config.has_value "${key}"; then
        bashio::config "${key}"
    else
        printf "%s" "${fallback}"
    fi
}

# Apply postgresql.conf configuration
apply_postgresql_config() {
    if ! bashio::config.has_value 'postgresql_config'; then
        return 0
    fi
    
    bashio::log.info "Applying PostgreSQL configuration parameters..."
    
    # Get all keys from postgresql_config
    for key in $(bashio::config 'postgresql_config | keys[]'); do
        # Check if parameter is forbidden
        if is_forbidden_param "${key}"; then
            bashio::log.warning "Skipping forbidden parameter: ${key} (managed by addon)"
            continue
        fi
        
        # Get the value for this key
        local value
        value=$(bashio::config "postgresql_config.${key}")
        
        # Check if parameter already exists in the config file
        if grep -q "^[[:space:]]*${key}[[:space:]]*=" "${POSTGRESQL_CONF}"; then
            # Parameter exists, update it
            bashio::log.info "Updating postgresql.conf: ${key} = ${value}"
            sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "${POSTGRESQL_CONF}"
        else
            # Parameter doesn't exist, append it
            bashio::log.info "Adding to postgresql.conf: ${key} = ${value}"
            echo "${key} = ${value}" >> "${POSTGRESQL_CONF}"
        fi
        
        PARAM_COUNT=$(( PARAM_COUNT + 1 ))
    done
    
    if [[ ${PARAM_COUNT} -gt 0 ]]; then
        bashio::log.info "Applied ${PARAM_COUNT} PostgreSQL configuration parameter(s)"
    fi
}

# Apply pg_hba.conf configuration
apply_pg_hba_config() {
    # Always clean up previously written user-defined rules first so that
    # clearing pg_hba_config in the addon UI also removes any orphaned rules
    # (notably important to recover from a prior run that wrote malformed
    # entries — see GitHub issue #81).
    if grep -q "^# User-defined authentication rules" "${PG_HBA_CONF}"; then
        bashio::log.debug "Removing existing user-defined rules..."
        sed -i '/^# User-defined authentication rules/,$d' "${PG_HBA_CONF}"
        # Remove any trailing blank lines left behind
        sed -i -e :a -e '/^[[:space:]]*$/{$d;N;ba}' "${PG_HBA_CONF}"
    fi

    if ! bashio::config.has_value 'pg_hba_config'; then
        return 0
    fi

    bashio::log.info "Applying pg_hba.conf authentication rules..."

    # Add a comment separator for user rules
    echo "" >> "${PG_HBA_CONF}"
    echo "# User-defined authentication rules" >> "${PG_HBA_CONF}"

    # Get the number of rules
    local rule_count
    rule_count=$(bashio::config 'pg_hba_config | length')

    # Process each rule
    for (( i=0; i<rule_count; i++ )); do
        local type database user address method options
        local rule_line

        # Read rule components via optional_config so unset/null fields become
        # true empty strings instead of the literal string "null".
        type=$(optional_config "pg_hba_config[${i}].type" "host")
        database=$(optional_config "pg_hba_config[${i}].database")
        user=$(optional_config "pg_hba_config[${i}].user")
        address=$(optional_config "pg_hba_config[${i}].address")
        method=$(optional_config "pg_hba_config[${i}].method")
        options=$(optional_config "pg_hba_config[${i}].options")

        # Validate required fields
        if [[ -z "${database}" ]] || [[ -z "${user}" ]] || [[ -z "${method}" ]]; then
            bashio::log.warning "Skipping invalid pg_hba rule ${i}: missing required field(s) (database, user, or method)"
            continue
        fi
        
        # Validate address requirement for non-local types
        if [[ "${type}" != "local" ]] && [[ -z "${address}" ]]; then
            bashio::log.warning "Skipping invalid pg_hba rule ${i}: address required for type '${type}'"
            continue
        fi
        
        # Build the rule line
        if [[ "${type}" == "local" ]]; then
            # Local connections don't use address
            rule_line="${type}    ${database}    ${user}    ${method}"
        else
            # Network connections include address
            rule_line="${type}    ${database}    ${user}    ${address}    ${method}"
        fi
        
        # Add options if provided
        if [[ -n "${options}" ]]; then
            rule_line="${rule_line}    ${options}"
        fi
        
        # Add the rule to pg_hba.conf
        bashio::log.info "Adding pg_hba.conf rule: ${rule_line}"
        echo "${rule_line}" >> "${PG_HBA_CONF}"
        
        RULE_COUNT=$(( RULE_COUNT + 1 ))
    done
    
    if [[ ${RULE_COUNT} -gt 0 ]]; then
        bashio::log.info "Applied ${RULE_COUNT} pg_hba.conf authentication rule(s)"
    fi
}

# Main execution
main() {
    # Verify that configuration files exist
    if [[ ! -f "${POSTGRESQL_CONF}" ]]; then
        bashio::log.error "postgresql.conf not found at ${POSTGRESQL_CONF}"
        return 1
    fi
    
    if [[ ! -f "${PG_HBA_CONF}" ]]; then
        bashio::log.error "pg_hba.conf not found at ${PG_HBA_CONF}"
        return 1
    fi
    
    # Apply configurations
    apply_postgresql_config
    apply_pg_hba_config
    
    # Summary
    if [[ ${PARAM_COUNT} -eq 0 ]] && [[ ${RULE_COUNT} -eq 0 ]]; then
        bashio::log.info "No user configuration to apply"
    else
        bashio::log.info "User configuration applied successfully"
    fi
    
    return 0
}

# Run main function
main
