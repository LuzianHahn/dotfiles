# Test Script Struggles - Current Status

## Core Problem
The test script `test_vim.sh` fails with exit code 3 when run in the Docker container **without producing any output**, making debugging extremely difficult.

## Key Observations

1. **Script runs successfully with node present** - All 30 tests pass, exit code 0
2. **Script returns exit code 3 with NO OUTPUT** when node is removed
3. **The issue is NOT a timeout** - Command completes in ~5 seconds, not timeout duration
4. **Debug output shows** `Current node: v24.21.0` even after removing node binary
5. **Without bash wrapper** (`docker exec` directly): tests complete with correct exit codes

## Debug Information

### Working Test (with node)
```bash
docker exec -w /root dotfiles-vim-test-1 bash -c 'source /root/.nvm/nvm.sh && ./test_vim.sh' > /tmp/dotfiles/test.log 2>&1
# Exit: 0
# 83 lines of output, all tests pass
```

### Failing Test (without node)
```bash
docker exec -w /root dotfiles-vim-test-1 rm -f /root/.nvm/versions/node/v24.21.0/bin/node
docker exec -w /root dotfiles-vim-test-1 bash -c 'source /root/.nvm/nvm.sh && ./test_vim.sh' > /tmp/dotfiles/test.log 2>&1
# Exit: 3
# 0 lines in output file - script fails silently
```

## Root Cause Hypothesis

The issue appears to be related to:
- Running `bash -c "./test_vim.sh"` in the Docker container context
- The combination with `source /root/.nvm/nvm.sh` and the script's `set -euo pipefail`
- Possibly a signal being sent that causes immediate exit without output
- Some command in the script failing with a signal (SIGTERM/SIGKILL) rather than returning a normal error code

## Verified Working Commands

```bash
# Simple vim command - works
docker exec dotfiles-vim-test-1 vim -u NONE -N -ex -c "echo 123" -c "q"
# Exit: 0

# Check nvm when node is present
docker exec -w /root dotfiles-vim-test-1 bash -c 'source /root/.nvm/nvm.sh && nvm current'
# Output: v24.21.0

# Check nvm when node is missing
docker exec -w /root dotfiles-vim-test-1 bash -c 'source /root/.nvm/nvm.sh && nvm current'
# Output: none
```

## File Locations

- `/tmp/dotfiles/test_vim.sh` - Main test script
- `/tmp/dotfiles/docker-compose.yml` - Container configuration  
- `/tmp/dotfiles/integration_test` - Integration test wrapper

## Next Steps to Resolve

1. Determine what signal is causing exit code 3
2. Check if the issue is with how the script sources nvm when node is missing
3. Verify the exact command that triggers the exit (likely in `run_vim_command` or `test_plugin_coc`)
4. Consider running script with `set +e` to capture more diagnostic output
5. Check if there's a race condition or signal handler issue
