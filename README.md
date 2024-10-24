# CleanMyMac

A simple shell script to clean up the junk files generated during daily development work on macOS. Regularly using this script helps prevent excessive accumulation of unnecessary files over time.

## Features
- **Clear Xcode Build Files**: Removes Derived Data and Archives to free up space.
- **Cleanup Homebrew**: Uninstalls all outdated software installed via Homebrew.
- **Clear Old Gem Versions**: Removes all previously installed versions of Ruby gems.
- **Upgrade Before Cleanup**: Prompts to upgrade Homebrew and Ruby gems before cleaning. Click "YES" to proceed with the upgrades.

## Usage
To execute the script, run the following command in your terminal:

```bash
curl https://raw.githubusercontent.com/HeminWon/CleanMyMac/arm/cleanmymac.sh | sh
```

## Contribution
We welcome contributions! If you have suggestions for improvements or new features, feel free to submit a Merge Request (MR).

## Issues
If you encounter any bugs or have questions about the script, please open an issue in the repository. Your feedback is greatly appreciated!

## License
This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

