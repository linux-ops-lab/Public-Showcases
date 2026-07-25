#!/bin/bash

# -----------------------------------------------------------------------------
# Permission and access audit for a local user account
# -----------------------------------------------------------------------------

# Read the target user from the first positional argument.
TARGET_USER="$1"

# Define the directory and filename used for the audit log.
LOGDIR="/var/log/permission-check"
LOGFILE="permission-check-$TARGET_USER-$(date '+%Y-%m-%d_%H-%M').log"

# Store reusable separators for a consistent text-based layout.
LINE="================================================================================"
SUBLINE="--------------------------------------------------------------------------------"

# Create the log directory if it does not already exist.
mkdir -p "$LOGDIR"

# Redirect standard output and standard error to both the terminal and the log.
exec > >(tee -a "$LOGDIR/$LOGFILE") 2>&1

# -----------------------------------------------------------------------------
# Output formatting functions
# -----------------------------------------------------------------------------

# Print the main script banner and basic execution information.
print_banner() {
  printf '\n%s\n' "$LINE"
  printf ' PERMISSION AND ACCESS AUDIT\n'
  printf '%s\n' "$LINE"
  printf ' Target user : %s\n' "$TARGET_USER"
  printf ' Started     : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf ' Log file    : %s/%s\n' "$LOGDIR" "$LOGFILE"
  printf '%s\n\n' "$LINE"
}

# Print a top-level section heading.
print_section() {
  printf '\n%s\n' "$LINE"
  printf ' %s\n' "$1"
  printf '%s\n\n' "$LINE"
}

# Print a subsection heading inside a larger audit category.
print_subsection() {
  printf '\n%s\n' "$SUBLINE"
  printf ' %s\n' "$1"
  printf '%s\n\n' "$SUBLINE"
}

# Print an informational status message.
print_info() {
  printf '[INFO] %s\n' "$1"
}

# Print an error message to the combined terminal and log output.
print_error() {
  printf '[ERROR] %s\n' "$1"
}

# Print the command-line usage and all supported audit options.
show_usage() {
  printf 'Usage: %s <user> <option> [option ...]\n\n' "${0##*/}"
  printf 'Available options:\n'
  printf '  permissions   Check directory and file ownership for the user and groups.\n'
  printf '  directories   Check directory ownership for the user and groups.\n'
  printf '  files         Check file ownership for the user and groups.\n'
  printf '  acl           Check user and group ACL entries.\n'
  printf '  acl-user      Check ACL entries assigned directly to the user.\n'
  printf '  acl-group     Check ACL entries assigned to the user groups.\n'
  printf '  systemd       Check systemd User, Group, and SupplementaryGroups entries.\n'
  printf '  systemd-user  Check systemd User entries.\n'
  printf '  systemd-group Check systemd Group and SupplementaryGroups entries.\n'
  printf '  sudo          Check sudo permissions for the user.\n'
  printf '  special       Check root-owned setuid and setgid objects.\n'
  printf '  suid          Check root-owned setuid objects.\n'
  printf '  setgid        Check root-owned setgid objects.\n'
  printf '  all           Run all available audit categories.\n'
  printf '  help          Display this help text.\n\n'
  printf 'Multiple options can be combined in one execution.\n'
  printf 'Example: %s <user> permissions acl systemd sudo\n' "${0##*/}"
}

# -----------------------------------------------------------------------------
# Audit functions
# -----------------------------------------------------------------------------

# Find directories owned directly by the target user.
find_du() {
  find / \
    \( \
    -path '/.snapshots' -o \
    -path '/proc' -o \
    -path '/sys' -o \
    -path '/dev' \
    \) -prune \
    -o -type d -user "$TARGET_USER" -exec ls -ld {} +
}

# Declare an array used to store the names of all target-user groups.
UGROUPS=()

# Collect all group names assigned to the target user.
group_c() {
  count=0
  for ugid in $(id -G "$TARGET_USER"); do
    UGROUPS["$count"]=$(getent group "$ugid" | cut -d ":" -f 1)
    ((count++))
  done
}

# Preserve the existing array declaration used by the directory group check.
GDIR=()

# Find directories owned by any group assigned to the target user.
find_dg() {
  for g in $(id -G "$TARGET_USER"); do
    print_info "Checking ownership for group GID: $g"
    find / \
      \( \
      -path '/.snapshots' -o \
      -path '/proc' -o \
      -path '/sys' -o \
      -path '/dev' \
      \) -prune \
      -o -type d -gid "$g" -exec ls -ld {} +
    printf '\n'
  done
}

# Find files owned directly by the target user.
find_fu() {
  find / \
    \( \
    -path '/.snapshots' -o \
    -path '/proc' -o \
    -path '/sys' -o \
    -path '/dev' \
    \) -prune \
    -o -type f -user "$TARGET_USER" -exec ls -l {} +
}

# Find files owned by any group assigned to the target user.
find_fg() {
  for g in $(id -G "$TARGET_USER"); do
    print_info "Checking ownership for group GID: $g"
    find / \
      \( \
      -path '/.snapshots' -o \
      -path '/proc' -o \
      -path '/sys' -o \
      -path '/dev' \
      \) -prune \
      -o -type f -gid "$g" -exec ls -l {} +
    printf '\n'
  done
}

# Find ACL entries assigned directly to the target user.
find_aclu() {
  find / \
    \( \
    -path '/proc' -o \
    -path '/sys' -o \
    -path '/dev' -o \
    -path '/.snapshots' \
    \) -prune \
    -o -print -exec getfacl -p -s -- {} + 2>/dev/null | grep -B 5 "user:$TARGET_USER"
}

# Find ACL entries assigned to any group of the target user.
find_aclg() {
  for acl_group in "${UGROUPS[@]}"; do

    find / \
      \( \
      -path '/proc' -o \
      -path '/sys' -o \
      -path '/dev' -o \
      -path '/.snapshots' \
      \) -prune \
      -o -print -exec getfacl -p -s -- {} + 2>/dev/null | grep -B 5 "group:$acl_group"
  done
}

# Display the sudo permissions assigned to the target user.
sudou() {
  sudo -l -U "$TARGET_USER"
}

# Find root-owned files and directories with the setuid bit enabled.
find_suid() {
  find / -type f -user root -perm -4000 -ls 2>/dev/null
  find / -type d -user root -perm -4000 -ls 2>/dev/null
}

# Find root-owned files and directories with the setgid bit enabled.
find_guid() {
  find / -type f -user root -perm -2000 -ls 2>/dev/null
  find / -type d -user root -perm -2000 -ls 2>/dev/null
}

# Collect all installed systemd service unit names.
sysd_units() {
  mapfile -t services < <(
    systemctl list-unit-files \
      --type=service \
      --no-legend \
      --no-pager \
      | awk '{print $1}'
  )
}

# Check systemd service definitions for a matching User directive.
sysd_u() {
  mapfile -t services < <(
    systemctl list-unit-files \
      --type=service \
      --no-legend \
      --no-pager \
      | awk '{print $1}'
  )

  for s in "${services[@]}"; do
    if systemctl cat "$s" | grep -q "User=$TARGET_USER"; then
      print_info "User assignment found in service: $s"
      systemctl status "$s" --no-pager
      printf '\n'
    fi
  done
}

# Check systemd service definitions for matching group directives.
sysd_g() {
  print_info "Checking primary Group assignments."
  for s in "${services[@]}"; do
    # Check the primary Group directive of the service unit.
    for ug in "${UGROUPS[@]}"; do
      if systemctl cat "$s" | grep -q "Group=$ug"; then
        print_info "Primary group assignment found in service: $s"
        systemctl status "$s" --no-pager
      fi
    done
  done

  printf '\n'

  print_info "Checking SupplementaryGroups assignments."
  for s in "${services[@]}"; do
    # Check the SupplementaryGroups directive of the service unit.
    for ug2 in "${UGROUPS[@]}"; do
      if systemctl cat "$s" | grep -q "SupplementaryGroups=$ug2"; then
        print_info "Supplementary group assignment found in service: $s"
      fi
    done
  done
}

# -----------------------------------------------------------------------------
# Presentation wrappers for grouped audit categories
# -----------------------------------------------------------------------------

# Run both user and group directory ownership checks.
run_directory_checks() {
  print_section "DIRECTORY OWNERSHIP"
  print_subsection "Directories owned by user: $TARGET_USER"
  find_du
  print_subsection "Directories owned by groups of user: $TARGET_USER"
  find_dg
}

# Run both user and group file ownership checks.
run_file_checks() {
  print_section "FILE OWNERSHIP"
  print_subsection "Files owned by user: $TARGET_USER"
  find_fu
  print_subsection "Files owned by groups of user: $TARGET_USER"
  find_fg
}

# Run all classic ownership checks for directories and files.
run_permission_checks() {
  print_section "CLASSIC OWNERSHIP PERMISSIONS"
  print_info "Checking directory and file ownership for the target user and its groups."
  run_directory_checks
  run_file_checks
}

# Run the ACL check assigned directly to the target user.
run_acl_user_check() {
  print_section "USER ACL ENTRIES"
  print_info "Checking ACL entries assigned directly to user: $TARGET_USER"
  printf '\n'
  find_aclu
}

# Run the ACL checks assigned through the target user's groups.
run_acl_group_check() {
  print_section "GROUP ACL ENTRIES"
  print_info "Checking ACL entries assigned to groups of user: $TARGET_USER"
  printf '\n'
  find_aclg
}

# Run all user and group ACL checks.
run_acl_checks() {
  run_acl_user_check
  run_acl_group_check
}

# Run the systemd User directive check.
run_systemd_user_check() {
  print_section "SYSTEMD USER ASSIGNMENTS"
  print_info "Checking service units containing User=$TARGET_USER."
  printf '\n'
  sysd_u
}

# Run the systemd Group and SupplementaryGroups checks.
run_systemd_group_check() {
  print_section "SYSTEMD GROUP ASSIGNMENTS"
  print_info "Checking service units assigned to groups of user: $TARGET_USER"
  printf '\n'
  sysd_g
}

# Run all systemd identity assignment checks.
run_systemd_checks() {
  run_systemd_user_check
  run_systemd_group_check
}

# Run the sudo permission check.
run_sudo_check() {
  print_section "SUDO PERMISSIONS"
  print_info "Checking sudo rules effective for user: $TARGET_USER"
  printf '\n'
  sudou
}

# Run the root-owned setuid object check.
run_suid_check() {
  print_section "ROOT-OWNED SETUID OBJECTS"
  print_info "Checking root-owned files and directories with the setuid bit enabled."
  printf '\n'
  find_suid
}

# Run the root-owned setgid object check.
run_setgid_check() {
  print_section "ROOT-OWNED SETGID OBJECTS"
  print_info "Checking root-owned files and directories with the setgid bit enabled."
  printf '\n'
  find_guid
}

# Run both special permission-bit checks.
run_special_permission_checks() {
  run_suid_check
  run_setgid_check
}

# Run every audit category available in this script.
run_all_checks() {
  run_permission_checks
  run_acl_checks
  run_systemd_checks
  run_sudo_check
  run_special_permission_checks
}

# -----------------------------------------------------------------------------
# Script initialization
# -----------------------------------------------------------------------------

# Display the script banner before starting the selected checks.
print_banner

# Display the local identity information for the target user.
print_section "TARGET USER IDENTITY"
id "$TARGET_USER"

# Collect group names and systemd service units for later checks.
group_c
sysd_units

# Require at least one audit option after the target user argument.
if [[ -z "$2" ]]; then
  print_error "No audit option was provided."
  printf '\n'
  show_usage
  exit 1
fi

# -----------------------------------------------------------------------------
# Option dispatcher
# -----------------------------------------------------------------------------

# Process every option supplied after the target user so that audit categories
# can be combined in a single script execution.
for option in "${@:2}"; do
  case "$option" in
    permissions)
      run_permission_checks
      ;;
    directories | dir)
      run_directory_checks
      ;;
    files | file)
      run_file_checks
      ;;
    acl)
      run_acl_checks
      ;;
    acl-user)
      run_acl_user_check
      ;;
    acl-group | test)
      run_acl_group_check
      ;;
    systemd)
      run_systemd_checks
      ;;
    systemd-user | sysdu)
      run_systemd_user_check
      ;;
    systemd-group | sysdg)
      run_systemd_group_check
      ;;
    sudo)
      run_sudo_check
      ;;
    special)
      run_special_permission_checks
      ;;
    suid)
      run_suid_check
      ;;
    setgid)
      run_setgid_check
      ;;
    all)
      run_all_checks
      ;;
    help | -h | --help)
      print_section "USAGE"
      show_usage
      ;;
    *)
      print_error "Unknown audit option: $option"
      printf '\n'
      show_usage
      exit 2
      ;;
  esac
done

# Print a final message after all requested audit categories have finished.
print_section "AUDIT FINISHED"
print_info "All requested checks have been executed."
print_info "Log file: $LOGDIR/$LOGFILE"
printf '\n'
