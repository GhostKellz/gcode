# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in gcode, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email security concerns to the maintainers directly
3. Include a detailed description of the vulnerability
4. Provide steps to reproduce if applicable
5. Allow reasonable time for a fix before public disclosure

## Security Considerations

gcode is a Unicode processing library. While it does not handle network operations or sensitive data directly, the following security considerations apply:

### Input Validation
- All UTF-8/UTF-16 input is validated before processing
- Malformed sequences are rejected with appropriate errors
- Buffer boundaries are strictly enforced

### Memory Safety
- Written in Zig with memory-safe patterns
- No dynamic memory allocation in hot paths
- Bounds checking on all array accesses
- No use of unsafe pointer operations

### Denial of Service
- Lookup operations are O(1) with bounded memory
- No recursive algorithms that could cause stack overflow
- Designed for use in terminal emulators with adversarial input

## Best Practices for Users

When integrating gcode into your application:

- Validate external input at system boundaries before passing to gcode
- Handle error returns appropriately; do not ignore validation failures
- Keep gcode updated to receive security fixes

## Acknowledgments

We appreciate security researchers who responsibly disclose vulnerabilities. Contributors who report valid security issues will be acknowledged (with permission) in release notes.
