#!/bin/bash
#
#    vi:set filetype=bash et ts=4:
#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2025 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#        Test script for si_mkdhcpserver
#        This script exhaustively tests the features of si_mkdhcpserver
#        using a configuration file in /tmp to avoid modifying system files.
#        Each modification is validated with kea-dhcp4 -t.

# Configuration
TEST_DIR="/tmp/si_mkdhcpserver_test"
CONFIG_FILE="${TEST_DIR}/kea-dhcp4.conf"
INVALID_DIR="/tmp/nonexistent_dir_$(date +%s)"
INVALID_FILE="${TEST_DIR}/kea-dhcp4|invalid.conf"
SI_MKDHCP="sbin/perl si_mkdhcpserver"  # Path to the Perl script (adjust if necessary)
KEA_DHCP4="kea-dhcp4"  # Path to the kea-dhcp4 executable (adjust if necessary)
EXIT_SUCCESS=0
EXIT_FAILURE=1

# Function to display a test message
print_test() {
    echo "=== Test: $1 ==="
}

# Function to check exit code
check_exit_code() {
    local expected=$1
    local actual=$2
    local test_name=$3
    if [ $actual -eq $expected ]; then
        echo "PASS: $test_name (Exit code: $actual)"
    else
        echo "FAIL: $test_name (Expected: $expected, Got: $actual)"
        exit 1
    fi
}

# Function to check for a message in the output (handles Added/Updated)
check_output() {
    local output=$1
    local pattern=$2
    local test_name=$3
    # Uses grep -E with -- to avoid patterns starting with -- being treated as options
    if echo "$output" | grep -E -q -- "$pattern"; then
        echo "PASS: $test_name (Output contains: $pattern)"
    else
        echo "FAIL: $test_name (Output does not contain: $pattern)"
        echo "Output obtained:"
        echo "$output"
        exit 1
    fi
}

# Function to check configuration consistency with kea-dhcp4 -t
check_config_consistency() {
    local test_name=$1
    local si_exit_code=$2
    if [ -f "$CONFIG_FILE" ]; then
        $KEA_DHCP4 -t "$CONFIG_FILE" > /dev/null 2>&1
        local kea_exit_code=$?
        if [ $kea_exit_code -eq 0 ]; then
            echo "PASS: $test_name (Configuration file valid according to kea-dhcp4 -t)"
        else
            if [ $si_exit_code -eq 0 ]; then
                echo "BUG: $test_name (si_mkdhcpserver returned 0 but kea-dhcp4 -t failed with code $kea_exit_code)"
                echo "Configuration file content:"
                cat "$CONFIG_FILE"
                exit 1
            else
                echo "PASS: $test_name (kea-dhcp4 -t failed as expected since si_mkdhcpserver failed)"
            fi
        fi
    else
        echo "PASS: $test_name (No configuration file to check, as no modification was expected)"
    fi
}

# Setup the test environment
setup() {
    echo "Preparing the test environment..."
    mkdir -p "$TEST_DIR"
    rm -f "$CONFIG_FILE"
}

# Cleanup after tests
cleanup() {
    echo "Cleaning up the test environment..."
    rm -rf "$TEST_DIR"
}

# Check if kea-dhcp4 is available
if ! command -v $KEA_DHCP4 &> /dev/null; then
    echo "Error: kea-dhcp4 is not installed or not in the PATH."
    echo "Please install Kea DHCP or adjust the KEA_DHCP4 variable in the script."
    exit 1
fi

# Run the tests
setup

# Test 1: Check --help option
print_test "Option --help"
output=$($SI_MKDHCP --help 2>&1)
check_exit_code $EXIT_SUCCESS $? "Option --help exit code"
check_output "$output" "si_mkdhcpserver \[options\]" "Option --help displays help"
# No file modification, so no kea-dhcp4 validation

# Test 2: Check --man option
print_test "Option --man"
output=$($SI_MKDHCP --man 2>&1)
check_exit_code $EXIT_SUCCESS $? "Option --man exit code"
check_output "$output" "SystemImager DHCP server configuration tool" "Option --man displays the manual"
# No file modification, so no kea-dhcp4 validation

# Test 3: Check no options provided (should fail)
print_test "No options provided"
output=$($SI_MKDHCP 2>&1)
check_exit_code $EXIT_FAILURE $? "No options exit code"
check_output "$output" "At least one action option is required" "No options displays an error"
# No file modification, so no kea-dhcp4 validation

# Test 4: Check --file with invalid path (non-existent directory)
print_test "Option --file with non-existent directory"
output=$($SI_MKDHCP --file "$INVALID_DIR/test.conf" --add-subnet 192.168.1.0/24 2>&1)
check_exit_code $EXIT_FAILURE $? "Option --file non-existent directory exit code"
check_output "$output" "directory '$INVALID_DIR' does not exists" "Option --file non-existent directory displays an error"
check_config_consistency "Option --file non-existent directory validation" $?

# Test 5: Check --file with invalid characters
print_test "Option --file with invalid characters"
output=$($SI_MKDHCP --file "$INVALID_FILE" --add-subnet 192.168.1.0/24 2>&1)
check_exit_code $EXIT_FAILURE $? "Option --file invalid characters exit code"
check_output "$output" "Invalid file path: .*/kea-dhcp4|invalid.conf" "Option --file invalid characters displays an error"
check_config_consistency "Option --file invalid characters validation" $?

# Test 6: Add a valid subnet
print_test "Add a valid subnet"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-subnet 192.168.1.0/24 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Add subnet exit code"
check_output "$output" "Added subnet 192.168.1.0/24" "Add subnet displays success message"
[ -f "$CONFIG_FILE" ] || { echo "FAIL: Configuration file $CONFIG_FILE not created"; exit 1; }
check_config_consistency "Add subnet validation" $si_exit_code

# Test 7: Add an existing subnet (should fail)
print_test "Add an existing subnet"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-subnet 192.168.1.0/24 2>&1)
si_exit_code=$?
check_exit_code $EXIT_FAILURE $si_exit_code "Add existing subnet exit code"
check_output "$output" "Subnet 192.168.1.0/24 already exists" "Add existing subnet displays an error"
check_config_consistency "Add existing subnet validation" $si_exit_code

# Test 8: Add a valid pool
print_test "Add a valid pool"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-pool 192.168.1.10 192.168.1.20 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Add pool exit code"
check_output "$output" "Added pool 192.168.1.10 - 192.168.1.20" "Add pool displays success message"
check_config_consistency "Add pool validation" $si_exit_code

# Test 9: Add a pool outside the subnet (should fail)
print_test "Add a pool outside the subnet"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-pool 10.0.0.10 10.0.0.20 2>&1)
si_exit_code=$?
check_exit_code $EXIT_FAILURE $si_exit_code "Add pool outside subnet exit code"
check_output "$output" "No subnet found containing IP 10.0.0.10" "Add pool outside subnet displays an error"
check_config_consistency "Add pool outside subnet validation" $si_exit_code

# Test 10: Add a valid client
print_test "Add a valid client"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-client testclient 00:11:22:33:44:55 192.168.1.100 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Add client exit code"
# Accepts the message with or without the "to subnet 192.168.1.0/24" suffix
check_output "$output" "Added client reservation testclient \(00:11:22:33:44:55, 192.168.1.100\)( to subnet 192.168.1.0/24)?" "Add client displays success message"
check_config_consistency "Add client validation" $si_exit_code
# Note: A Perl warning "Use of uninitialized value $ARGV[0] in pattern match (m//) at si_mkdhcpserver line 199" was observed.
# This indicates a bug in si_mkdhcpserver. Suggestion: Modify line 199 to add a "defined $ARGV[0]" check:
# Before: push @add_clients, shift @ARGV if $ARGV[0] =~ /^--global/;
# After: push @add_clients, shift @ARGV if defined $ARGV[0] && $ARGV[0] =~ /^--global/;

# Test 11: Add a client with IP outside subnet (should fail)
print_test "Add a client with IP outside subnet"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-client badclient 00:11:22:33:44:56 10.0.0.100 2>&1)
si_exit_code=$?
check_exit_code $EXIT_FAILURE $si_exit_code "Add client outside subnet exit code"
check_output "$output" "No subnet found for IP 10.0.0.100" "Add client outside subnet displays an error"
check_config_consistency "Add client outside subnet validation" $si_exit_code

# Test 12: Delete a client
print_test "Delete a client"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --del-client testclient 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Delete client exit code"
# Accepts the message with or without the "from subnet 192.168.1.0/24" suffix
check_output "$output" "Deleted client reservation testclient \(00:11:22:33:44:55, 192.168.1.100\)( from subnet 192.168.1.0/24)?" "Delete client displays success message"
check_config_consistency "Delete client validation" $si_exit_code

# Test 13: Delete a subnet with reservations (should fail without --force)
print_test "Delete a subnet with reservations without --force"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-client testclient 00:11:22:33:44:55 192.168.1.100 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Add client for subnet deletion test exit code"
check_output "$output" "Added client reservation testclient \(00:11:22:33:44:55, 192.168.1.100\)( to subnet 192.168.1.0/24)?" "Add client for subnet deletion test displays success message"
check_config_consistency "Add client for subnet deletion test validation" $si_exit_code
output=$($SI_MKDHCP --file "$CONFIG_FILE" --del-subnet 192.168.1.0/24 2>&1)
si_exit_code=$?
check_exit_code $EXIT_FAILURE $si_exit_code "Delete subnet with reservations exit code"
check_output "$output" "Cannot delete subnet 192.168.1.0/24: contains reservations" "Delete subnet with reservations displays an error"
check_config_consistency "Delete subnet with reservations validation" $si_exit_code

# Test 14: Delete a subnet with --force
print_test "Delete a subnet with --force"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --del-subnet 192.168.1.0/24 --force 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Delete subnet with --force exit code"
check_output "$output" "Deleted subnet 192.168.1.0/24" "Delete subnet with --force displays success message"
check_config_consistency "Delete subnet with --force validation" $si_exit_code

# Test 15: Configure domain-name
print_test "Configure domain-name"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --add-subnet 192.168.1.0/24 --dns-domain example.com 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Configure domain-name exit code"
check_output "$output" "(Added|Updated) domain-name as example.com" "Configure domain-name displays success message"
check_config_consistency "Configure domain-name validation" $si_exit_code

# Test 16: Configure domain-name-servers
print_test "Configure domain-name-servers"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --dns-servers 8.8.8.8 8.8.4.4 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Configure domain-name-servers exit code"
check_output "$output" "(Added|Updated) domain-name-servers to 8.8.8.8" "Configure domain-name-servers displays message for 8.8.8.8"
check_output "$output" "(Added|Updated) domain-name-servers to 8.8.4.4" "Configure domain-name-servers displays message for 8.8.4.4"
check_config_consistency "Configure domain-name-servers validation" $si_exit_code

# Test 17: List subnets
print_test "List subnets"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --list-subnets 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "List subnets exit code"
check_output "$output" "192.168.1.0/24" "List subnets displays the subnet"
# No file modification, so no kea-dhcp4 validation

# Test 18: List subnets in CSV
print_test "List subnets in CSV"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --list-subnets --csv 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "List subnets CSV exit code"
check_output "$output" "subnet,subnet-id,net-interface-name,ip-min,ip-max" "List subnets CSV displays the header"
# No file modification, so no kea-dhcp4 validation

# Test 19: Check --quiet with --list-subnets
print_test "Option --quiet with --list-subnets"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --list-subnets --quiet 2>&1)
si_exit_code=$?
check_exit_code $EXIT_SUCCESS $si_exit_code "Option --quiet with list-subnets exit code"
check_output "$output" "192.168.1.0/24" "Option --quiet with list-subnets displays only CSV output"
# No file modification, so no kea-dhcp4 validation

# Test 20: Check incompatibility --quiet with --debug
print_test "Incompatibility --quiet with --debug"
output=$($SI_MKDHCP --file "$CONFIG_FILE" --debug 1 --quiet 2>&1)
si_exit_code=$?
check_exit_code $EXIT_FAILURE $si_exit_code "Incompatibility quiet with debug exit code"
check_output "$output" "--quiet: is incompatible with --help, --man or --debug" "Incompatibility quiet displays an error"
# No file modification, so no kea-dhcp4 validation

# Test 21: Check incompatibility --quiet with --help
print_test "Incompatibility --quiet with --help"
output=$($SI_MKDHCP --quiet --help 2>&1)
si_exit_code=$?
check_exit_code $EXIT_FAILURE $si_exit_code "Incompatibility quiet with help exit code"
check_output "$output" "--quiet: is incompatible with --help, --man or --debug" "Incompatibility quiet with help displays an error"
# No file modification, so no kea-dhcp4 validation

# Test 22: Check incompatibility --quiet with --man
print_test "Incompatibility --quiet with --man"
output=$($SI_MKDHCP --quiet --man 2>&1)
si_exit_code=$?
check_exit_code $EXIT_FAILURE $si_exit_code "Incompatibility quiet with man exit code"
check_output "$output" "--quiet: is incompatible with --help, --man or --debug" "Incompatibility quiet with man displays an error"
# No file modification, so no kea-dhcp4 validation

# Cleanup
cleanup

echo "All tests have been executed successfully!"
exit 0
