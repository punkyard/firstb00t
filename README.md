# Firstb00t - Debian VPS First Boot Security Script

A comprehensive security-focused first-boot script for Debian VPS systems. This project aims to automate the initial security hardening and configuration of Debian-based virtual private servers.

## Features

- System updates and security patches
- UFW firewall configuration
- SSH hardening
- User management (including restricted users)
- Fail2ban setup
- AppArmor configuration
- Log monitoring
- Password policies
- Security benchmarks
- Automated testing

## Prerequisites

- Debian-based VPS
- Root access
- Internet connection
- Basic understanding of Linux security

## Quick Start

1. Clone the repository:

```bash
git clone https://github.com/yourusername/firstb00t.git
cd firstb00t
```

2. Make the script executable:

```bash
chmod +x scripts/main.sh
```

3. Run the script:

```bash
sudo ./scripts/main.sh
```

## Project Structure

See `2_folder_structure.md` for detailed information about the project organization.

## Development Plan

See `1_development_plan.md` for the current development roadmap and future plans.

## Security Considerations

- The script requires root access
- It makes significant system changes
- Always backup your system before running
- Test in a non-production environment first

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Debian Security Team
- Open Source Security Community
- All contributors

## Support

For support, please open an issue in the GitHub repository.
