# Cursor Rules

A repository containing Cursor rules for AI-assisted coding in compatible editors like Cursor.

## Overview

This repository contains a collection of rules that guide AI interactions when using Cursor or compatible editors. These rules enforce code standards, commenting styles, and communication preferences.

## Features

- Standardized code commenting rules
- Language-specific coding standards
- Test writing guidelines
- Communication style preferences
- Post-code generation compliance checks

## Installation

Use the provided setup script to link these rules to your project:

```bash
# Navigate to any project directory where you want to use these rules
cd /path/to/your/project

# Run the setup script from this repository
/path/to/cursorrules/setup.sh
```

The setup script will:

1. Create a `.cursor` directory in your project if it doesn't exist
2. Create a symbolic link to these rules from your project
3. Update your `.gitignore` to ignore the `.cursor` directory

## Manual Setup

If you prefer to set up manually:

1. Create a `.cursor` directory in your project
2. Create a symbolic link from this repository's rules:
   ```bash
   ln -s /path/to/cursorrules/.cursor/rules /path/to/your/project/.cursor/rules
   ```
3. Add `.cursor` to your `.gitignore`

## Contributing

To contribute to this rule set:

1. Fork this repository
2. Create a new rule file in the `.cursor/rules` directory
3. Follow the naming convention: `[number]-[name].mdc`
4. Submit a pull request with your changes
