# Network Adapter Reset Tool

This repository contains scripts to reset network adapters and reconnect to Wi-Fi. There are two versions of the script: one in English and one in Spanish. The instructions below explain how to generate the executables and ensure they run with administrator privileges.

## Prerequisites

- Windows 10 or later
- PowerShell
- Download the preferred exe file version

## Running the Executables

Run in the root directory:

Spanish version:

```bash
ps2exe -inputFile "Spanish/RestablecerAdaptadorRed.ps1" -outputFile "Spanish/RestablecerAdaptadorRed.exe" -description "This executable resets network adapters and reconnects to Wi-Fi." -title "RestablecerAdaptadorRed" -company "TheDataScientist" -version "0.0.1"
```

English version:

```bash
ps2exe -inputFile "English/ResetNetworkAdapter.ps1" -outputFile "English/ResetNetworkAdapter.exe" -description "This executable resets network adapters and reconnects to Wi-Fi." -title "ResetNetworkAdapter" -company "TheDataScientist" -version "0.0.1"
```

- Spanish Version: RestablecerAdaptadorRed.exe
- English Version: ResetNetworkAdapter.exe

After generating the executables, you can run them. They will need administrator privileges to execute properly.

## License

[MIT](https://choosealicense.com/licenses/mit/)
